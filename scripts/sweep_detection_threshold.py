#!/usr/bin/env python3
"""
Calibrate detection thresholds using Ultralytics val on the held-out split.

Usage:
  python scripts/sweep_detection_threshold.py
  python scripts/sweep_detection_threshold.py --quick
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MODEL = ROOT / "runs" / "retrain" / "mealybug_v11" / "weights" / "best.pt"
DEFAULT_DATA = ROOT / "mealybug.v10-8th-yolo26n.yolo26" / "data.yaml"
OUT_DIR = ROOT / "runs" / "calibration"


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument("--model", type=Path, default=DEFAULT_MODEL)
    p.add_argument("--data", type=Path, default=DEFAULT_DATA)
    p.add_argument("--quick", action="store_true", help="Fewer conf steps")
    p.add_argument(
        "--deploy-focus",
        action="store_true",
        help="Dense grid 0.15–0.40 (deploy / two-tier tuning)",
    )
    p.add_argument(
        "--out",
        type=Path,
        default=OUT_DIR / "threshold_sweep.json",
        help="Output JSON path",
    )
    p.add_argument("--imgsz", type=int, default=640)
    return p.parse_args()


def main() -> None:
    args = parse_args()
    try:
        from ultralytics import YOLO
    except ImportError:
        raise SystemExit("pip install -U ultralytics")

    if not args.data.is_file():
        raise SystemExit(f"Missing data yaml: {args.data}")

    model = YOLO(str(args.model))
    conf_grid = (
        [round(0.15 + i * 0.01, 2) for i in range(26)]
        if args.deploy_focus
        else (
            [round(0.05 + i * 0.01, 2) for i in range(41)]
            if not args.quick
            else [0.08, 0.10, 0.12, 0.14, 0.16, 0.18, 0.20, 0.22, 0.25, 0.28, 0.30, 0.35, 0.40]
        )
    )

    rows = []
    print(f"Val sweep on {args.data} ({len(conf_grid)} confidence values)...")
    for conf in conf_grid:
        metrics = model.val(
            data=str(args.data),
            split="val",
            conf=conf,
            iou=0.45,
            imgsz=args.imgsz,
            plots=False,
            verbose=False,
        )
        p = float(metrics.box.mp)
        r = float(metrics.box.mr)
        f1 = (2 * p * r / (p + r)) if (p + r) else 0.0
        rows.append({"conf": conf, "precision": p, "recall": r, "f1": f1})
        print(f"  conf={conf:.2f}  P={p:.3f}  R={r:.3f}  F1={f1:.3f}")

    best_f1 = max(rows, key=lambda x: x["f1"])
    pr55 = [x for x in rows if x["precision"] >= 0.55]
    best_recall_pr55 = max(pr55, key=lambda x: x["recall"]) if pr55 else best_f1
    rp50 = [x for x in rows if x["recall"] >= 0.50]
    best_prec_rp50 = max(rp50, key=lambda x: x["precision"]) if rp50 else best_f1

    # Two-tier: possible = F1-optimal or slightly lower; confirmed = best precision with recall >= 45%
    rp45 = [x for x in rows if x["recall"] >= 0.45]
    confirmed_row = max(rp45, key=lambda x: x["precision"]) if rp45 else best_prec_rp50
    possible_conf = best_f1["conf"]
    confirmed_conf = max(confirmed_row["conf"], possible_conf + 0.03)

    def row_at(conf: float) -> dict | None:
        for x in rows:
            if abs(x["conf"] - conf) < 1e-6:
                return x
        return None

    deploy_rows = {0.22: row_at(0.22), 0.28: row_at(0.28)}

    recommendation = {
        "method": "ultralytics_val_split",
        "data": str(args.data),
        "model": str(args.model),
        "balanced": {
            "detection_threshold": best_f1["conf"],
            "nms_threshold": 0.45,
            "metrics": {k: best_f1[k] for k in ("precision", "recall", "f1")},
        },
        "accuracy_mode": {
            "detection_threshold": best_recall_pr55["conf"],
            "nms_threshold": 0.50,
            "metrics": {k: best_recall_pr55[k] for k in ("precision", "recall", "f1")},
        },
        "two_tier": {
            "possible_threshold": possible_conf,
            "confirmed_threshold": round(confirmed_conf, 2),
            "possible_metrics": {k: best_f1[k] for k in ("precision", "recall", "f1")},
            "confirmed_metrics": {k: confirmed_row[k] for k in ("precision", "recall", "f1")},
        },
        "roboflow_note": "Roboflow UI optimal ~0.12 is similar to val F1-optimal when metrics are computed at low conf.",
        "deploy_current": {
            "possible_0.22": deploy_rows[0.22],
            "confirmed_0.28": deploy_rows[0.28],
        },
    }

    args.out.parent.mkdir(parents=True, exist_ok=True)
    out = args.out
    out.write_text(json.dumps({"recommendation": recommendation, "rows": rows}, indent=2), encoding="utf-8")
    print("\n=== Recommendation ===")
    print(json.dumps(recommendation, indent=2))
    print(f"\nWrote {out}")


if __name__ == "__main__":
    main()
