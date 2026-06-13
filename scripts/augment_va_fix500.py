#!/usr/bin/env python3
"""
Augment Va (field) and fix500 only — v10 Roboflow aug is left unchanged.

Targets:
  1. fix_sets/fix500_*/images + labels_reviewed  (aug copies named Vfix500b_*)
  2. datasets/mealybug_va_field/train            (aug copies named Vb_*)
  3. datasets/mealybug_v10_plus_annotations/train — ann_* only (aug copies named Vb_*)

Then rebuild the training pool:
  python scripts/build_v13afix_dataset.py --augment-field --fix-corrupt --split 0.7 0.2 0.1

Usage:
  python scripts/augment_va_fix500.py
  python scripts/augment_va_fix500.py --dry-run
  python scripts/augment_va_fix500.py --fix-copies 2 --va-copies 3
"""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from augment_yolo_subset import augment_batch  # noqa: E402
FIX_SET = ROOT / "fix_sets" / "fix500_20260520"
VA_TRAIN = ROOT / "datasets" / "mealybug_va_field" / "train"
V10_PLUS_TRAIN = ROOT / "datasets" / "mealybug_v10_plus_annotations" / "train"


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Augment Va + fix500 (not v10 aug pool).")
    p.add_argument("--fix-set", type=Path, default=FIX_SET)
    p.add_argument("--fix-copies", type=int, default=2, help="Extra copies per fix500 image (~3× total).")
    p.add_argument("--va-copies", type=int, default=3, help="Extra copies per Va image (~4× total).")
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--skip-v10-plus-ann", action="store_true", help="Only va_field + fix500.")
    return p.parse_args()


def main() -> None:
    args = parse_args()
    report: dict = {"built_at": datetime.now(timezone.utc).isoformat(), "steps": []}

    fix_set = args.fix_set.resolve()
    if not (fix_set / "images").is_dir():
        raise SystemExit(f"Missing fix set images: {fix_set / 'images'}")

    print("=== fix500 ===")
    s = augment_batch(
        fix_set,
        labels_dir="labels_reviewed",
        copies_per_image=args.fix_copies,
        seed=args.seed,
        version_prefix="Vfix500b",
        dry_run=args.dry_run,
    )
    report["steps"].append({"name": "fix500", **s})
    print(s, "\n")

    if VA_TRAIN.is_dir():
        print("=== Va (mealybug_va_field/train) ===")
        s = augment_batch(
            VA_TRAIN,
            labels_dir="labels",
            copies_per_image=args.va_copies,
            seed=args.seed + 1,
            version_prefix="Vb",
            dry_run=args.dry_run,
        )
        report["steps"].append({"name": "va_field_train", **s})
        print(s, "\n")

    if not args.skip_v10_plus_ann and V10_PLUS_TRAIN.is_dir():
        print("=== Va in v10_plus (ann_* train only) ===")
        s = augment_batch(
            V10_PLUS_TRAIN,
            labels_dir="labels",
            name_prefix="ann_",
            copies_per_image=args.va_copies,
            seed=args.seed + 2,
            version_prefix="Vb",
            dry_run=args.dry_run,
        )
        report["steps"].append({"name": "v10_plus_ann_train", **s})
        print(s, "\n")

    log = ROOT / "runs" / "augment_va_fix500_report.json"
    log.parent.mkdir(parents=True, exist_ok=True)
    if not args.dry_run:
        log.write_text(json.dumps(report, indent=2), encoding="utf-8")
        print(f"Wrote {log}")

    print("Next:")
    print("  python scripts/merge_fix_set_review.py --fix-set", fix_set)
    print("  python scripts/build_v13afix_dataset.py --augment-field --fix-corrupt --split 0.7 0.2 0.1")


if __name__ == "__main__":
    main()
