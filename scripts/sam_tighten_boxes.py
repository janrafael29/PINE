#!/usr/bin/env python3
"""
Tighten bounding boxes using SAM (Segment Anything Model).
For each existing YOLO label box, run SAM to get precise segmentation,
then replace the loose box with the tightest bounding box from the mask.

Usage:
  python sam_tighten_boxes.py --dataset-dir /workspace/datasets/mealybug_v13afix/train
  python sam_tighten_boxes.py --dataset-dir /workspace/datasets/mealybug_v13afix/train --limit 500
  python sam_tighten_boxes.py --dataset-dir /workspace/datasets/mealybug_v13afix/test
"""

import argparse
import shutil
import numpy as np
from pathlib import Path
from datetime import datetime

def parse_args():
    p = argparse.ArgumentParser(description="Tighten boxes with SAM")
    p.add_argument("--dataset-dir", type=str, required=True,
                   help="Path to dataset folder (with images/ and labels/)")
    p.add_argument("--sam-model", type=str, default="sam2.1_b",
                   help="SAM model variant: sam2.1_b, sam2.1_l, sam2.1_s")
    p.add_argument("--min-area", type=float, default=0.0001,
                   help="Minimum relative box area to keep (removes tiny noise)")
    p.add_argument("--max-area", type=float, default=0.25,
                   help="Maximum relative box area to keep (removes huge wrong boxes)")
    p.add_argument("--limit", type=int, default=None,
                   help="Limit number of images to process")
    p.add_argument("--output-dir", type=str, default=None,
                   help="Save tightened labels here (default: overwrite in-place)")
    p.add_argument("--backup", action="store_true", default=True,
                   help="Backup original labels before overwriting")
    return p.parse_args()


def load_sam_model(model_name):
    """Load SAM model for box-prompted segmentation."""
    from ultralytics import SAM
    model = SAM(model_name)
    return model


def read_yolo_labels(label_path):
    """Read YOLO format labels: cls cx cy w h"""
    boxes = []
    if not label_path.exists():
        return boxes
    for line in label_path.read_text().strip().split('\n'):
        if not line.strip():
            continue
        parts = line.strip().split()
        if len(parts) >= 5:
            boxes.append({
                'cls': int(parts[0]),
                'cx': float(parts[1]),
                'cy': float(parts[2]),
                'w': float(parts[3]),
                'h': float(parts[4]),
            })
    return boxes


def yolo_to_xyxy(box, img_w, img_h):
    """Convert YOLO [cx, cy, w, h] normalized to [x1, y1, x2, y2] pixels."""
    cx, cy, w, h = box['cx'], box['cy'], box['w'], box['h']
    x1 = (cx - w/2) * img_w
    y1 = (cy - h/2) * img_h
    x2 = (cx + w/2) * img_w
    y2 = (cy + h/2) * img_h
    return [max(0, x1), max(0, y1), min(img_w, x2), min(img_h, y2)]


def xyxy_to_yolo(x1, y1, x2, y2, img_w, img_h):
    """Convert pixel [x1, y1, x2, y2] to YOLO [cx, cy, w, h] normalized."""
    cx = ((x1 + x2) / 2) / img_w
    cy = ((y1 + y2) / 2) / img_h
    w = (x2 - x1) / img_w
    h = (y2 - y1) / img_h
    return cx, cy, w, h


def tighten_box_with_sam(sam_model, image_path, boxes_xyxy):
    """Run SAM with box prompts and return tightened boxes."""
    results = sam_model(image_path, bboxes=boxes_xyxy)

    tightened = []
    for i, result in enumerate(results):
        if result.masks is None or len(result.masks.data) == 0:
            tightened.append(boxes_xyxy[i])
            continue

        mask = result.masks.data[i].cpu().numpy() if i < len(result.masks.data) else result.masks.data[0].cpu().numpy()

        ys, xs = np.where(mask > 0.5)
        if len(xs) == 0 or len(ys) == 0:
            tightened.append(boxes_xyxy[i])
            continue

        x1_tight = float(xs.min())
        y1_tight = float(ys.min())
        x2_tight = float(xs.max())
        y2_tight = float(ys.max())

        # Sanity check: tightened box shouldn't be too different from original
        orig = boxes_xyxy[i]
        orig_area = (orig[2] - orig[0]) * (orig[3] - orig[1])
        tight_area = (x2_tight - x1_tight) * (y2_tight - y1_tight)

        if tight_area < orig_area * 0.1 or tight_area > orig_area * 3.0:
            tightened.append(boxes_xyxy[i])
        else:
            tightened.append([x1_tight, y1_tight, x2_tight, y2_tight])

    return tightened


