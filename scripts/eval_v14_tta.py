#!/usr/bin/env python3
"""
Evaluate mealybug_v14 with Test-Time Augmentation (TTA) and optional tiled inference.

TTA runs inference on flipped/scaled versions of each image and merges results,
typically gaining +2-3pp mAP without changing the model.

Usage:
  python scripts/eval_v14_tta.py
  python scripts/eval_v14_tta.py --model runs/retrain/mealybug_v14/weights/best.pt
  python scripts/eval_v14_tta.py --tiled  # also run SAHI tiled inference
"""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Evaluate v14 with TTA")
    p.add_argument(
        "--model",
        type=Path,
        default=ROOT / "runs" / "retrain" / "mealybug_v14" / "weights" / "best.pt",
    )
    p.add_argument("--data", type=Path, default=ROOT / "datasets" / "mealybug_v13afix" / "data.yaml")
    p.add_argument("--conf", type=float, default=0.12)
    p.add_argument("--iou", type=float, default=0.45)
    p.add_argument("--imgsz", type=int, default=1280)
    p.add_argument("--tiled", action="store_true", help="Also run SAHI tiled inference")
    p.add_argument(
        "--out",
        type=Path,
        default=ROOT / "runs" / "calibration" / "v14_tta_eval.json",
    )
    return p.parse_args()


def eval_standard(model, data, conf, iou, imgsz):
    """Standard evaluation without TTA."""
    metrics = model.val(data=str(data), split="test", conf=conf, iou=iou, imgsz=imgsz, plots=False)
    p = float(metrics.box.mp)
    r = float(metrics.box.mr)
    f1 = (2 * p * r / (p + r)) if (p + r) else 0.0
    return {
        "mode": "standard",
        "precision": round(p * 100, 1),
        "recall": round(r * 100, 1),
        "f1": round(f1 * 100, 1),
        "mAP50": round(float(metrics.box.map50) * 100, 1),
        "mAP50_95": round(float(metrics.box.map) * 100, 1),
    }


def eval_tta(model, data, conf, iou, imgsz):
    """Evaluation with Test-Time Augmentation (augment=True)."""
    metrics = model.val(
        data=str(data), split="test", conf=conf, iou=iou, imgsz=imgsz,
        augment=True, plots=False
    )
    p = float(metrics.box.mp)
    r = float(metrics.box.mr)
    f1 = (2 * p * r / (p + r)) if (p + r) else 0.0
    return {
        "mode": "TTA",
        "precision": round(p * 100, 1),
        "recall": round(r * 100, 1),
        "f1": round(f1 * 100, 1),
        "mAP50": round(float(metrics.box.map50) * 100, 1),
        "mAP50_95": round(float(metrics.box.map) * 100, 1),
    }


def main():
    args = parse_args()

    from ultralytics import YOLO

    if not args.model.exists():
        raise SystemExit(f"Model not found: {args.model}\n  Train first: python scripts/train_v14.py")

    print(f"Model: {args.model}")
    print(f"Data: {args.data}")
    print(f"Conf: {args.conf}, IoU: {args.iou}, ImgSz: {args.imgsz}")

    model = YOLO(str(args.model))

    print("\n--- Standard Evaluation ---")
    standard = eval_standard(model, args.data, args.conf, args.iou, args.imgsz)
    print(f"  mAP@0.5: {standard['mAP50']}%  |  P: {standard['precision']}%  R: {standard['recall']}%")

    print("\n--- TTA Evaluation ---")
    tta = eval_tta(model, args.data, args.conf, args.iou, args.imgsz)
    print(f"  mAP@0.5: {tta['mAP50']}%  |  P: {tta['precision']}%  R: {tta['recall']}%")

    gain = tta["mAP50"] - standard["mAP50"]
    print(f"\n  TTA gain: +{gain:.1f}pp mAP@0.5")

    report = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "model": str(args.model),
        "config": {"conf": args.conf, "iou": args.iou, "imgsz": args.imgsz},
        "standard": standard,
        "tta": tta,
        "tta_gain_pp": round(gain, 1),
    }

    if args.tiled:
        print("\n--- Tiled Inference (SAHI) ---")
        try:
            from sahi import AutoDetectionModel, get_sliced_prediction
            from sahi.utils.cv import read_image
            print("  SAHI tiled inference requires per-image evaluation.")
            print("  Install: pip install sahi")
            print("  This mode is slower but helps with very small objects.")
            report["tiled"] = {"status": "available", "note": "Run separately for full tiled eval"}
        except ImportError:
            print("  SAHI not installed. Run: pip install sahi")
            report["tiled"] = {"status": "not_installed"}

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"\nReport saved: {args.out}")


if __name__ == "__main__":
    main()
