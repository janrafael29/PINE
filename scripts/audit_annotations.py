#!/usr/bin/env python3
"""
Annotation Audit Tool — Find missing/incorrect labels in the training set.

Runs the current best model on training images and compares predictions
against existing labels to identify:
  1. MISSING ANNOTATIONS: Model detects mealybugs where no label exists (likely real bugs missed by annotator)
  2. GHOST ANNOTATIONS: Labels exist where model sees nothing (possible annotation errors)
  3. LOOSE BOXES: Labels with poor IoU match to predictions (annotation alignment issues)

Usage:
  python scripts/audit_annotations.py
  python scripts/audit_annotations.py --model runs/retrain/mealybug_v13afix/weights/best.pt
  python scripts/audit_annotations.py --limit 500 --conf 0.4
"""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Audit annotations against model predictions")
    p.add_argument(
        "--model",
        type=Path,
        default=ROOT / "runs" / "retrain" / "mealybug_v13afix" / "weights" / "best.pt",
    )
    p.add_argument(
        "--images",
        type=Path,
        default=ROOT / "datasets" / "mealybug_v13afix" / "train" / "images",
    )
    p.add_argument(
        "--labels",
        type=Path,
        default=ROOT / "datasets" / "mealybug_v13afix" / "train" / "labels",
    )
    p.add_argument("--conf", type=float, default=0.35, help="Confidence threshold for predictions")
    p.add_argument("--iou-thresh", type=float, default=0.3, help="IoU threshold for matching pred to GT")
    p.add_argument("--limit", type=int, default=0, help="Limit number of images to process (0=all)")
    p.add_argument(
        "--out",
        type=Path,
        default=ROOT / "runs" / "audit" / "annotation_audit.json",
    )
    return p.parse_args()


def xywh_to_xyxy(box, img_w, img_h):
    """Convert YOLO normalized xywh to pixel xyxy."""
    cx, cy, w, h = box
    x1 = (cx - w / 2) * img_w
    y1 = (cy - h / 2) * img_h
    x2 = (cx + w / 2) * img_w
    y2 = (cy + h / 2) * img_h
    return [x1, y1, x2, y2]


def compute_iou(box1, box2):
    """Compute IoU between two xyxy boxes."""
    x1 = max(box1[0], box2[0])
    y1 = max(box1[1], box2[1])
    x2 = min(box1[2], box2[2])
    y2 = min(box1[3], box2[3])

    inter = max(0, x2 - x1) * max(0, y2 - y1)
    area1 = (box1[2] - box1[0]) * (box1[3] - box1[1])
    area2 = (box2[2] - box2[0]) * (box2[3] - box2[1])
    union = area1 + area2 - inter

    return inter / union if union > 0 else 0.0


def load_yolo_labels(label_path, img_w, img_h):
    """Load YOLO format labels and convert to xyxy."""
    boxes = []
    if not label_path.exists():
        return boxes
    for line in label_path.read_text().strip().split("\n"):
        if not line.strip():
            continue
        parts = line.strip().split()
        if len(parts) >= 5:
            cx, cy, w, h = float(parts[1]), float(parts[2]), float(parts[3]), float(parts[4])
            boxes.append(xywh_to_xyxy([cx, cy, w, h], img_w, img_h))
    return boxes


