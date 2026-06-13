#!/usr/bin/env python3
"""
Auto-Fix Annotations — Automatically repair missing/incorrect labels.

Strategy:
  1. MISSING LABELS (model detects, no GT): If model confidence >= high_conf,
     auto-add the prediction as a new ground-truth label.
  2. GHOST LABELS (GT exists, model sees nothing): If model doesn't detect
     anything near the GT box even at very low conf, mark for removal.
  3. LOOSE BOXES (low IoU match): Replace GT box with model's prediction
     (model's localization is often better than manual annotation for small objects).

This is SAFE because:
  - Only HIGH confidence predictions are auto-added (very likely correct)
  - Ghost labels are only removed if they fail at very low confidence (0.10)
  - Original labels are backed up before any changes
  - A dry-run mode lets you preview changes first

Usage:
  # DRY RUN first (no changes, just shows what would happen):
  python scripts/auto_fix_annotations.py --dry-run

  # Apply fixes:
  python scripts/auto_fix_annotations.py --apply

  # Conservative mode (only add missing, don't remove ghosts):
  python scripts/auto_fix_annotations.py --apply --no-remove

  # Aggressive mode (lower threshold for adding):
  python scripts/auto_fix_annotations.py --apply --add-conf 0.40
"""

from __future__ import annotations

import argparse
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path
from collections import defaultdict

ROOT = Path(__file__).resolve().parents[1]


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Auto-fix annotations using model predictions")
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
    p.add_argument(
        "--add-conf", type=float, default=0.50,
        help="Min confidence to auto-add a missing annotation (default 0.50 = conservative)"
    )
    p.add_argument(
        "--remove-conf", type=float, default=0.10,
        help="If model doesn't detect at this low conf, label is likely wrong (default 0.10)"
    )
    p.add_argument(
        "--tighten-iou", type=float, default=0.35,
        help="If matched IoU is below this, replace GT box with model prediction"
    )
    p.add_argument(
        "--match-iou", type=float, default=0.3,
        help="IoU threshold for matching predictions to GT boxes"
    )
    p.add_argument("--limit", type=int, default=0, help="Limit images (0=all)")
    p.add_argument("--dry-run", action="store_true", help="Preview changes without modifying files")
    p.add_argument("--apply", action="store_true", help="Actually apply the fixes")
    p.add_argument("--no-remove", action="store_true", help="Don't remove ghost annotations (conservative)")
    p.add_argument("--no-tighten", action="store_true", help="Don't tighten loose boxes")
    p.add_argument(
        "--backup-dir",
        type=Path,
        default=ROOT / "runs" / "audit" / "labels_backup",
    )
    p.add_argument(
        "--out",
        type=Path,
        default=ROOT / "runs" / "audit" / "auto_fix_report.json",
    )
    return p.parse_args()


def xyxy_to_yolo(box, img_w, img_h):
    """Convert pixel xyxy to YOLO normalized xywh."""
    x1, y1, x2, y2 = box
    cx = ((x1 + x2) / 2) / img_w
    cy = ((y1 + y2) / 2) / img_h
    w = (x2 - x1) / img_w
    h = (y2 - y1) / img_h
    return [cx, cy, w, h]


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
    """Load YOLO labels → list of (class_id, xyxy, raw_line)."""
    entries = []
    if not label_path.exists():
        return entries
    for line in label_path.read_text().strip().split("\n"):
        if not line.strip():
            continue
        parts = line.strip().split()
        if len(parts) >= 5:
            cls_id = int(parts[0])
            cx, cy, w, h = float(parts[1]), float(parts[2]), float(parts[3]), float(parts[4])
            xyxy = xywh_to_xyxy([cx, cy, w, h], img_w, img_h)
            entries.append({"cls": cls_id, "xyxy": xyxy, "raw": line.strip()})
    return entries


