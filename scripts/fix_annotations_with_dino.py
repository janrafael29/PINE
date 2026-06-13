#!/usr/bin/env python3
"""
Fix under-annotated images by adding GroundingDINO predictions as new labels.
Also handles over-annotated and completely unlabeled images.

Strategies:
  1. UNDER-ANNOTATED (GT=1, DINO=8+): Add DINO predictions as extra labels
  2. UNLABELED (GT=0, DINO>0): Create label files from DINO predictions
  3. OVER-ANNOTATED (GT>>DINO): Flag for manual review (don't auto-delete)

Usage on Vast.ai:
  python fix_annotations_with_dino.py --mode audit          # dry-run, show what would change
  python fix_annotations_with_dino.py --mode fix            # actually fix labels
  python fix_annotations_with_dino.py --mode fix --strategy merge  # merge DINO + existing
  python fix_annotations_with_dino.py --mode fix --strategy replace  # replace with DINO only
"""

import argparse
import csv
import shutil
from pathlib import Path
from datetime import datetime

try:
    from groundingdino.util.inference import load_model, predict
    import groundingdino.datasets.transforms as T
    from PIL import Image
    import torch
    import huggingface_hub
    HAS_DINO = True
except ImportError:
    HAS_DINO = False


def parse_args():
    p = argparse.ArgumentParser(description="Fix annotations using GroundingDINO")
    p.add_argument("--dataset-dir", type=str, default="/workspace/datasets/mealybug_v13afix/train")
    p.add_argument("--mode", choices=["audit", "fix"], default="audit",
                   help="audit=dry-run, fix=actually modify labels")
    p.add_argument("--strategy", choices=["merge", "replace"], default="merge",
                   help="merge=add DINO predictions to existing; replace=overwrite with DINO")
    p.add_argument("--min-diff", type=int, default=3,
                   help="Minimum difference threshold to consider image under-annotated")
    p.add_argument("--box-threshold", type=float, default=0.30,
                   help="GroundingDINO box confidence threshold")
    p.add_argument("--text-threshold", type=float, default=0.25,
                   help="GroundingDINO text confidence threshold")
    p.add_argument("--text-prompt", type=str, default="mealybug . white insect . pest on leaf")
    p.add_argument("--iou-threshold", type=float, default=0.4,
                   help="IoU threshold for merging (avoid duplicate boxes)")
    p.add_argument("--max-gt", type=int, default=30,
                   help="Skip images with GT > this (dense annotations likely correct)")
    p.add_argument("--output-dir", type=str, default="/workspace/runs/annotation_fix")
    return p.parse_args()


def load_dino_model():
    """Load GroundingDINO model."""
    import groundingdino
    gd_path = Path(groundingdino.__file__).parent
    config_path = gd_path / "config" / "GroundingDINO_SwinT_OGC.py"

    weights_path = huggingface_hub.hf_hub_download(
        repo_id="ShilongLiu/GroundingDINO",
        filename="groundingdino_swint_ogc.pth",
    )

    model = load_model(str(config_path), weights_path)
    return model


def run_dino_on_image(model, image_path, text_prompt, box_threshold, text_threshold):
    """Run GroundingDINO and return boxes in YOLO format [cx, cy, w, h] normalized."""
    image_pil = Image.open(image_path).convert("RGB")
    w_img, h_img = image_pil.size

    transform = T.Compose([
        T.RandomResize([800], max_size=1333),
        T.ToTensor(),
        T.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
    ])
    image_tensor, _ = transform(image_pil, None)

    boxes, logits, phrases = predict(
        model=model,
        image=image_tensor,
        caption=text_prompt,
        box_threshold=box_threshold,
        text_threshold=text_threshold,
    )

    yolo_boxes = []
    for box, logit in zip(boxes, logits):
        cx, cy, bw, bh = box.tolist()
        yolo_boxes.append({
            "cx": cx, "cy": cy, "w": bw, "h": bh,
            "conf": logit.item()
        })

    return yolo_boxes


