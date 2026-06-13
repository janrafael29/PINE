#!/usr/bin/env python3
"""
Audit and auto-clean YOLO box labels (v10-scale datasets).

Safe automated fixes (no manual CVAT):
  - Polygon / extra-coordinate lines -> tight axis-aligned bbox
  - Clip boxes to [0, 1]
  - Drop invalid / wrong-class lines
  - Drop tiny boxes (likely noise)
  - Drop huge boxes (likely whole-leaf mistakes)
  - Dedupe near-duplicate boxes (label-side NMS)

Usage:
  python scripts/audit_and_clean_yolo_labels.py --root mealybug.v10-8th-yolo26n.yolo26 --dry-run
  python scripts/audit_and_clean_yolo_labels.py --root mealybug.v10-8th-yolo26n.yolo26 --apply --backup

Outputs:
  runs/label_clean/report.json
  runs/label_clean/worst_for_cvat.csv  (prioritize human review)
"""

from __future__ import annotations

import argparse
import json
import shutil
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "runs" / "label_clean"


@dataclass
class Box:
    cls: int
    cx: float
    cy: float
    w: float
    h: float

    @property
    def area(self) -> float:
        return self.w * self.h

    def xyxy(self) -> tuple[float, float, float, float]:
        x1 = self.cx - self.w / 2
        y1 = self.cy - self.h / 2
        x2 = self.cx + self.w / 2
        y2 = self.cy + self.h / 2
        return x1, y1, x2, y2


@dataclass
class Stats:
    files: int = 0
    lines_in: int = 0
    lines_out: int = 0
    polygon_converted: int = 0
    dropped_invalid: int = 0
    dropped_tiny: int = 0
    dropped_huge: int = 0
    deduped: int = 0
    clipped: int = 0
    worst_scores: list[tuple[float, str, int, float]] = field(default_factory=list)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument("--root", type=Path, required=True, help="Dataset root with train/valid/test")
    p.add_argument("--splits", nargs="+", default=["train", "valid", "test"])
    p.add_argument("--min-area", type=float, default=0.00008, help="Drop boxes smaller than this")
    p.add_argument("--max-area", type=float, default=0.22, help="Drop boxes larger than this (leaf-sized)")
    p.add_argument("--dedupe-iou", type=float, default=0.85, help="Merge duplicate label boxes")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--apply", action="store_true", help="Write cleaned labels")
    p.add_argument("--backup", action="store_true", help="Copy labels to labels_backup_* before apply")
    p.add_argument("--limit", type=int, default=0, help="Max files per split (0 = all)")
    return p.parse_args()


def polygon_to_box(parts: list[str]) -> Box | None:
    """YOLO polygon: cls x1 y1 x2 y2 ... (normalized)."""
    if len(parts) < 7:
        return None
    try:
        cls = int(float(parts[0]))
        coords = [float(x) for x in parts[1:]]
    except ValueError:
        return None
    if len(coords) < 6 or len(coords) % 2 != 0:
        return None
    xs = coords[0::2]
    ys = coords[1::2]
    x1, x2 = max(0.0, min(xs)), min(1.0, max(xs))
    y1, y2 = max(0.0, min(ys)), min(1.0, max(ys))
    w = x2 - x1
    h = y2 - y1
    if w <= 0 or h <= 0:
        return None
    return Box(cls=cls, cx=(x1 + x2) / 2, cy=(y1 + y2) / 2, w=w, h=h)


def parse_line(line: str) -> Box | None:
    parts = line.strip().split()
    if not parts:
        return None
    if len(parts) > 5:
        return polygon_to_box(parts)
    if len(parts) != 5:
        return None
    try:
        cls = int(float(parts[0]))
        cx, cy, w, h = (float(parts[1]), float(parts[2]), float(parts[3]), float(parts[4]))
    except ValueError:
        return None
    return Box(cls=cls, cx=cx, cy=cy, w=w, h=h)


def clip_box(b: Box) -> Box:
    w = max(1e-6, min(1.0, b.w))
    h = max(1e-6, min(1.0, b.h))
    cx = min(1.0 - w / 2, max(w / 2, b.cx))
    cy = min(1.0 - h / 2, max(h / 2, b.cy))
    return Box(cls=b.cls, cx=cx, cy=cy, w=w, h=h)


def iou(a: Box, b: Box) -> float:
    ax1, ay1, ax2, ay2 = a.xyxy()
    bx1, by1, bx2, by2 = b.xyxy()
    ix1, iy1 = max(ax1, bx1), max(ay1, by1)
    ix2, iy2 = min(ax2, bx2), min(ay2, by2)
    iw, ih = max(0.0, ix2 - ix1), max(0.0, iy2 - iy1)
    inter = iw * ih
    if inter <= 0:
        return 0.0
    union = a.area + b.area - inter
    return inter / union if union > 0 else 0.0


def dedupe_boxes(boxes: list[Box], iou_thr: float) -> tuple[list[Box], int]:
    """Keep larger-confidence proxy: keep smaller area box (tighter) when duplicate."""
    removed = 0
    kept: list[Box] = []
    for b in sorted(boxes, key=lambda x: x.area):
        if any(iou(b, k) >= iou_thr for k in kept):
            removed += 1
            continue
        kept.append(b)
    return kept, removed