def main():
    args = parse_args()

    from ultralytics import YOLO
    from PIL import Image

    print(f"Loading model: {args.model}")
    model = YOLO(str(args.model))

    image_dir = args.images
    label_dir = args.labels

    image_files = sorted(image_dir.glob("*.*"))
    image_files = [f for f in image_files if f.suffix.lower() in (".jpg", ".jpeg", ".png", ".bmp")]

    if args.limit > 0:
        image_files = image_files[: args.limit]

    print(f"Processing {len(image_files)} images...")
    print(f"Confidence threshold: {args.conf}")
    print(f"IoU matching threshold: {args.iou_thresh}")

    missing_annotations = []  # Model found something, no GT label
    ghost_annotations = []  # GT label exists, model sees nothing
    loose_boxes = []  # Both exist but IoU is low
    stats = {
        "total_images": len(image_files),
        "total_gt_boxes": 0,
        "total_pred_boxes": 0,
        "matched": 0,
        "missing_annotation_count": 0,
        "ghost_annotation_count": 0,
        "loose_box_count": 0,
    }

    for i, img_path in enumerate(image_files):
        if (i + 1) % 500 == 0:
            print(f"  Progress: {i + 1}/{len(image_files)}")

        img = Image.open(img_path)
        img_w, img_h = img.size

        label_path = label_dir / (img_path.stem + ".txt")
        gt_boxes = load_yolo_labels(label_path, img_w, img_h)

        results = model.predict(str(img_path), conf=args.conf, verbose=False)
        pred_boxes = []
        pred_confs = []
        if results and results[0].boxes is not None:
            for box in results[0].boxes:
                xyxy = box.xyxy[0].cpu().numpy().tolist()
                conf = float(box.conf[0])
                pred_boxes.append(xyxy)
                pred_confs.append(conf)

        stats["total_gt_boxes"] += len(gt_boxes)
        stats["total_pred_boxes"] += len(pred_boxes)

        gt_matched = [False] * len(gt_boxes)
        pred_matched = [False] * len(pred_boxes)

        for pi, pbox in enumerate(pred_boxes):
            best_iou = 0
            best_gi = -1
            for gi, gbox in enumerate(gt_boxes):
                if gt_matched[gi]:
                    continue
                iou = compute_iou(pbox, gbox)
                if iou > best_iou:
                    best_iou = iou
                    best_gi = gi

            if best_iou >= args.iou_thresh and best_gi >= 0:
                gt_matched[best_gi] = True
                pred_matched[pi] = True
                stats["matched"] += 1

                if best_iou < 0.5:
                    loose_boxes.append({
                        "image": img_path.name,
                        "pred_box": [round(x, 1) for x in pbox],
                        "gt_box": [round(x, 1) for x in gt_boxes[best_gi]],
                        "iou": round(best_iou, 3),
                        "conf": round(pred_confs[pi], 3),
                    })
                    stats["loose_box_count"] += 1

        for pi, matched in enumerate(pred_matched):
            if not matched:
                missing_annotations.append({
                    "image": img_path.name,
                    "pred_box": [round(x, 1) for x in pred_boxes[pi]],
                    "conf": round(pred_confs[pi], 3),
                })
                stats["missing_annotation_count"] += 1

        for gi, matched in enumerate(gt_matched):
            if not matched:
                ghost_annotations.append({
                    "image": img_path.name,
                    "gt_box": [round(x, 1) for x in gt_boxes[gi]],
                })
                stats["ghost_annotation_count"] += 1

    print(f"\n{'='*60}")
    print(f"AUDIT COMPLETE")
    print(f"{'='*60}")
    print(f"Total images processed:    {stats['total_images']}")
    print(f"Total GT boxes:            {stats['total_gt_boxes']}")
    print(f"Total predictions:         {stats['total_pred_boxes']}")
    print(f"Matched (IoU >= {args.iou_thresh}):    {stats['matched']}")
    print(f"")
    print(f"MISSING ANNOTATIONS:       {stats['missing_annotation_count']}")
    print(f"  (Model found mealybugs with no GT label — likely real bugs missed by annotator)")
    print(f"")
    print(f"GHOST ANNOTATIONS:         {stats['ghost_annotation_count']}")
    print(f"  (GT labels where model sees nothing — possible annotation errors)")
    print(f"")
    print(f"LOOSE BOXES:               {stats['loose_box_count']}")
    print(f"  (Matched but IoU < 0.5 — annotation alignment issues)")

    # Sort by confidence (highest first = most likely real misses)
    missing_annotations.sort(key=lambda x: x["conf"], reverse=True)

    report = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "config": {
            "model": str(args.model),
            "conf": args.conf,
            "iou_thresh": args.iou_thresh,
            "images_dir": str(args.images),
            "labels_dir": str(args.labels),
        },
        "stats": stats,
        "missing_annotations_top50": missing_annotations[:50],
        "ghost_annotations_top50": ghost_annotations[:50],
        "loose_boxes_top50": loose_boxes[:50],
    }

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"\nFull report: {args.out}")

    if stats["missing_annotation_count"] > 100:
        print(f"\n*** WARNING: {stats['missing_annotation_count']} potential missing annotations detected!")
        print(f"    Top 5 high-confidence missing labels:")
        for item in missing_annotations[:5]:
            print(f"      {item['image']} @ conf={item['conf']}")


if __name__ == "__main__":
    main()
