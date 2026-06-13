#!/usr/bin/env python3
"""
Copy merged annotations into a copy of the 17k v10 dataset (train only).
Keeps val/ test unchanged so metrics stay comparable to v11/v12 (43% test mAP).

Usage:
  python scripts/merge_annotations_into_v10.py --source datasets/mealybug_merged_annotations
  python scripts/merge_annotations_into_v10.py --dry-run
"""

from __future__ import annotations

import argparse
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
V10 = ROOT / "mealybug.v10-8th-yolo26n.yolo26"
DEFAULT_SOURCE = ROOT / "datasets" / "mealybug_merged_annotations"
DEFAULT_OUT = ROOT / "datasets" / "mealybug_v10_plus_annotations"

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    p.add_argument("--v10", type=Path, default=V10)
    p.add_argument("--out", type=Path, default=DEFAULT_OUT)
    p.add_argument("--dry-run", action="store_true")
    return p.parse_args()


def copy_v10_tree(v10: Path, out: Path, dry_run: bool) -> None:
    if out.exists() and not dry_run:
        shutil.rmtree(out)
    if dry_run:
        print(f"would copy v10 tree {v10} -> {out} (excluding train/images labels first pass)")
        return
    shutil.copytree(v10, out)


def main() -> None:
    args = parse_args()
    src = args.source.resolve()
    v10 = args.v10.resolve()
    out = args.out.resolve()

    src_img = src / "images"
    src_lbl = src / "labels"
    if not src_img.is_dir():
        raise SystemExit(f"Missing {src_img} — run merge_darknet_zips.py first")

    if not v10.is_dir():
        raise SystemExit(f"Missing {v10}")

    if args.dry_run:
        print(f"DRY RUN: build {out}")
    else:
        if out.exists():
            shutil.rmtree(out)
        shutil.copytree(v10, out)

    train_img = out / "train" / "images"
    train_lbl = out / "train" / "labels"
    train_img.mkdir(parents=True, exist_ok=True)
    train_lbl.mkdir(parents=True, exist_ok=True)

    added = skipped = 0
    for img in sorted(src_img.iterdir()):
        if not img.is_file() or img.suffix.lower() not in IMAGE_EXTS:
            continue
        dest_name = f"ann_{img.stem}{img.suffix.lower()}"
        dest_img = train_img / dest_name
        dest_lbl = train_lbl / f"{Path(dest_name).stem}.txt"
        lbl = src_lbl / f"{img.stem}.txt"

        if dest_img.exists():
            skipped += 1
            continue

        if args.dry_run:
            print(f"  add {dest_name}")
            added += 1
            continue

        shutil.copy2(img, dest_img)
        if lbl.is_file():
            shutil.copy2(lbl, dest_lbl)
        else:
            dest_lbl.write_text("", encoding="utf-8")
        added += 1

    data_yaml = out / "data.yaml"
    yaml_text = (
        "train: train/images\n"
        "val: valid/images\n"
        "test: test/images\n"
        "nc: 1\n"
        "names:\n"
        "- mealybug\n"
    )
    if not args.dry_run:
        data_yaml.write_text(yaml_text, encoding="utf-8")

    train_count = len(list(train_img.glob("*"))) if train_img.is_dir() else 0
    report = {
        "merged_at": datetime.now(timezone.utc).isoformat(),
        "source": str(src),
        "v10_base": str(v10),
        "out": str(out),
        "added_to_train": added,
        "skipped_existing": skipped,
        "train_images_total": train_count,
        "val_test": "unchanged from v10 (fair benchmark)",
    }
    if not args.dry_run:
        (out / "merge_into_v10_report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")

    print(f"Output dataset: {out}")
    print(f"  Added to train: {added}")
    print(f"  Skipped (name exists): {skipped}")
    print(f"  Train images total: ~{train_count}")
    print("  Val/test: same 923 / 462 as 17k benchmark")
    print()
    print("Compare metrics (same test split):")
    print("  python scripts/evaluate_model_accuracy.py --model runs/retrain/mealybug_v11/weights/best.pt --data datasets/mealybug_v10_plus_annotations/data.yaml --conf 0.12")
    print()
    print("After fine-tune from v11:")
    print("  python scripts/retrain_yolo.py --data datasets/mealybug_v10_plus_annotations/data.yaml --weights runs/retrain/mealybug_v11/weights/best.pt --name mealybug_v13 --epochs 50 --batch 8 --imgsz 640 --patience 15 --no-export")


if __name__ == "__main__":
    main()
