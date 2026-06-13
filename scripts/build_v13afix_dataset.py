#!/usr/bin/env python3
"""
Build mealybug_v13afix: v10 + Va field + fix500, then optional 70/20/10 resplit.

Usage:
  python scripts/build_v13afix_dataset.py --augment-field --fix-corrupt --split 0.7 0.2 0.1
"""

from __future__ import annotations

import argparse
import hashlib
import json
import random
import re
import shutil
import tempfile
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
V10A = ROOT / "datasets" / "mealybug_v10_plus_annotations"
FIX_TRAIN = ROOT / "datasets" / "train"
DEFAULT_OUT = ROOT / "datasets" / "mealybug_v13afix"

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument("--base", type=Path, default=V10A)
    p.add_argument("--fix-train", type=Path, default=FIX_TRAIN)
    p.add_argument("--out", type=Path, default=DEFAULT_OUT)
    p.add_argument("--augment-field", action="store_true")
    p.add_argument("--fix-corrupt", action="store_true")
    p.add_argument("--split", nargs=3, type=float, metavar=("TRAIN", "VAL", "TEST"), default=None)
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--dry-run", action="store_true")
    return p.parse_args()


def read_yolo_labels(path: Path) -> list[tuple[int, float, float, float, float]]:
    rows: list[tuple[int, float, float, float, float]] = []
    if not path.is_file():
        return rows
    for line in path.read_text(encoding="utf-8").splitlines():
        parts = line.strip().split()
        if len(parts) < 5:
            continue
        rows.append((int(parts[0]), *map(float, parts[1:5])))
    return rows


def write_yolo_labels(path: Path, rows: list[tuple[int, float, float, float, float]]) -> None:
    lines = [f"{c} {cx:.6f} {cy:.6f} {w:.6f} {h:.6f}" for c, cx, cy, w, h in rows]
    path.write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")


def hflip_label(rows: list[tuple[int, float, float, float, float]]) -> list:
    return [(c, 1.0 - cx, cy, w, h) for c, cx, cy, w, h in rows]


def fix_image(path: Path) -> None:
    try:
        from PIL import Image

        with Image.open(path) as im:
            im.convert("RGB").save(path, quality=95)
    except Exception:
        pass


def hflip_image(src: Path, dst: Path) -> None:
    from PIL import Image, ImageOps

    with Image.open(src) as im:
        ImageOps.mirror(im.convert("RGB")).save(dst, quality=95)


def file_hash(path: Path) -> str:
    return hashlib.md5(path.read_bytes()).hexdigest()


def stem_keys(stem: str) -> set[str]:
    s = stem.lower()
    keys = {s}
    m = re.search(r"(img_\d{8}_\d{6}(?:_\d+)?)", s, re.I)
    if m:
        keys.add(m.group(1).lower())
    return keys


def add_to_pool(pool: dict[str, tuple[Path, Path]], img: Path, lbl: Path, fix_corrupt: bool) -> bool:
    if not img.is_file() or img.suffix.lower() not in IMAGE_EXTS:
        return False
    h = file_hash(img)
    if h in pool:
        return False
    pool[h] = (img, lbl if lbl.is_file() else None)  # type: ignore[arg-type]
    return True


def build_staging(base: Path, fix_train: Path, augment_field: bool, fix_corrupt: bool, staging: Path) -> dict:
    shutil.copytree(base, staging)
    train_img, train_lbl = staging / "train" / "images", staging / "train" / "labels"
    existing_stems: set[str] = set()
    for p in train_img.iterdir():
        if p.is_file():
            existing_stems |= stem_keys(p.stem)

    fix_img, fix_lbl = fix_train / "images", fix_train / "labels"
    fix_added = fix_skip = 0
    for img in sorted(fix_img.iterdir()):
        if not img.is_file() or img.suffix.lower() not in IMAGE_EXTS:
            continue
        if stem_keys(img.stem) & existing_stems:
            fix_skip += 1
            continue
        dest = train_img / f"fix_{img.stem}{img.suffix.lower()}"
        lbl = fix_lbl / f"{img.stem}.txt"
        shutil.copy2(img, dest)
        if fix_corrupt:
            fix_image(dest)
        (train_lbl / f"{dest.stem}.txt").write_text(
            lbl.read_text(encoding="utf-8") if lbl.is_file() else "", encoding="utf-8"
        )
        existing_stems |= stem_keys(img.stem)
        fix_added += 1

    aug_n = 0
    if augment_field:
        for img in sorted(train_img.glob("ann_*")):
            if not img.is_file() or img.suffix.lower() not in IMAGE_EXTS:
                continue
            out = train_img / f"{img.stem}_hflp{img.suffix.lower()}"
            if out.exists():
                continue
            lbl = train_lbl / f"{img.stem}.txt"
            hflip_image(img, out)
            write_yolo_labels(train_lbl / f"{out.stem}.txt", hflip_label(read_yolo_labels(lbl)))
            aug_n += 1

    return {"fix500_added": fix_added, "fix500_skipped": fix_skip, "field_hflip_aug": aug_n}