def main():
    args = parse_args()

    dataset_dir = Path(args.dataset_dir)
    images_dir = dataset_dir / "images"
    labels_dir = dataset_dir / "labels"
    output_dir = Path(args.output_dir) if args.output_dir else labels_dir

    print("=" * 60)
    print("  SAM BOX TIGHTENING")
    print("=" * 60)
    print(f"  Images: {images_dir}")
    print(f"  Labels: {labels_dir}")
    print(f"  SAM model: {args.sam_model}")
    print(f"  Min area: {args.min_area}")
    print(f"  Max area: {args.max_area}")
    print()

    # Backup labels
    if args.backup and output_dir == labels_dir:
        backup_dir = dataset_dir / f"labels_pre_sam_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        shutil.copytree(labels_dir, backup_dir)
        print(f"  Backed up labels to: {backup_dir}")

    # Load SAM
    print("Loading SAM model...")
    sam_model = load_sam_model(args.sam_model)
    print("  SAM loaded!")

    # Find all images with labels
    image_extensions = {".jpg", ".jpeg", ".png", ".bmp"}
    image_files = sorted([f for f in images_dir.iterdir() if f.suffix.lower() in image_extensions])

    if args.limit:
        image_files = image_files[:args.limit]

    total = len(image_files)
    print(f"  Processing {total} images...")

    stats = {
        "processed": 0,
        "tightened": 0,
        "removed_tiny": 0,
        "removed_huge": 0,
        "unchanged": 0,
        "total_boxes_before": 0,
        "total_boxes_after": 0,
    }

    from PIL import Image

    for i, img_path in enumerate(image_files):
        if (i + 1) % 200 == 0:
            print(f"  [{i+1}/{total}] processed... "
                  f"(tightened={stats['tightened']}, removed={stats['removed_tiny']+stats['removed_huge']})")

        label_path = labels_dir / (img_path.stem + ".txt")
        if not label_path.exists():
            continue

        boxes = read_yolo_labels(label_path)
        if not boxes:
            continue

        # Get image dimensions
        with Image.open(img_path) as img:
            img_w, img_h = img.size

        stats["total_boxes_before"] += len(boxes)

        # Filter by area first
        valid_boxes = []
        for box in boxes:
            area = box['w'] * box['h']
            if area < args.min_area:
                stats["removed_tiny"] += 1
                continue
            if area > args.max_area:
                stats["removed_huge"] += 1
                continue
            valid_boxes.append(box)

        if not valid_boxes:
            # Write empty label
            output_path = output_dir / (img_path.stem + ".txt")
            output_path.write_text("")
            continue

        # Convert to xyxy for SAM
        boxes_xyxy = [yolo_to_xyxy(b, img_w, img_h) for b in valid_boxes]

        # Run SAM tightening
        try:
            tightened_xyxy = tighten_box_with_sam(sam_model, str(img_path), boxes_xyxy)
        except Exception as e:
            tightened_xyxy = boxes_xyxy
            stats["unchanged"] += 1

        # Convert back to YOLO format
        new_lines = []
        for j, tight_box in enumerate(tightened_xyxy):
            cx, cy, w, h = xyxy_to_yolo(tight_box[0], tight_box[1], tight_box[2], tight_box[3], img_w, img_h)
            # Clamp values
            cx = max(0, min(1, cx))
            cy = max(0, min(1, cy))
            w = max(0.001, min(1, w))
            h = max(0.001, min(1, h))
            new_lines.append(f"0 {cx:.6f} {cy:.6f} {w:.6f} {h:.6f}")

        # Write tightened labels
        output_path = output_dir / (img_path.stem + ".txt")
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text("\n".join(new_lines) + "\n")

        stats["tightened"] += 1
        stats["total_boxes_after"] += len(new_lines)
        stats["processed"] += 1

    print(f"\n{'='*60}")
    print(f"  SAM TIGHTENING COMPLETE")
    print(f"{'='*60}")
    print(f"  Images processed:    {stats['processed']}")
    print(f"  Boxes tightened:     {stats['tightened']} images")
    print(f"  Tiny boxes removed:  {stats['removed_tiny']}")
    print(f"  Huge boxes removed:  {stats['removed_huge']}")
    print(f"  Total boxes before:  {stats['total_boxes_before']}")
    print(f"  Total boxes after:   {stats['total_boxes_after']}")
    print(f"  Boxes removed total: {stats['total_boxes_before'] - stats['total_boxes_after']}")


if __name__ == "__main__":
    main()
