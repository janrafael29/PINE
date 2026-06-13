#!/usr/bin/env python3
"""
Augment a reviewed YOLO batch (images/ + labels/) before merging into datasets/train.

Uses pest-safe transforms aligned with Roboflow (flip, 90°, ±15° rotate, mild brightness,
light noise). Skips heavy blur / mosaic.

Requires: pip install albumentations opencv-python-headless

Usage:
  python scripts/augment_yolo_subset.py --batch field_batches/2026-05-19_collected
  python scripts/augment_yolo_subset.py --batch ... --copies-per-image 3
"""

from __future__ import annotations

import argparse
import random
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Augment a YOLO field batch in-place.")
    p.add_argument("--batch", type=Path, required=True, help="Folder with images/ (+ labels/).")
    p.add_argument(
        "--labels-dir",
        type=str,
        default="labels",
        help="Label subfolder name (e.g. labels or labels_reviewed).",
    )
    p.add_argument(
        "--name-prefix",
        type=str,
        default="",
        help="Only augment image files whose stem starts with this prefix.",
    )
    p.add_argument(
        "--copies-per-image",
        type=int,
        default=3,
        help="Extra augmented copies per source image (default 3 → ~4× with original).",
    )
    p.add_argument("--seed", type=int, default=42, help="RNG seed for reproducibility.")
    p.add_argument(
        "--output-suffix",
        type=str,
        default="_aug",
        help="Filename suffix before index, e.g. photo_aug0.jpg",
    )
    p.add_argument("--dry-run", action="store_true")
    return p.parse_args()


def read_yolo_labels(path: Path) -> tuple[list[list[float]], list[int]]:
    boxes: list[list[float]] = []
    classes: list[int] = []
    if not path.is_file():
        return boxes, classes
    for line in path.read_text(encoding="utf-8").strip().splitlines():
        parts = line.split()
        if len(parts) < 5:
            continue
        cls = int(float(parts[0]))
        boxes.append([float(parts[1]), float(parts[2]), float(parts[3]), float(parts[4])])
        classes.append(cls)
    return boxes, classes


def sanitize_boxes(
    boxes: list[list[float]], classes: list[int]
) -> tuple[list[list[float]], list[int]]:
    """Drop invalid YOLO boxes and clip centers/sizes to [0, 1]."""
    out_b: list[list[float]] = []
    out_c: list[int] = []
    for cls, (cx, cy, w, h) in zip(classes, boxes):
        if w <= 1e-6 or h <= 1e-6:
            continue
        w = min(1.0, max(w, 1e-6))
        h = min(1.0, max(h, 1e-6))
        cx = min(1.0 - w / 2, max(w / 2, cx))
        cy = min(1.0 - h / 2, max(h / 2, cy))
        x1, y1 = cx - w / 2, cy - h / 2
        x2, y2 = cx + w / 2, cy + h / 2
        if x1 < 0 or y1 < 0 or x2 > 1 or y2 > 1:
            continue
        out_b.append([cx, cy, w, h])
        out_c.append(cls)
    return out_b, out_c


def write_yolo_labels(path: Path, boxes: list[list[float]], classes: list[int]) -> None:
    lines: list[str] = []
    for cls, (cx, cy, w, h) in zip(classes, boxes):
        lines.append(f"{cls} {cx:.6f} {cy:.6f} {w:.6f} {h:.6f}")
    path.write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")


def build_pipeline():
    try:
        import albumentations as A
    except ImportError as e:
        raise SystemExit(
            "Install albumentations: pip install albumentations opencv-python-headless"
        ) from e

    return A.Compose(
        [
            A.HorizontalFlip(p=0.5),
            A.VerticalFlip(p=0.5),
            A.RandomRotate90(p=0.5),
            A.Rotate(limit=15, border_mode=0, p=0.5),
            A.RandomBrightnessContrast(
                brightness_limit=0.11,
                contrast_limit=0.11,
                p=0.5,
            ),
            A.GaussNoise(std_range=(0.02, 0.08), p=0.35),
        ],
        bbox_params=A.BboxParams(
            format="yolo",
            label_fields=["class_labels"],
            min_visibility=0.35,
        ),
    )