def format_yolo_line(cls_id, xyxy, img_w, img_h):
    """Format xyxy box as YOLO label line."""
    cx, cy, w, h = xyxy_to_yolo(xyxy, img_w, img_h)
    cx = max(0.0, min(1.0, cx))
    cy = max(0.0, min(1.0, cy))
    w = max(0.001, min(1.0, w))
    h = max(0.001, min(1.0, h))
    return f"{cls_id} {cx:.6f} {cy:.6f} {w:.6f} {h:.6f}"


def main():
    args = parse_args()

    if not args.dry_run and not args.apply:
        print("ERROR: Must specify --dry-run or --apply")
        print("  Dry run first:  python scripts/auto_fix_annotations.py --dry-run")
        print("  Apply fixes:    python scripts/auto_fix_annotations.py --apply")
        return

    from ultralytics import YOLO
    from PIL import Image

    print(f"{'DRY RUN' if args.dry_run else 'APPLYING FIXES'}")
    print(f"Model: {args.model}")
    print(f"Add threshold: conf >= {args.add_conf}")
    print(f"Remove threshold: model misses at conf {args.remove_conf}")
    print(f"Tighten threshold: matched IoU < {args.tighten_iou}")
    print()

    model = YOLO(str(args.model))

    image_files = sorted(args.images.glob("*.*"))
    image_files = [f for f in image_files if f.suffix.lower() in (".jpg", ".jpeg", ".png", ".bmp")]
    if args.limit > 0:
        image_files = image_files[:args.limit]

    print(f"Processing {len(image_files)} images...\n")

    # Backup original labels
    if args.apply and not args.backup_dir.exists():
        print(f"Backing up labels to: {args.backup_dir}")
        shutil.copytree(args.labels, args.backup_dir)
        print("  Backup complete.\n")

    stats = {
        "images_processed": 0,
        "labels_added": 0,
        "labels_removed": 0,
        "labels_tightened": 0,
        "files_modified": 0,
    }
    changes_log = []

    for i, img_path in enumerate(image_files):
        if (i + 1) % 1000 == 0:
            print(f"  Progress: {i + 1}/{len(image_files)} | Added: {stats['labels_added']} | Removed: {stats['labels_removed']} | Tightened: {stats['labels_tightened']}")

        img = Image.open(img_path)
        img_w, img_h = img.size

        label_path = args.labels / (img_path.stem + ".txt")
        gt_entries = load_yolo_labels(label_path, img_w, img_h)

        # Run model at ADD threshold (for finding missing annotations)
        results_add = model.predict(str(img_path), conf=args.add_conf, verbose=False)
        pred_boxes_add = []
        pred_confs_add = []
        if results_add and results_add[0].boxes is not None:
            for box in results_add[0].boxes:
                pred_boxes_add.append(box.xyxy[0].cpu().numpy().tolist())
                pred_confs_add.append(float(box.conf[0]))

        # Run model at REMOVE threshold (for checking ghost labels)
        results_low = model.predict(str(img_path), conf=args.remove_conf, verbose=False)
        pred_boxes_low = []
        if results_low and results_low[0].boxes is not None:
            for box in results_low[0].boxes:
                pred_boxes_low.append(box.xyxy[0].cpu().numpy().tolist())

        # --- STEP 1: Find MISSING annotations ---
        new_labels = []
        for pi, pbox in enumerate(pred_boxes_add):
            matched = False
            for gt in gt_entries:
                if compute_iou(pbox, gt["xyxy"]) >= args.match_iou:
                    matched = True
                    break
            if not matched:
                new_labels.append({
                    "xyxy": pbox,
                    "conf": pred_confs_add[pi],
                })
                stats["labels_added"] += 1
                changes_log.append({
                    "type": "added",
                    "image": img_path.name,
                    "box": [round(x, 1) for x in pbox],
                    "conf": round(pred_confs_add[pi], 3),
                })

        # --- STEP 2: Find GHOST annotations ---
        remove_indices = set()
        if not args.no_remove:
            for gi, gt in enumerate(gt_entries):
                has_any_pred = False
                for pbox in pred_boxes_low:
                    if compute_iou(gt["xyxy"], pbox) >= 0.2:
                        has_any_pred = True
                        break
                if not has_any_pred:
                    remove_indices.add(gi)
                    stats["labels_removed"] += 1
                    changes_log.append({
                        "type": "removed",
                        "image": img_path.name,
                        "box": [round(x, 1) for x in gt["xyxy"]],
                        "reason": f"model sees nothing at conf={args.remove_conf}",
                    })

        # --- STEP 3: Tighten LOOSE boxes ---
        tighten_map = {}  # gt_index -> new_xyxy
        if not args.no_tighten:
            for pi, pbox in enumerate(pred_boxes_add):
                best_iou = 0
                best_gi = -1
                for gi, gt in enumerate(gt_entries):
                    if gi in remove_indices:
                        continue
                    iou = compute_iou(pbox, gt["xyxy"])
                    if iou > best_iou:
                        best_iou = iou
                        best_gi = gi

                if best_gi >= 0 and args.match_iou <= best_iou < args.tighten_iou:
                    tighten_map[best_gi] = pbox
                    stats["labels_tightened"] += 1
                    changes_log.append({
                        "type": "tightened",
                        "image": img_path.name,
                        "old_box": [round(x, 1) for x in gt_entries[best_gi]["xyxy"]],
                        "new_box": [round(x, 1) for x in pbox],
                        "old_iou": round(best_iou, 3),
                    })

        # --- WRITE FIXED LABELS ---
        file_changed = bool(new_labels or remove_indices or tighten_map)
        if file_changed:
            stats["files_modified"] += 1

            if args.apply:
                lines = []
                for gi, gt in enumerate(gt_entries):
                    if gi in remove_indices:
                        continue
                    if gi in tighten_map:
                        lines.append(format_yolo_line(gt["cls"], tighten_map[gi], img_w, img_h))
                    else:
                        lines.append(gt["raw"])

                for new in new_labels:
                    lines.append(format_yolo_line(0, new["xyxy"], img_w, img_h))

                label_path.write_text("\n".join(lines) + "\n" if lines else "", encoding="utf-8")

        stats["images_processed"] += 1

    # --- SUMMARY ---
    print(f"\n{'='*60}")
    print(f"{'DRY RUN COMPLETE' if args.dry_run else 'FIXES APPLIED'}")
    print(f"{'='*60}")
    print(f"Images processed:    {stats['images_processed']}")
    print(f"Files modified:      {stats['files_modified']}")
    print(f"")
    print(f"Labels ADDED:        {stats['labels_added']}")
    print(f"  (High-confidence predictions with no existing GT)")
    print(f"")
    print(f"Labels REMOVED:      {stats['labels_removed']}")
    print(f"  (GT boxes where model sees nothing even at {args.remove_conf} conf)")
    print(f"")
    print(f"Labels TIGHTENED:    {stats['labels_tightened']}")
    print(f"  (GT boxes replaced with better-aligned model predictions)")

    if args.dry_run:
        print(f"\n>>> To apply these changes, run with --apply <<<")
        print(f">>> Original labels will be backed up to: {args.backup_dir}")

    if args.apply:
        print(f"\n  Original labels backed up at: {args.backup_dir}")
        print(f"  To UNDO: copy backup labels back to {args.labels}")

    # Save report
    report = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "mode": "dry_run" if args.dry_run else "applied",
        "config": {
            "model": str(args.model),
            "add_conf": args.add_conf,
            "remove_conf": args.remove_conf,
            "tighten_iou": args.tighten_iou,
            "no_remove": args.no_remove,
            "no_tighten": args.no_tighten,
        },
        "stats": stats,
        "changes_sample": changes_log[:100],
    }

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"\nReport: {args.out}")


if __name__ == "__main__":
    main()
