#!/usr/bin/env python3
"""
Rename augmented copies from *_augN to versioned prefixes:
  - Va aug  -> Vb_<stem>_<N>
  - fix500 aug -> Vfix500b_<stem>_<N>

Usage:
  python scripts/rename_augmented_va_fix500.py --dry-run
  python scripts/rename_augmented_va_fix500.py
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUG_RE = re.compile(r"^(?P<base>.+)_aug(?P<idx>\d+)$")

FIX_SET = ROOT / "fix_sets" / "fix500_20260520"
VA_TRAIN = ROOT / "datasets" / "mealybug_va_field" / "train"
V10_PLUS_TRAIN = ROOT / "datasets" / "mealybug_v10_plus_annotations" / "train"


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--prefix-va", type=str, default="Vb")
    p.add_argument("--prefix-fix", type=str, default="Vfix500b")
    return p.parse_args()


def rename_aug_in_dir(
    img_dir: Path,
    lbl_dir: Path,
    prefix: str,
    dry_run: bool,
    name_filter: str | None = None,
) -> int:
    if not img_dir.is_dir():
        raise SystemExit(f"Missing {img_dir}")
    if not lbl_dir.is_dir():
        raise SystemExit(f"Missing {lbl_dir}")

    n = 0
    for img in sorted(img_dir.iterdir()):
        if not img.is_file():
            continue
        m = AUG_RE.match(img.stem)
        if not m:
            continue
        if name_filter and not img.stem.startswith(name_filter):
            continue
        base, idx = m.group("base"), m.group("idx")
        new_stem = f"{prefix}_{base}_{idx}"
        new_img = img_dir / f"{new_stem}{img.suffix.lower()}"
        old_lbl = lbl_dir / f"{img.stem}.txt"
        new_lbl = lbl_dir / f"{new_stem}.txt"
        if new_img.exists():
            print(f"skip exists: {new_img.name}")
            continue
        if dry_run:
            print(f"{img.name} -> {new_img.name}")
        else:
            img.rename(new_img)
            if old_lbl.is_file():
                old_lbl.rename(new_lbl)
            elif not new_lbl.exists():
                new_lbl.write_text("", encoding="utf-8")
        n += 1
    return n


def main() -> None:
    args = parse_args()
    total = 0

    print("=== fix500 -> Vfix500b ===")
    total += rename_aug_in_dir(
        FIX_SET / "images",
        FIX_SET / "labels_reviewed",
        args.prefix_fix,
        args.dry_run,
    )

    print("=== va_field train -> Vb ===")
    total += rename_aug_in_dir(
        VA_TRAIN / "images",
        VA_TRAIN / "labels",
        args.prefix_va,
        args.dry_run,
    )

    print("=== v10_plus ann_* aug -> Vb ===")
    total += rename_aug_in_dir(
        V10_PLUS_TRAIN / "images",
        V10_PLUS_TRAIN / "labels",
        args.prefix_va,
        args.dry_run,
        name_filter="ann_",
    )

    print(f"Renamed augmented files: {total}")


if __name__ == "__main__":
    main()
