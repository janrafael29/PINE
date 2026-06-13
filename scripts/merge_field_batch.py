#!/usr/bin/env python3
"""
Merge a reviewed field batch (images/ + labels/) into datasets/train for training.

Usage:
  python scripts/merge_field_batch.py --batch field_batches/2026-05-21_field
  python scripts/merge_field_batch.py --batch ... --dry-run
"""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DATASET = ROOT / "datasets"
TRAIN_IMG = DEFAULT_DATASET / "train" / "images"
TRAIN_LBL = DEFAULT_DATASET / "train" / "labels"


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Merge field batch into datasets/train.")
    p.add_argument("--batch", type=Path, required=True, help="Batch folder with images/ and labels/.")
    p.add_argument(
        "--dataset-root",
        type=Path,
        default=DEFAULT_DATASET,
        help="YOLO dataset root (default: datasets/).",
    )
    p.add_argument("--dry-run", action="store_true", help="Print actions only.")
    return p.parse_args()


def main() -> None:
    args = parse_args()
    batch = args.batch.resolve()
    img_src = batch / "images"
    lbl_src = batch / "labels"
    if not img_src.is_dir():
        raise SystemExit(f"Missing {img_src}")

    train_img = args.dataset_root / "train" / "images"
    train_lbl = args.dataset_root / "train" / "labels"
    train_img.mkdir(parents=True, exist_ok=True)
    train_lbl.mkdir(parents=True, exist_ok=True)

    copied = skipped = 0
    for img in sorted(img_src.iterdir()):
        if not img.is_file():
            continue
        dest_img = train_img / img.name
        dest_lbl = train_lbl / f"{img.stem}.txt"
        lbl_file = lbl_src / f"{img.stem}.txt"

        if dest_img.exists():
            skipped += 1
            continue

        if args.dry_run:
            print(f"would copy {img.name}")
            copied += 1
            continue

        shutil.copy2(img, dest_img)
        if lbl_file.is_file():
            shutil.copy2(lbl_file, dest_lbl)
        else:
            dest_lbl.write_text("", encoding="utf-8")
        copied += 1

    print(f"Batch: {batch}")
    print(f"Copied: {copied}  Skipped (duplicate name): {skipped}")
    print(f"Train images now: {len(list(train_img.glob('*')))} files")
    if not args.dry_run:
        print("Next: python scripts/audit_yolo_dataset.py  (if present)")
        print("       python scripts/retrain_yolo.py  (see RUN.md)")


if __name__ == "__main__":
    main()
