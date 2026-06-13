#!/usr/bin/env python3
"""
Merge reviewed fix-set labels into datasets/train (and optional valid refresh).

Expects CVAT export in:
  fix_sets/<name>/labels_reviewed/*.txt
with matching basenames under fix_sets/<name>/images/

Usage:
  python scripts/merge_fix_set_review.py --fix-set fix_sets/fix500_20260519
  python scripts/merge_fix_set_review.py --fix-set ... --dry-run
"""

from __future__ import annotations

import argparse
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DATASET = ROOT / "datasets"


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Merge reviewed fix set into datasets/train.")
    p.add_argument("--fix-set", type=Path, required=True)
    p.add_argument("--dataset-root", type=Path, default=DEFAULT_DATASET)
    p.add_argument("--dry-run", action="store_true")
    return p.parse_args()


def main() -> None:
    args = parse_args()
    fix = args.fix_set.resolve()
    img_dir = fix / "images"
    reviewed = fix / "labels_reviewed"
    if not img_dir.is_dir():
        raise SystemExit(f"Missing {img_dir}")
    if not reviewed.is_dir():
        raise SystemExit(
            f"Missing {reviewed}\n"
            "Export YOLO 1.1 from CVAT into labels_reviewed/ (same basenames as images/)."
        )

    train_img = args.dataset_root / "train" / "images"
    train_lbl = args.dataset_root / "train" / "labels"
    train_img.mkdir(parents=True, exist_ok=True)
    train_lbl.mkdir(parents=True, exist_ok=True)

    copied = skipped = 0
    for img in sorted(img_dir.iterdir()):
        if not img.is_file():
            continue
        lbl = reviewed / f"{img.stem}.txt"
        if not lbl.is_file():
            print(f"skip (no reviewed label): {img.name}")
            skipped += 1
            continue
        dest_img = train_img / img.name
        dest_lbl = train_lbl / f"{img.stem}.txt"
        if dest_img.exists() and not args.dry_run:
            skipped += 1
            continue
        if args.dry_run:
            print(f"would merge {img.name}")
            copied += 1
            continue
        shutil.copy2(img, dest_img)
        shutil.copy2(lbl, dest_lbl)
        copied += 1

    log = {
        "merged_utc": datetime.now(timezone.utc).isoformat(),
        "fix_set": str(fix),
        "copied": copied,
        "skipped": skipped,
    }
    log_path = fix / "merge_log.json"
    if not args.dry_run:
        log_path.write_text(json.dumps(log, indent=2), encoding="utf-8")

    print(json.dumps(log, indent=2))
    if not args.dry_run:
        print("Next: retrain YOLO + export TFLite (RUN.md); sweep thresholds after.")


if __name__ == "__main__":
    main()
