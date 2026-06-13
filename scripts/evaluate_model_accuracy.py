#!/usr/bin/env python3
"""
Report model accuracy (precision, recall, mAP) on val and test splits.

Usage:
  python scripts/evaluate_model_accuracy.py
  python scripts/evaluate_model_accuracy.py --model runs/retrain/mealybug_fix500/weights/best.pt
  python scripts/evaluate_model_accuracy.py --data datasets/data.yaml --splits val test
"""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DATA = ROOT / "datasets" / "data.yaml"
DEFAULT_MODELS = [
    ROOT / "runs" / "retrain" / "mealybug_v2" / "weights" / "best.pt",
    ROOT / "runs" / "retrain" / "mealybug_fix500" / "weights" / "best.pt",
]
OUT_DIR = ROOT / "runs" / "calibration"


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument(
        "--model",
        type=Path,
        action="append",
        default=None,
        help="Weights path (repeatable). Default: v2 + fix500 if present.",
    )
    p.add_argument("--data", type=Path, default=DEFAULT_DATA)
    p.add_argument(
        "--splits",
        nargs="+",
        default=["val", "test"],
        choices=["val", "test"],
    )
    p.add_argument("--conf", type=float, default=0.12, help="Score threshold for val")
    p.add_argument("--iou", type=float, default=0.45)
    p.add_argument("--imgsz", type=int, default=640)
    p.add_argument(
        "--out",
        type=Path,
        default=OUT_DIR / "accuracy_report.json",
    )
    return p.parse_args()


def run_val(model_path: Path, data: Path, split: str, conf: float, iou: float, imgsz: int) -> dict:
    from ultralytics import YOLO

    model = YOLO(str(model_path))
    metrics = model.val(
        data=str(data),
        split=split,
        conf=conf,
        iou=iou,
        imgsz=imgsz,
        plots=False,
        verbose=False,
    )
    p = float(metrics.box.mp)
    r = float(metrics.box.mr)
    map50 = float(metrics.box.map50)
    map5095 = float(metrics.box.map)
    f1 = (2 * p * r / (p + r)) if (p + r) else 0.0
    return {
        "split": split,
        "conf": conf,
        "iou": iou,
        "precision": round(p, 4),
        "recall": round(r, 4),
        "f1": round(f1, 4),
        "mAP50": round(map50, 4),
        "mAP50_95": round(map5095, 4),
        "precision_pct": round(p * 100, 1),
        "recall_pct": round(r * 100, 1),
        "mAP50_pct": round(map50 * 100, 1),
        "mAP50_95_pct": round(map5095 * 100, 1),
    }


def main() -> None:
    args = parse_args()
    if not args.data.is_file():
        raise SystemExit(f"Missing data yaml: {args.data}")

    models = args.model or [m for m in DEFAULT_MODELS if m.is_file()]
    if not models:
        raise SystemExit("No model weights found. Pass --model path/to/best.pt")

    report: dict = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "data": str(args.data.resolve()),
        "conf": args.conf,
        "iou": args.iou,
        "imgsz": args.imgsz,
        "models": {},
    }

    for model_path in models:
        name = model_path.parent.parent.name
        print(f"\n=== {name} ({model_path.name}) ===")
        entry: dict = {"weights": str(model_path.resolve()), "splits": {}}
        for split in args.splits:
            print(f"  Evaluating split={split} conf={args.conf} ...")
            try:
                row = run_val(model_path, args.data, split, args.conf, args.iou, args.imgsz)
                entry["splits"][split] = row
                print(
                    f"    P={row['precision_pct']}%  R={row['recall_pct']}%  "
                    f"mAP@0.5={row['mAP50_pct']}%  mAP@0.5:0.95={row['mAP50_95_pct']}%"
                )
            except Exception as e:
                entry["splits"][split] = {"error": str(e)}
                print(f"    ERROR: {e}")
        report["models"][name] = entry

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"\nWrote {args.out}")


if __name__ == "__main__":
    main()
