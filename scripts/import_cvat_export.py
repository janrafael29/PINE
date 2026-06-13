#!/usr/bin/env python3
"""
Copy CVAT YOLO 1.1 export into fix_sets/<name>/labels_reviewed/.

Images stay in fix_sets/.../images/ (already local). Only labels are imported.

Usage:
  python scripts/import_cvat_export.py --fix-set fix_sets/fix500_20260520 --cvat-zip "C:\\Users\\you\\Downloads\\export.zip"
  python scripts/import_cvat_export.py --fix-set fix_sets/fix500_20260520 --cvat-dir "C:\\Users\\you\\Downloads\\unzipped"

Then:
  python scripts/merge_fix_set_review.py --fix-set fix_sets/fix500_20260520
"""

from __future__ import annotations

import argparse
import shutil
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Import CVAT YOLO export into labels_reviewed/")
    p.add_argument("--fix-set", type=Path, required=True)
    g = p.add_mutually_exclusive_group(required=True)
    g.add_argument("--cvat-zip", type=Path, help="CVAT download .zip")
    g.add_argument("--cvat-dir", type=Path, help="Unzipped CVAT export folder")
    return p.parse_args()


def collect_txt_sources(root: Path) -> dict[str, Path]:
    """Map label stem -> path (prefer deepest match if duplicates)."""
    found: dict[str, Path] = {}
    for txt in root.rglob("*.txt"):
        if txt.name in ("train.txt", "valid.txt", "test.txt"):
            continue
        stem = txt.stem
        found[stem] = txt
    return found


def extract_zip(zip_path: Path, dest: Path) -> Path:
    dest.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(zip_path, "r") as zf:
        zf.extractall(dest)
    return dest


def main() -> None:
    args = parse_args()
    fix = args.fix_set.resolve()
    img_dir = fix / "images"
    out_dir = fix / "labels_reviewed"
    if not img_dir.is_dir():
        raise SystemExit(f"Missing images folder: {img_dir}")

    if args.cvat_zip:
        if not args.cvat_zip.is_file():
            raise SystemExit(f"Zip not found: {args.cvat_zip}")
        scratch = fix / "_cvat_export_unzip"
        if scratch.exists():
            shutil.rmtree(scratch)
        src_root = extract_zip(args.cvat_zip.resolve(), scratch)
    else:
        src_root = args.cvat_dir.resolve()
        if not src_root.is_dir():
            raise SystemExit(f"Folder not found: {src_root}")

    labels_by_stem = collect_txt_sources(src_root)
    if not labels_by_stem:
        raise SystemExit(f"No .txt labels under {src_root}")

    out_dir.mkdir(parents=True, exist_ok=True)
    images = sorted(p for p in img_dir.iterdir() if p.is_file())
    matched = missing = 0
    for img in images:
        src = labels_by_stem.get(img.stem)
        dst = out_dir / f"{img.stem}.txt"
        if not src:
            missing += 1
            continue
        shutil.copy2(src, dst)
        matched += 1

    print(f"CVAT source: {src_root}")
    print(f"Label files in export: {len(labels_by_stem)}")
    print(f"Local images: {len(images)}")
    print(f"Matched -> labels_reviewed/: {matched}")
    print(f"Missing labels for images: {missing}")
    print(f"Output: {out_dir}")
    if missing:
        print(
            "\nSome images have no label file in the export (empty negatives are OK — "
            "create empty .txt manually if needed)."
        )
    if matched == 0:
        raise SystemExit(
            "No names matched. Check that export is YOLO 1.1 and stems match images/."
        )
    print(
        "\nNext:\n"
        f"  python scripts/merge_fix_set_review.py --fix-set {fix.relative_to(ROOT)}"
    )


if __name__ == "__main__":
    main()