def read_yolo_labels(label_path):
    """Read existing YOLO label file."""
    boxes = []
    if not label_path.exists():
        return boxes
    with open(label_path, "r") as f:
        for line in f:
            parts = line.strip().split()
            if len(parts) >= 5:
                boxes.append({
                    "cls": int(parts[0]),
                    "cx": float(parts[1]),
                    "cy": float(parts[2]),
                    "w": float(parts[3]),
                    "h": float(parts[4]),
                })
    return boxes


def compute_iou(box1, box2):
    """Compute IoU between two boxes in [cx, cy, w, h] format."""
    x1_min = box1["cx"] - box1["w"] / 2
    y1_min = box1["cy"] - box1["h"] / 2
    x1_max = box1["cx"] + box1["w"] / 2
    y1_max = box1["cy"] + box1["h"] / 2

    x2_min = box2["cx"] - box2["w"] / 2
    y2_min = box2["cy"] - box2["h"] / 2
    x2_max = box2["cx"] + box2["w"] / 2
    y2_max = box2["cy"] + box2["h"] / 2

    inter_x = max(0, min(x1_max, x2_max) - max(x1_min, x2_min))
    inter_y = max(0, min(y1_max, y2_max) - max(y1_min, y2_min))
    inter_area = inter_x * inter_y

    area1 = box1["w"] * box1["h"]
    area2 = box2["w"] * box2["h"]
    union = area1 + area2 - inter_area

    return inter_area / union if union > 0 else 0


def merge_boxes(existing_boxes, dino_boxes, iou_threshold):
    """Merge DINO predictions with existing labels, avoiding duplicates."""
    merged = list(existing_boxes)  # keep all existing
    added = 0

    for dino_box in dino_boxes:
        is_duplicate = False
        for existing in existing_boxes:
            iou = compute_iou(dino_box, existing)
            if iou > iou_threshold:
                is_duplicate = True
                break

        if not is_duplicate:
            merged.append({
                "cls": 0,
                "cx": dino_box["cx"],
                "cy": dino_box["cy"],
                "w": dino_box["w"],
                "h": dino_box["h"],
            })
            added += 1

    return merged, added


def write_yolo_labels(label_path, boxes):
    """Write boxes to YOLO label file."""
    with open(label_path, "w") as f:
        for box in boxes:
            f.write(f"{box['cls']} {box['cx']:.6f} {box['cy']:.6f} {box['w']:.6f} {box['h']:.6f}\n")