def is_source_image(path: Path, output_suffix: str, version_prefix: str = "") -> bool:
    stem = path.stem
    if output_suffix and output_suffix in stem:
        return False
    if version_prefix and stem.startswith(f"{version_prefix}_"):
        return False
    return True


def augment_batch(
    batch: Path,
    *,
    labels_dir: str = "labels",
    name_prefix: str = "",
    copies_per_image: int = 3,
    seed: int = 42,
    output_suffix: str = "_aug",
    version_prefix: str = "",
    dry_run: bool = False,
) -> dict[str, int]:
    batch = batch.resolve()
    img_dir = batch / "images"
    lbl_dir = batch / labels_dir
    if not img_dir.is_dir():
        raise SystemExit(f"Missing {img_dir}")
    if not lbl_dir.is_dir():
        raise SystemExit(f"Missing {lbl_dir}")

    try:
        import cv2
    except ImportError as e:
        raise SystemExit("pip install opencv-python-headless") from e

    pipeline = build_pipeline()
    rng = random.Random(seed)

    sources = sorted(
        p
        for p in img_dir.iterdir()
        if p.is_file()
        and p.suffix.lower() in IMAGE_EXTS
        and is_source_image(p, output_suffix, version_prefix)
        and (not name_prefix or p.stem.startswith(name_prefix))
    )
    if not sources:
        raise SystemExit(f"No images to augment in {img_dir}")

    created = skipped_empty = 0
    for img_path in sources:
        stem = img_path.stem
        lbl_path = lbl_dir / f"{stem}.txt"
        boxes, classes = read_yolo_labels(lbl_path)
        boxes, classes = sanitize_boxes(boxes, classes)

        image = cv2.imread(str(img_path))
        if image is None:
            continue

        for i in range(copies_per_image):
            if version_prefix:
                out_stem = f"{version_prefix}_{stem}_{i}"
            else:
                out_stem = f"{stem}{output_suffix}{i}"
            out_img = img_dir / f"{out_stem}{img_path.suffix.lower()}"
            out_lbl = lbl_dir / f"{out_stem}.txt"
            if out_img.exists():
                continue

            if not boxes:
                if dry_run:
                    skipped_empty += 1
                    continue
                shutil.copy2(img_path, out_img)
                out_lbl.write_text("", encoding="utf-8")
                created += 1
                continue

            seed_i = rng.randint(0, 2**31 - 1)
            augmented = pipeline(
                image=image,
                bboxes=boxes,
                class_labels=classes,
                seed=seed_i,
            )
            new_boxes = augmented["bboxes"]
            new_classes = augmented["class_labels"]
            if not new_boxes:
                continue

            if dry_run:
                created += 1
                continue

            cv2.imwrite(str(out_img), augmented["image"])
            write_yolo_labels(out_lbl, list(new_boxes), list(new_classes))
            created += 1

    total = len([p for p in img_dir.iterdir() if p.is_file() and p.suffix.lower() in IMAGE_EXTS])
    return {
        "batch": str(batch),
        "sources": len(sources),
        "created": created,
        "negatives_copied": skipped_empty,
        "total_images": total,
    }


def main() -> None:
    args = parse_args()
    stats = augment_batch(
        args.batch,
        labels_dir=args.labels_dir,
        name_prefix=args.name_prefix,
        copies_per_image=args.copies_per_image,
        seed=args.seed,
        output_suffix=args.output_suffix,
        dry_run=args.dry_run,
    )
    print(f"Batch: {stats['batch']}")
    print(f"Source images: {stats['sources']}")
    print(f"Augmented copies created: {stats['created']}")
    if stats["negatives_copied"]:
        print(f"Negatives copied (no geom aug): {stats['negatives_copied']}")
    print(f"Total images in batch now: {stats['total_images']}")
    if not args.dry_run:
        print("Next: merge into training pool, then build_v13afix_dataset.py")


if __name__ == "__main__":
    main()
