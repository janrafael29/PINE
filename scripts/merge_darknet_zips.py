#!/usr/bin/env python3
"""
Merge Darknet/CVAT YOLO 1.1 zips into images/ + labels/.
Supports label-only zips (matches images from --image-dir by filename suffix).

Usage:
  python scripts/merge_darknet_zips.py ^
    --zip annotation_new/Mealybug_annotations.zip ^
    --zip annotation_new/Mealybug_annotations2.zip ^
    --image-dir field_batches/2026-05-21_2026-05-21_collected/images
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import tempfile
import zipfile
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUT = ROOT / "datasets" / "mealybug_merged_annotations"

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Merge Darknet YOLO annotation zips.")
    p.add_argument("--zip", type=Path, action="append", required=True, dest="zips")
    p.add_argument("--out", type=Path, default=DEFAULT_OUT)
    p.add_argument(
        "--image-dir",
        type=Path,
        action="append",
        default=[],
        help="Folders to search for photos (repeatable). Optional if zips include images.",
    )
    return p.parse_args()


def normalize_key(name: str) -> str:
    s = name.lower().strip()
    s = re.sub(r"\(\d+\)", "", s)  # (1) duplicates
    s = re.sub(r"[^a-z0-9]+", "_", s)
    return s.strip("_")


def build_image_index(image_dirs: list[Path]) -> dict[str, Path]:
    """Map normalized keys -> image path (longest stem wins on collision)."""
    index: dict[str, Path] = {}
    for d in image_dirs:
        if not d.is_dir():
            continue
        for img in d.rglob("*"):
            if not img.is_file() or img.suffix.lower() not in IMAGE_EXTS:
                continue
            stem = img.stem
            keys = {normalize_key(stem), normalize_key(stem.split("_")[-1])}
            # IMG_20260520_161423_958 from ..._era_IMG_20260520_161423_958
            m = re.search(r"(IMG_\d{8}_\d{6}(?:_\d+)?)", stem, re.I)
            if m:
                keys.add(normalize_key(m.group(1)))
            for k in keys:
                if k and (k not in index or len(stem) > len(index[k].stem)):
                    index[k] = img
    return index


def find_data_dir(extract_root: Path) -> Path:
    for name in ("obj_train_data", "data/obj_train_data"):
        p = extract_root / name
        if p.is_dir():
            return p
    if (extract_root / "obj_train_data").is_dir():
        return extract_root / "obj_train_data"
    return extract_root


def collect_labels(data_dir: Path) -> list[tuple[Path, str]]:
    """All .txt under obj_train_data; tag is subfolder (era, xyrus, ...)."""
    out: list[tuple[Path, str]] = []
    for txt in sorted(data_dir.rglob("*.txt")):
        if txt.name in ("train.txt", "obj.data", "obj.names"):
            continue
        tag = txt.parent.name if txt.parent != data_dir else "ann"
        out.append((txt, tag))
    return out


def sibling_image(lbl_path: Path) -> Path | None:
    """Image next to label in an extracted zip (annotated/era/foo.txt + foo.jpg)."""
    for ext in IMAGE_EXTS:
        candidate = lbl_path.with_suffix(ext)
        if candidate.is_file():
            return candidate
    return None


def match_image(label_stem: str, index: dict[str, Path]) -> Path | None:
    candidates = [
        normalize_key(label_stem),
        normalize_key(label_stem.replace("Copy of ", "Copy_of_")),
    ]
    m = re.search(r"(IMG_\d{8}_\d{6}(?:_\d+)?)", label_stem, re.I)
    if m:
        candidates.append(normalize_key(m.group(1)))
    for k in candidates:
        if k and k in index:
            return index[k]
    # fuzzy: any index key ending with label suffix
    nk = normalize_key(label_stem)
    for k, path in index.items():
        if k.endswith(nk) or nk.endswith(k):
            return path
    return None


def merge_zips(zips: list[Path], image_dirs: list[Path], out: Path) -> dict:
    img_out = out / "images"
    lbl_out = out / "labels"
    img_out.mkdir(parents=True, exist_ok=True)
    lbl_out.mkdir(parents=True, exist_ok=True)

    index = build_image_index([d.resolve() for d in image_dirs])
    report = {
        "merged_at": datetime.now(timezone.utc).isoformat(),
        "sources": [],
        "image_dirs": [str(d.resolve()) for d in image_dirs],
        "index_size": len(index),
        "total_pairs": 0,
        "with_nonempty_labels": 0,
        "missing_images": 0,
        "skipped_duplicates": 0,
        "missing_samples": [],
    }
    seen: set[str] = set()

    for zpath in zips:
        zpath = zpath.resolve()
        src_info = {"zip": str(zpath), "labels": 0, "paired": 0, "missing_images": 0}

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            with zipfile.ZipFile(zpath, "r") as zf:
                zf.extractall(tmp_path)
            data_dir = find_data_dir(tmp_path)
            labels = collect_labels(data_dir)
            src_info["labels"] = len(labels)

            for lbl_path, tag in labels:
                stem = lbl_path.stem
                img_src = sibling_image(lbl_path) or match_image(stem, index)
                if img_src is None:
                    src_info["missing_images"] += 1
                    report["missing_images"] += 1
                    if len(report["missing_samples"]) < 20:
                        report["missing_samples"].append(f"{tag}/{stem}.txt")
                    continue

                safe = normalize_key(f"{tag}_{stem}")[:120]
                if safe in seen:
                    report["skipped_duplicates"] += 1
                    continue
                seen.add(safe)

                ext = img_src.suffix.lower()
                dest_img = img_out / f"{safe}{ext}"
                dest_lbl = lbl_out / f"{safe}.txt"
                shutil.copy2(img_src, dest_img)
                shutil.copy2(lbl_path, dest_lbl)

                text = dest_lbl.read_text(encoding="utf-8").strip()
                if text:
                    report["with_nonempty_labels"] += 1
                report["total_pairs"] += 1
                src_info["paired"] += 1

        report["sources"].append(src_info)

    (out / "obj.names").write_text("mealybug\n", encoding="utf-8")
    report["out"] = str(out.resolve())
    return report


def main() -> None:
    args = parse_args()
    out = args.out.resolve()
    if not args.image_dir:
        print("No --image-dir: expecting images inside the zip(s).")
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True, exist_ok=True)

    report = merge_zips(args.zips, args.image_dir, out)
    manifest = out / "merge_manifest.json"
    manifest.write_text(json.dumps(report, indent=2), encoding="utf-8")

    print(f"Merged -> {out}")
    print(f"  Image index keys: {report['index_size']}")
    print(f"  Paired image+label: {report['total_pairs']}")
    print(f"  Non-empty labels: {report['with_nonempty_labels']}")
    print(f"  Missing images for labels: {report['missing_images']}")
    for s in report["sources"]:
        print(f"  - {Path(s['zip']).name}: {s['labels']} labels, {s['paired']} paired, {s['missing_images']} missing")
    if report["missing_samples"]:
        print("  Missing examples:", ", ".join(report["missing_samples"][:5]))
    print(f"Manifest: {manifest}")
    if report["total_pairs"] == 0:
        raise SystemExit("No pairs created — check --image-dir paths.")
    print("\nNext: python scripts/merge_annotations_into_v10.py")


if __name__ == "__main__":
    main()
