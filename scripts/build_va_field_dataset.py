#!/usr/bin/env python3
"""
Build field-only YOLO dataset from merged annotations (~877 images).
Train/val/test split for mealybug_va (no v10 merge).

Usage:
  python scripts/build_va_field_dataset.py
  python scripts/build_va_field_dataset.py --source datasets/mealybug_merged_all_annotations
"""

from __future__ import annotations

import argparse
import json
import random
import shutil
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = ROOT / "datasets" / "mealybug_merged_all_annotations"
DEFAULT_OUT = ROOT / "datasets" / "mealybug_va_field"

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    p.add_argument("--out", type=Path, default=DEFAULT_OUT)
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--train", type=float, default=0.70)
    p.add_argument("--val", type=float, default=0.15)
    p.add_argument("--dry-run", action="store_true")
    return p.parse_args()


def pairs(source: Path) -> list[tuple[Path, Path]]:
    img_dir = source / "images"
    lbl_dir = source / "labels"
    out: list[tuple[Path, Path]] = []
    for img in sorted(img_dir.iterdir()):
        if not img.is_file() or img.suffix.lower() not in IMAGE_EXTS:
            continue
        lbl = lbl_dir / f"{img.stem}.txt"
        if not lbl.is_file():
            continue
        out.append((img, lbl))
    return out


def copy_split(items: list[tuple[Path, Path]], split: str, out: Path, dry_run: bool) -> int:
    img_out = out / split / "images"
    lbl_out = out / split / "labels"
    if not dry_run:
        img_out.mkdir(parents=True, exist_ok=True)
        lbl_out.mkdir(parents=True, exist_ok=True)
    for img, lbl in items:
        dest_img = img_out / img.name
        dest_lbl = lbl_out / lbl.name
        if dry_run:
            continue
        shutil.copy2(img, dest_img)
        shutil.copy2(lbl, dest_lbl)
    return len(items)


def main() -> None:
    args = parse_args()
    source = args.source.resolve()
    out = args.out.resolve()

    all_pairs = pairs(source)
    if not all_pairs:
        raise SystemExit(f"No image+label pairs in {source}")

    random.seed(args.seed)
    random.shuffle(all_pairs)
    n = len(all_pairs)
    n_train = int(n * args.train)
    n_val = int(n * args.val)
    n_test = n - n_train - n_val
    train_p = all_pairs[:n_train]
    val_p = all_pairs[n_train : n_train + n_val]
    test_p = all_pairs[n_train + n_val :]

    if args.dry_run:
        print(f"DRY RUN: {n} pairs -> train {len(train_p)} val {len(val_p)} test {len(test_p)}")
        return

    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)

    counts = {
        "train": copy_split(train_p, "train", out, False),
        "val": copy_split(val_p, "valid", out, False),
        "test": copy_split(test_p, "test", out, False),
    }

    yaml = """train: train/images
val: valid/images
test: test/images
nc: 1
names:
- mealybug
"""
    (out / "data.yaml").write_text(yaml, encoding="utf-8")

    nonempty = 0
    for split in ("train", "valid", "test"):
        for lbl in (out / split / "labels").glob("*.txt"):
            if lbl.read_text(encoding="utf-8").strip():
                nonempty += 1

    manifest = {
        "built_at": datetime.now(timezone.utc).isoformat(),
        "source": str(source),
        "out": str(out),
        "seed": args.seed,
        "counts": counts,
        "nonempty_labels_total": nonempty,
    }
    (out / "build_manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    print(f"Built {out}")
    for k, v in counts.items():
        print(f"  {k}: {v}")
    print(f"  labels with boxes (all splits): {nonempty}")


if __name__ == "__main__":
    main()
