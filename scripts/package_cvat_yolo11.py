#!/usr/bin/env python3
"""Build CVAT-compatible YOLO 1.1 zip from a fix_set folder (obj_train_data layout)."""

from __future__ import annotations

import argparse
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument(
        "--fix-set",
        type=Path,
        default=ROOT / "fix_sets" / "fix500_20260520",
        help="Fix set dir with images/ and labels_pre/",
    )
    p.add_argument(
        "--labels-dir",
        type=str,
        default="labels_pre",
        help="Label subfolder name (default: labels_pre)",
    )
    p.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Output zip (default: <fix-set>/cvat_import_yolo11.zip)",
    )
    return p.parse_args()


def main() -> None:
    args = parse_args()
    fix = args.fix_set.resolve()
    img_dir = fix / "images"
    lbl_dir = fix / args.labels_dir
    if not img_dir.is_dir():
        raise SystemExit(f"Missing {img_dir}")
    if not lbl_dir.is_dir():
        raise SystemExit(f"Missing {lbl_dir}")

    out_zip = args.output or (fix / "cvat_import_yolo11.zip")
    data_dir_name = "obj_train_data"

    names = fix / "obj.names"
    names.write_text("mealybug\n", encoding="utf-8")

    obj_data = fix / "obj.data"
    obj_data.write_text(
        "classes = 1\nnames = obj.names\ntrain = train.txt\n",
        encoding="utf-8",
    )

    images = sorted(p for p in img_dir.iterdir() if p.is_file())
    train_lines = [f"{data_dir_name}/{p.name}" for p in images]
    train_txt = fix / "train.txt"
    train_txt.write_text("\n".join(train_lines) + "\n", encoding="utf-8")

    with zipfile.ZipFile(out_zip, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        zf.write(obj_data, "obj.data")
        zf.write(names, "obj.names")
        zf.write(train_txt, "train.txt")
        for img in images:
            arc_img = f"{data_dir_name}/{img.name}"
            zf.write(img, arc_img)
            lbl = lbl_dir / f"{img.stem}.txt"
            text = lbl.read_text(encoding="utf-8") if lbl.is_file() else ""
            zf.writestr(f"{data_dir_name}/{img.stem}.txt", text)

    print(f"Wrote {out_zip} ({len(images)} images)")
    print("CVAT: create task with images zip OR use this zip as YOLO 1.1 annotation upload.")


if __name__ == "__main__":
    main()