def process_file(
    lbl_path: Path,
    *,
    min_area: float,
    max_area: float,
    dedupe_iou: float,
    stats: Stats,
    was_polygon: list[bool],
) -> list[Box]:
    raw = lbl_path.read_text(encoding="utf-8", errors="ignore").strip()
    lines = [ln for ln in raw.splitlines() if ln.strip()]
    stats.lines_in += len(lines)
    out: list[Box] = []
    for line in lines:
        parts = line.split()
        is_poly = len(parts) > 5
        b = parse_line(line)
        if b is None:
            stats.dropped_invalid += 1
            continue
        if is_poly:
            stats.polygon_converted += 1
        if b.cls != 0:
            stats.dropped_invalid += 1
            continue
        clipped = clip_box(b)
        if (
            clipped.cx != b.cx
            or clipped.cy != b.cy
            or clipped.w != b.w
            or clipped.h != b.h
        ):
            stats.clipped += 1
        b = clipped
        if b.area < min_area:
            stats.dropped_tiny += 1
            continue
        if b.area > max_area:
            stats.dropped_huge += 1
            was_polygon.append(is_poly)
            continue
        out.append(b)
    out, n_dedupe = dedupe_boxes(out, dedupe_iou)
    stats.deduped += n_dedupe
    stats.lines_out += len(out)
    return out


def write_labels(path: Path, boxes: list[Box]) -> None:
    lines = [
        f"{b.cls} {b.cx:.6f} {b.cy:.6f} {b.w:.6f} {b.h:.6f}" for b in boxes
    ]
    path.write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")


def main() -> None:
    args = parse_args()
    root = args.root.resolve()
    if not root.is_dir():
        raise SystemExit(f"Missing dataset root: {root}")

    stats = Stats()
    per_split: dict[str, dict[str, int]] = {}
    worst: list[tuple[float, str, int, float]] = []

    for split in args.splits:
        lbl_dir = root / split / "labels"
        if not lbl_dir.is_dir():
            print(f"Skip missing {lbl_dir}")
            continue
        split_stats = {
            "files": 0,
            "lines_in": 0,
            "lines_out": 0,
            "dropped_huge": 0,
        }
        files = sorted(lbl_dir.glob("*.txt"))
        if args.limit > 0:
            files = files[: args.limit]
        for lbl_path in files:
            stats.files += 1
            split_stats["files"] += 1
            lines_before = len(
                [
                    ln
                    for ln in lbl_path.read_text(encoding="utf-8", errors="ignore").splitlines()
                    if ln.strip()
                ]
            )
            boxes = process_file(
                lbl_path,
                min_area=args.min_area,
                max_area=args.max_area,
                dedupe_iou=args.dedupe_iou,
                stats=stats,
                was_polygon=[],
            )
            split_stats["lines_in"] += lines_before
            split_stats["lines_out"] += len(boxes)
            dropped = lines_before - len(boxes)
            if dropped >= 3 or (lines_before >= 5 and dropped / max(lines_before, 1) >= 0.3):
                score = float(dropped) + (5.0 if lines_before > 0 and len(boxes) == 0 else 0)
                worst.append((score, str(lbl_path.relative_to(root)), len(boxes), 0.0))

            if args.apply:
                if args.backup:
                    bak = lbl_path.with_name(lbl_path.name + ".bak")
                    if not bak.exists():
                        shutil.copy2(lbl_path, bak)
                write_labels(lbl_path, boxes)

        per_split[split] = split_stats

    worst.sort(reverse=True)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    worst_csv = OUT_DIR / "worst_for_cvat.csv"
    worst_csv.write_text(
        "score,label_path,boxes_after\n"
        + "\n".join(f"{s},{p},{n}" for s, p, n, _ in worst[:500]),
        encoding="utf-8",
    )

    report = {
        "root": str(root),
        "dry_run": args.dry_run or not args.apply,
        "applied": args.apply,
        "params": {
            "min_area": args.min_area,
            "max_area": args.max_area,
            "dedupe_iou": args.dedupe_iou,
        },
        "totals": {
            "files": stats.files,
            "lines_in": stats.lines_in,
            "lines_out": stats.lines_out,
            "polygon_converted": stats.polygon_converted,
            "dropped_invalid": stats.dropped_invalid,
            "dropped_tiny": stats.dropped_tiny,
            "dropped_huge": stats.dropped_huge,
            "deduped": stats.deduped,
            "clipped": stats.clipped,
        },
        "per_split": per_split,
        "next_steps": [
            "Review runs/label_clean/worst_for_cvat.csv in CVAT (worst 200-500 images).",
            "Re-train mealybug_v11 from mealybug_v10 best.pt after clean + field batch.",
            "Re-run: python scripts/evaluate_model_accuracy.py --model runs/retrain/mealybug_v10/weights/best.pt",
        ],
    }
    (OUT_DIR / "report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")

    print(json.dumps(report["totals"], indent=2))
    print(f"Wrote {OUT_DIR / 'report.json'}")
    print(f"Wrote {worst_csv} (top 500 priority paths)")
    if not args.apply:
        print("Dry run only. Re-run with --apply --backup to write cleaned labels.")


if __name__ == "__main__":
    main()
