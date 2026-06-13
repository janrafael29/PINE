#!/usr/bin/env python3
"""
Remove bad YOLO boxes: loose, huge/tiny, duplicates, failed pest-mask QA.

Does NOT keep loose boxes — drops them. Slightly tightens boxes with minor slack (< shrink threshold).

Usage:
  python scripts/clean_bad_labels.py --root mealybug.v10-8th-yolo26n.yolo26 --dry-run
  python scripts/clean_bad_labels.py --root mealybug.v10-8th-yolo26n.yolo26 --apply --backup
"""
from __future__ import annotations

import argparse
import json
import shutil
import sys
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "runs" / "label_bad_clean"
sys.path.insert(0, str(ROOT / "labeling_system"))

from pine_label.engine import (  # noqa: E402
    Box,
    TightenParams,
    find_image_for_label,
    merge_boxes_nms,
    parse_annotations,
    tighten_box_on_image,
    write_annotations,
)


@dataclass
class CleanStats:
    files: int = 0
    boxes_in: int = 0
    boxes_out: int = 0
    removed_invalid: int = 0
    removed_tiny: int = 0
    removed_huge: int = 0
    removed_loose: int = 0
    removed_no_pest: int = 0
    removed_duplicate: int = 0
    tightened_minor: int = 0
    kept: int = 0
    empty_files_after: int = 0


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Remove loose / bad YOLO boxes.")
    p.add_argument("--root", type=Path, required=True)
    p.add_argument("--splits", nargs="+", default=["train", "valid", "test"])
    p.add_argument("--min-area", type=float, default=0.00008)
    p.add_argument("--max-area", type=float, default=0.22)
    p.add_argument(
        "--loose-shrink",
        type=float,
        default=0.25,
        help="Remove box if mask tighten shrinks area by at least this fraction.",
    )
    p.add_argument(
        "--minor-tighten",
        type=float,
        default=0.03,
        help="If shrink in [minor, loose), replace with tight box.",
    )
    p.add_argument("--dedupe-iou", type=float, default=0.85)
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--apply", action="store_true")
    p.add_argument("--backup", action="store_true")
    p.add_argument("--limit", type=int, default=0)
    return p.parse_args()


def ann_to_box(ann) -> Box | None:
    if isinstance(ann, Box):
        return ann
    if hasattr(ann, "bounding_box"):
        return ann.bounding_box()
    return None


def clean_boxes_on_image(
    bgr,
    boxes: list[Box],
    *,
    min_area: float,
    max_area: float,
    loose_shrink: float,
    minor_tighten: float,
    params: TightenParams,
    stats: CleanStats,
) -> list[Box]:
    out: list[Box] = []
    for b in boxes:
        stats.boxes_in += 1
        if b.cls != 0:
            stats.removed_invalid += 1
            continue
        if b.area < min_area:
            stats.removed_tiny += 1
            continue
        if b.area > max_area:
            stats.removed_huge += 1
            continue
        tight, reason = tighten_box_on_image(bgr, b, params)
        if reason == "ok":
            shrink = 1.0 - tight.area / max(b.area, 1e-9)
            if shrink >= loose_shrink:
                stats.removed_loose += 1
                continue
            if shrink >= minor_tighten:
                out.append(tight)
                stats.tightened_minor += 1
            else:
                out.append(b)
                stats.kept += 1
        elif reason == "shrink_too_much":
            # Mask tiny vs box — label likely covers background, not one pest.
            stats.removed_no_pest += 1
            continue
        else:
            # Blur / glare / mask miss — keep original rather than delete.
            out.append(b)
            stats.kept += 1
    before_dedupe = len(out)
    out = merge_boxes_nms(out, iou_thr=0.85)
    stats.removed_duplicate += before_dedupe - len(out)
    stats.boxes_out += len(out)
    return out


def main() -> None:
    import cv2

    args = parse_args()
    root = args.root.resolve()
    apply = args.apply and not args.dry_run
    params = TightenParams()
    stats = CleanStats()
    per_split: dict[str, dict[str, int]] = {}

    for split in args.splits:
        lbl_dir = root / split / "labels"
        img_dir = root / split / "images"
        if not lbl_dir.is_dir():
            continue
        split_stats = CleanStats()
        files = sorted(lbl_dir.glob("*.txt"))
        if args.limit > 0:
            files = files[: args.limit]
        for lbl in files:
            stats.files += 1
            split_stats.files += 1
            anns = parse_annotations(lbl)
            boxes = [ann_to_box(a) for a in anns]
            boxes = [b for b in boxes if b is not None]
            if not boxes:
                continue
            img = find_image_for_label(lbl, img_dir)
            if img is None:
                continue
            bgr = cv2.imread(str(img))
            if bgr is None:
                continue
            cleaned = clean_boxes_on_image(
                bgr,
                boxes,
                min_area=args.min_area,
                max_area=args.max_area,
                loose_shrink=args.loose_shrink,
                minor_tighten=args.minor_tighten,
                params=params,
                stats=split_stats,
            )
            if apply:
                if args.backup:
                    bak = lbl_dir / "backup_before_bad_clean" / lbl.name
                    bak.parent.mkdir(parents=True, exist_ok=True)
                    if not bak.is_file():
                        shutil.copy2(lbl, bak)
                write_annotations(lbl, cleaned)
                if not cleaned:
                    stats.empty_files_after += 1
        for k in (
            "boxes_in",
            "boxes_out",
            "removed_loose",
            "removed_no_pest",
            "removed_huge",
            "removed_tiny",
            "removed_duplicate",
            "tightened_minor",
            "kept",
        ):
            setattr(stats, k, getattr(stats, k) + getattr(split_stats, k))
        per_split[split] = {
            "files": split_stats.files,
            "boxes_in": split_stats.boxes_in,
            "boxes_out": split_stats.boxes_out,
            "removed_loose": split_stats.removed_loose,
            "removed_no_pest": split_stats.removed_no_pest,
            "removed_huge": split_stats.removed_huge,
            "removed_tiny": split_stats.removed_tiny,
            "removed_duplicate": split_stats.removed_duplicate,
            "tightened_minor": split_stats.tightened_minor,
            "kept": split_stats.kept,
        }

    report = {
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "root": str(root),
        "applied": apply,
        "params": {
            "min_area": args.min_area,
            "max_area": args.max_area,
            "loose_shrink": args.loose_shrink,
            "minor_tighten": args.minor_tighten,
            "dedupe_iou": args.dedupe_iou,
        },
        "totals": {
            "files": stats.files,
            "boxes_in": stats.boxes_in,
            "boxes_out": stats.boxes_out,
            "removed_total": stats.boxes_in - stats.boxes_out,
            "removed_loose": stats.removed_loose,
            "removed_no_pest": stats.removed_no_pest,
            "removed_huge": stats.removed_huge,
            "removed_tiny": stats.removed_tiny,
            "removed_duplicate": stats.removed_duplicate,
            "tightened_minor": stats.tightened_minor,
            "kept": stats.kept,
            "pct_removed": round(
                100 * (stats.boxes_in - stats.boxes_out) / max(stats.boxes_in, 1), 2
            ),
        },
        "per_split": per_split,
        "rollback": "Restore from <split>/labels/backup_before_bad_clean/ if needed.",
    }
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out_path = OUT_DIR / f"{root.name}_bad_clean_report.json"
    out_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report["totals"], indent=2))
    print(f"Wrote {out_path}")
    if not apply:
        print("Dry run. Re-run with --apply --backup to write cleaned labels.")


if __name__ == "__main__":
    main()