def collect_pool(staging: Path) -> dict[str, tuple[Path, Path]]:
    pool: dict[str, tuple[Path, Path]] = {}
    for split in ("train", "valid", "test"):
        img_dir = staging / ("valid" if split == "valid" else split) / "images"
        lbl_dir = staging / ("valid" if split == "valid" else split) / "labels"
        if split == "valid":
            img_dir = staging / "valid" / "images"
            lbl_dir = staging / "valid" / "labels"
        for img in sorted(img_dir.iterdir()):
            if not img.is_file():
                continue
            lbl = lbl_dir / f"{img.stem}.txt"
            add_to_pool(pool, img, lbl, False)
    return pool


def write_split(
    items: list[tuple[Path, Path | None]],
    split: str,
    out: Path,
    fix_corrupt: bool,
) -> int:
    img_out, lbl_out = out / split / "images", out / split / "labels"
    img_out.mkdir(parents=True, exist_ok=True)
    lbl_out.mkdir(parents=True, exist_ok=True)
    for i, (img, lbl) in enumerate(items):
        name = f"{split}_{i:06d}{img.suffix.lower()}"
        dest_img = img_out / name
        dest_lbl = lbl_out / f"{Path(name).stem}.txt"
        shutil.copy2(img, dest_img)
        if fix_corrupt:
            fix_image(dest_img)
        if lbl and lbl.is_file():
            shutil.copy2(lbl, dest_lbl)
        else:
            dest_lbl.write_text("", encoding="utf-8")
    return len(items)


def apply_split(
    pool: dict[str, tuple[Path, Path | None]],
    ratios: tuple[float, float, float],
    seed: int,
    out: Path,
    fix_corrupt: bool,
    dry_run: bool,
) -> dict[str, int]:
    rt, rv, rs = ratios
    if abs(rt + rv + rs - 1.0) > 0.001:
        raise SystemExit(f"split ratios must sum to 1.0, got {rt + rv + rs}")

    items = list(pool.values())
    random.seed(seed)
    random.shuffle(items)
    n = len(items)
    n_train = int(n * rt)
    n_val = int(n * rv)
    n_test = n - n_train - n_val

    counts = {"train": n_train, "valid": n_val, "test": n_test, "total": n}
    if dry_run:
        return counts

    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    write_split(items[:n_train], "train", out, fix_corrupt)
    write_split(items[n_train : n_train + n_val], "valid", out, fix_corrupt)
    write_split(items[n_train + n_val :], "test", out, fix_corrupt)
    (out / "data.yaml").write_text(
        "train: train/images\nval: valid/images\ntest: test/images\nnc: 1\nnames:\n- mealybug\n",
        encoding="utf-8",
    )
    return counts


def main() -> None:
    args = parse_args()
    base = args.base.resolve()
    out = args.out.resolve()
    if not base.is_dir():
        raise SystemExit(f"Missing {base}")

    with tempfile.TemporaryDirectory() as tmp:
        staging = Path(tmp) / "staging"
        meta = build_staging(base, args.fix_train.resolve(), args.augment_field, args.fix_corrupt, staging)
        pool = collect_pool(staging)

        if args.split:
            counts = apply_split(pool, tuple(args.split), args.seed, out, args.fix_corrupt, args.dry_run)
            report = {
                "built_at": datetime.now(timezone.utc).isoformat(),
                "split": {"train": args.split[0], "val": args.split[1], "test": args.split[2], "seed": args.seed},
                "augment_field": args.augment_field,
                "fix_corrupt": args.fix_corrupt,
                **meta,
                "counts": counts,
                "note": "70/20/10 resplit of full pool — NOT the original v10 462 test; compare v11/v12 on benchmark separately.",
            }
        else:
            raise SystemExit("Use --split 0.7 0.2 0.1")

    if not args.dry_run:
        (out / "build_v13afix_report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
