#!/usr/bin/env python3
"""
Export Ultralytics-style metric curves (PR, F1, P, R vs confidence).

Same plots as YOLO val with plots=True: BoxPR_curve, BoxF1_curve, BoxP_curve, BoxR_curve.

Usage:
  python scripts/export_ultralytics_curves.py
  python scripts/export_ultralytics_curves.py --model runs/retrain/mealybug_v11/weights/best.pt --split test
"""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MODEL = ROOT / "runs" / "retrain" / "mealybug_v11" / "weights" / "best.pt"
DEFAULT_DATA = ROOT / "mealybug.v10-8th-yolo26n.yolo26" / "data.yaml"
OUT_BASE = ROOT / "runs" / "calibration"

CURVE_FILES = (
    "BoxPR_curve.png",
    "BoxF1_curve.png",
    "BoxP_curve.png",
    "BoxR_curve.png",
)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Export YOLO val metric curves (plots=True).")
    p.add_argument("--model", type=Path, default=DEFAULT_MODEL)
    p.add_argument("--data", type=Path, default=DEFAULT_DATA)
    p.add_argument("--split", choices=("val", "test"), default="val")
    p.add_argument("--imgsz", type=int, default=640)
    return p.parse_args()


def main() -> None:
    args = parse_args()
    try:
        from ultralytics import YOLO
    except ImportError:
        raise SystemExit("pip install -U ultralytics")

    if not args.model.is_file():
        raise SystemExit(f"Missing weights: {args.model}")

    out_dir = OUT_BASE / f"mealybug_v11_ultralytics_curves_{args.split}"
    out_dir.mkdir(parents=True, exist_ok=True)

    before = {p.name for p in (ROOT / "runs" / "detect").glob("val*")} if (ROOT / "runs" / "detect").is_dir() else set()

    model = YOLO(str(args.model))
    metrics = model.val(
        data=str(args.data),
        split=args.split,
        imgsz=args.imgsz,
        plots=True,
        verbose=False,
        project=str(ROOT / "runs" / "detect"),
        name=f"curves_{args.split}",
        exist_ok=True,
    )

    detect_root = ROOT / "runs" / "detect"
    run_dir = detect_root / f"curves_{args.split}"
    if not run_dir.is_dir():
        candidates = sorted(detect_root.glob("val*"), key=lambda p: p.stat().st_mtime, reverse=True)
        run_dir = candidates[0] if candidates else None
    if run_dir is None or not run_dir.is_dir():
        raise SystemExit("Could not find val output folder under runs/detect")

    for name in CURVE_FILES:
        src = run_dir / name
        if src.is_file():
            shutil.copy2(src, out_dir / name)

    map50 = float(metrics.box.map50)
    print(f"split={args.split}  mAP@0.5={map50:.3f}")
    print(f"Wrote curves to {out_dir}")
    for name in CURVE_FILES:
        print(f"  - {name}")


if __name__ == "__main__":
    main()
