#!/usr/bin/env python3
"""
Train mealybug_v14 — YOLO26s @ 1280px with all optimizations.
Target: 80% mAP@0.5

Prerequisites:
  1. Run annotation audit first:
     python scripts/audit_annotations.py
  2. Fix any missing/ghost annotations found
  3. Then run this training script

Usage:
  python scripts/train_v14.py
  python scripts/train_v14.py --batch 16  # if you have A100 (40GB)
  python scripts/train_v14.py --resume    # resume interrupted training
"""

from __future__ import annotations

import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Train mealybug_v14")
    p.add_argument("--batch", type=int, default=32, help="Batch size (32 for 2x RTX 5090)")
    p.add_argument("--device", type=str, default="0,1", help="GPU devices (0,1 for dual GPU)")
    p.add_argument("--resume", action="store_true", help="Resume from last checkpoint")
    p.add_argument("--no-freeze", action="store_true", help="Skip backbone freezing")
    return p.parse_args()


def main():
    args = parse_args()

    from ultralytics import YOLO

    config = ROOT / "configs" / "train_v14.yaml"
    data_yaml = ROOT / "datasets" / "mealybug_v13afix" / "data.yaml"

    # Use YOLO26s as base architecture
    print("=" * 60)
    print("  MEALYBUG V14 TRAINING")
    print("  Architecture: YOLO26s (9.6M params)")
    print("  Input: 1280x1280")
    print("  Epochs: 200 (patience=50)")
    print("  Target: 80% mAP@0.5")
    print("=" * 60)

    if args.resume:
        last_pt = ROOT / "runs" / "retrain" / "mealybug_v14" / "weights" / "last.pt"
        if not last_pt.exists():
            raise SystemExit(f"No checkpoint to resume: {last_pt}")
        print(f"\nResuming from: {last_pt}")
        model = YOLO(str(last_pt))
        model.train(resume=True)
        return

    # Initialize YOLO26s with pretrained weights
    model = YOLO("yolo26s.pt")

    # Transfer learning: load v13afix head weights where compatible
    v13afix_weights = ROOT / "runs" / "retrain" / "mealybug_v13afix" / "weights" / "best.pt"
    if v13afix_weights.exists():
        print(f"\nNote: v13afix weights available at {v13afix_weights}")
        print("  Using yolo26s.pt (COCO pretrained) as base since architecture differs from v13afix (nano)")
        print("  The model will learn mealybug features from scratch on the s-variant backbone")

    freeze_layers = 10 if not args.no_freeze else 0

    results = model.train(
        data=str(data_yaml),
        name="mealybug_v14",
        project=str(ROOT / "runs" / "retrain"),
        exist_ok=True,

        # Core
        epochs=200,
        imgsz=1280,
        batch=args.batch,
        device=args.device,
        workers=8,

        # Optimizer
        optimizer="AdamW",
        lr0=0.0001,
        lrf=0.005,
        cos_lr=True,
        warmup_epochs=5,
        weight_decay=0.0005,
        patience=50,
        freeze=freeze_layers,

        # Loss
        box=10.0,
        cls=1.0,
        dfl=1.5,

        # Augmentation
        dropout=0.1,
        close_mosaic=30,
        copy_paste=0.3,
        scale=0.9,
        rect=False,

        # NMS
        conf=0.25,
        iou=0.45,

        # Output
        plots=True,
        save=True,
        val=True,
        verbose=True,
    )

    print("\n" + "=" * 60)
    print("  TRAINING COMPLETE")
    print("=" * 60)
    print(f"  Best weights: runs/retrain/mealybug_v14/weights/best.pt")
    print(f"  Last weights: runs/retrain/mealybug_v14/weights/last.pt")
    print(f"\n  Next steps:")
    print(f"    1. Evaluate: python scripts/evaluate_model_accuracy.py --model runs/retrain/mealybug_v14/weights/best.pt --data datasets/mealybug_v13afix/data.yaml")
    print(f"    2. Evaluate with TTA: python scripts/eval_v14_tta.py")
    print(f"    3. Export TFLite: yolo export model=runs/retrain/mealybug_v14/weights/best.pt format=tflite imgsz=640")


if __name__ == "__main__":
    main()