def main():
    args = parse_args()
    dataset_dir = Path(args.dataset_dir)
    images_dir = dataset_dir / "images"
    labels_dir = dataset_dir / "labels"
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    print("=" * 60)
    print("  ANNOTATION FIX WITH GROUNDING DINO")
    print("=" * 60)
    print(f"  Mode:           {args.mode}")
    print(f"  Strategy:       {args.strategy}")
    print(f"  Min diff:       {args.min_diff}")
    print(f"  Box threshold:  {args.box_threshold}")
    print(f"  IoU threshold:  {args.iou_threshold}")
    print(f"  Max GT skip:    {args.max_gt}")
    print()

    if not HAS_DINO:
        print("ERROR: GroundingDINO not installed. Run: pip install groundingdino-py")
        return

    # Find all images
    image_extensions = {".jpg", ".jpeg", ".png", ".bmp"}
    image_files = sorted([f for f in images_dir.iterdir() if f.suffix.lower() in image_extensions])
    print(f"  Found {len(image_files)} images")

    # Identify under-annotated images
    under_annotated = []
    unlabeled = []
    good = []
    skip_dense = []

    for img_path in image_files:
        label_path = labels_dir / (img_path.stem + ".txt")
        existing = read_yolo_labels(label_path)
        gt_count = len(existing)

        if gt_count > args.max_gt:
            skip_dense.append(img_path)
        elif gt_count == 0:
            unlabeled.append(img_path)
        else:
            under_annotated.append((img_path, gt_count))

    print(f"  Unlabeled (GT=0):           {len(unlabeled)}")
    print(f"  Candidates to check:        {len(under_annotated)}")
    print(f"  Skipped (GT>{args.max_gt}): {len(skip_dense)}")
    print()

    # Load GroundingDINO
    print("Loading GroundingDINO...")
    model = load_dino_model()
    device = "cuda" if torch.cuda.is_available() else "cpu"
    model = model.to(device)
    print(f"  Model loaded on {device}")

    # Backup labels
    if args.mode == "fix":
        backup_dir = output_dir / f"labels_backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        shutil.copytree(labels_dir, backup_dir)
        print(f"  Backed up labels to: {backup_dir}")

    # Process all candidate images
    all_targets = unlabeled + [x[0] for x in under_annotated]
    total = len(all_targets)
    print(f"\nProcessing {total} images with GroundingDINO...")

    stats = {"fixed": 0, "added_boxes": 0, "skipped": 0, "created": 0}
    fix_log = []

    for i, img_path in enumerate(all_targets):
        if (i + 1) % 100 == 0:
            print(f"  [{i+1}/{total}] processed... (fixed={stats['fixed']}, added={stats['added_boxes']})")

        label_path = labels_dir / (img_path.stem + ".txt")
        existing = read_yolo_labels(label_path)
        gt_count = len(existing)

        # Run GroundingDINO
        try:
            dino_boxes = run_dino_on_image(
                model, img_path, args.text_prompt,
                args.box_threshold, args.text_threshold
            )
        except Exception as e:
            stats["skipped"] += 1
            continue

        dino_count = len(dino_boxes)
        diff = dino_count - gt_count

        # Only fix if DINO finds significantly more
        if diff < args.min_diff and gt_count > 0:
            stats["skipped"] += 1
            continue

        if args.strategy == "merge" and gt_count > 0:
            new_boxes, added = merge_boxes(existing, dino_boxes, args.iou_threshold)
            if added == 0:
                stats["skipped"] += 1
                continue
        elif args.strategy == "replace" or gt_count == 0:
            if dino_count == 0:
                stats["skipped"] += 1
                continue
            new_boxes = [{"cls": 0, "cx": b["cx"], "cy": b["cy"], "w": b["w"], "h": b["h"]} for b in dino_boxes]
            added = dino_count

        fix_log.append({
            "filename": img_path.name,
            "gt_before": gt_count,
            "dino_found": dino_count,
            "boxes_added": added,
            "gt_after": len(new_boxes),
            "action": "created" if gt_count == 0 else "merged",
        })

        if args.mode == "fix":
            write_yolo_labels(label_path, new_boxes)

        if gt_count == 0:
            stats["created"] += 1
        else:
            stats["fixed"] += 1
        stats["added_boxes"] += added

    # Summary
    print(f"\n{'='*60}")
    print(f"  {'AUDIT' if args.mode == 'audit' else 'FIX'} COMPLETE")
    print(f"{'='*60}")
    print(f"  Images fixed:        {stats['fixed']}")
    print(f"  Labels created:      {stats['created']}")
    print(f"  Total boxes added:   {stats['added_boxes']}")
    print(f"  Skipped (no change): {stats['skipped']}")
    if args.mode == "audit":
        print(f"\n  This was a DRY RUN. Re-run with --mode fix to apply changes.")

    # Save fix log
    log_path = output_dir / "fix_log.csv"
    if fix_log:
        with open(log_path, "w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=fix_log[0].keys())
            writer.writeheader()
            writer.writerows(fix_log)
        print(f"  Fix log: {log_path}")

    # Also save a summary
    summary_path = output_dir / "fix_summary.txt"
    with open(summary_path, "w") as f:
        f.write(f"Annotation Fix Summary\n")
        f.write(f"{'='*40}\n")
        f.write(f"Date: {datetime.now().isoformat()}\n")
        f.write(f"Mode: {args.mode}\n")
        f.write(f"Strategy: {args.strategy}\n")
        f.write(f"Box threshold: {args.box_threshold}\n")
        f.write(f"Text threshold: {args.text_threshold}\n")
        f.write(f"IoU threshold: {args.iou_threshold}\n")
        f.write(f"Min diff: {args.min_diff}\n")
        f.write(f"Max GT skip: {args.max_gt}\n")
        f.write(f"\nResults:\n")
        f.write(f"  Fixed: {stats['fixed']}\n")
        f.write(f"  Created: {stats['created']}\n")
        f.write(f"  Boxes added: {stats['added_boxes']}\n")
        f.write(f"  Skipped: {stats['skipped']}\n")
    print(f"  Summary: {summary_path}")


if __name__ == "__main__":
    main()
