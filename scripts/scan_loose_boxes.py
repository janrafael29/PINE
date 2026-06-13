#!/usr/bin/env python3
"""Scan YOLO labels for loose boxes (would shrink significantly when tightened)."""
from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "labeling_system"))

from pine_label.engine import (  # noqa: E402
    Box,
    TightenParams,
    find_image_for_label,
    parse_label_file,
    tighten_box_on_image,
)


@dataclass
class ScanStats:
    files: int = 0
    files_with_boxes: int = 0
    boxes: int = 0
    tighten_ok: int = 0
    unchanged: int = 0
    failed_mask: int = 0
    loose_15: int = 0
    loose_25: int = 0
    loose_50: int = 0
    huge_gt_4pct: int = 0
    huge_gt_10pct: int = 0
    worst: list[tuple[float, str, int, float]] = field(default_factory=list)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Scan dataset for loose bounding boxes.")
    p.add_argument("--root", type=Path, default=ROOT / "mealybug.v10-8th-yolo26n.yolo26")
    p.add_argument("--splits", nargs="+", default=["train", "valid", "test"])
    p.add_argument("--limit", type=int, default=0, help="Max label files per split (0=all)")
    p.add_argument(
        "--out",
        type=Path,
        default=ROOT / "runs" / "label_loose_scan" / "v10_report.json",
    )
    return p.parse_args()


def scan_split(root: Path, split: str, limit: int, params: TightenParams) -> ScanStats:
    import cv2

    stats = ScanStats()
    lbl_dir = root / split / "labels"
    img_dir = root / split / "images"
    if not lbl_dir.is_dir():
        return stats
    files = sorted(lbl_dir.glob("*.txt"))
    if limit > 0:
        files = files[:limit]
    for lbl in files:
        boxes = parse_label_file(lbl)
        stats.files += 1
        if not boxes:
            continue
        stats.files_with_boxes += 1
        img = find_image_for_label(lbl, img_dir)
        if img is None:
            continue
        bgr = cv2.imread(str(img))
        if bgr is None:
            continue
        file_shrink = 0.0
        file_loose = 0
        for b in boxes:
            stats.boxes += 1
            if b.area > 0.04:
                stats.huge_gt_4pct += 1
            if b.area > 0.10:
                stats.huge_gt_10pct += 1
            tight, reason = tighten_box_on_image(bgr, b, params)
            if tight is None or reason != "ok":
                stats.failed_mask += 1
                stats.unchanged += 1
                continue
            ratio = tight.area / max(b.area, 1e-9)
            shrink = 1.0 - ratio
            if shrink < 0.03:
                stats.unchanged += 1
                continue
            stats.tighten_ok += 1
            file_shrink += shrink
            if shrink >= 0.15:
                stats.loose_15 += 1
                file_loose += 1
            if shrink >= 0.25:
                stats.loose_25 += 1
            if shrink >= 0.50:
                stats.loose_50 += 1
        if file_loose >= 2:
            stats.worst.append((file_shrink, f"{split}/labels/{lbl.name}", len(boxes), file_loose))
    stats.worst.sort(reverse=True)
    return stats


def main() -> None:
    args = parse_args()
    root = args.root.resolve()
    params = TightenParams()
    per_split: dict = {}
    total = ScanStats()
    for split in args.splits:
        s = scan_split(root, split, args.limit, params)
        per_split[split] = {
            "files": s.files,
            "files_with_boxes": s.files_with_boxes,
            "boxes": s.boxes,
            "would_tighten": s.tighten_ok,
            "unchanged": s.unchanged,
            "loose_15pct_shrink": s.loose_15,
            "loose_25pct_shrink": s.loose_25,
            "loose_50pct_shrink": s.loose_50,
            "huge_area_gt_4pct": s.huge_gt_4pct,
            "huge_area_gt_10pct": s.huge_gt_10pct,
            "pct_loose_25": round(100 * s.loose_25 / max(s.boxes, 1), 2),
        }
        for attr in (
            "files",
            "files_with_boxes",
            "boxes",
            "tighten_ok",
            "unchanged",
            "failed_mask",
            "loose_15",
            "loose_25",
            "loose_50",
            "huge_gt_4pct",
            "huge_gt_10pct",
        ):
            setattr(total, attr, getattr(total, attr) + getattr(s, attr))
        total.worst.extend(s.worst)
    total.worst.sort(reverse=True)

    report = {
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "root": str(root),
        "method": "HSV/LAB mask tighten; loose if shrink>=15%|25%|50% area",
        "totals": {
            "files": total.files,
            "boxes": total.boxes,
            "would_tighten_any": total.tighten_ok,
            "loose_25pct_shrink": total.loose_25,
            "loose_50pct_shrink": total.loose_50,
            "huge_area_gt_4pct": total.huge_gt_4pct,
            "pct_boxes_loose_25": round(100 * total.loose_25 / max(total.boxes, 1), 2),
            "pct_boxes_would_tighten": round(100 * total.tighten_ok / max(total.boxes, 1), 2),
        },
        "per_split": per_split,
        "worst_files_top30": [
            {"shrink_sum": a, "path": p, "boxes": n, "loose_boxes": c}
            for a, p, n, c in total.worst[:30]
        ],
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2), encoding="utf-8")
    csv_path = args.out.with_suffix(".csv")
    csv_path.write_text(
        "shrink_sum,path,boxes,loose_boxes\n"
        + "\n".join(
            f"{a:.3f},{p},{n},{c}" for a, p, n, c in total.worst[:500]
        ),
        encoding="utf-8",
    )
    print(json.dumps(report["totals"], indent=2))
    print(f"Wrote {args.out}")
    print(f"Wrote {csv_path}")


if __name__ == "__main__":
    main()
