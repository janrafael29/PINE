#!/usr/bin/env python3
"""Eval mealybug_va (field-only) on field test split and 17k benchmark test."""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIELD_DATA = ROOT / "datasets" / "mealybug_va_field" / "data.yaml"
BENCH_DATA = ROOT / "mealybug.v10-8th-yolo26n.yolo26" / "data.yaml"
OUT = ROOT / "runs" / "calibration" / "mealybug_va_field_eval.json"


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument(
        "--model",
        type=Path,
        default=ROOT / "runs" / "retrain" / "mealybug_va" / "weights" / "best.pt",
    )
    p.add_argument("--conf", type=float, default=0.12)
    p.add_argument("--iou", type=float, default=0.45)
    p.add_argument("--imgsz", type=int, default=640)
    p.add_argument("--out", type=Path, default=OUT)
    return p.parse_args()


def eval_split(model_path: Path, data: Path, split: str, conf: float, iou: float, imgsz: int) -> dict:
    from ultralytics import YOLO

    m = YOLO(str(model_path))
    metrics = m.val(data=str(data), split=split, conf=conf, iou=iou, imgsz=imgsz, verbose=False)
    p, r, map50, map5095 = metrics.box.mean()[:4].tolist()
    f1 = 2 * p * r / (p + r) if (p + r) > 0 else 0.0
    return {
        "split": split,
        "precision_pct": round(p * 100, 1),
        "recall_pct": round(r * 100, 1),
        "f1_pct": round(f1 * 100, 1),
        "mAP50_pct": round(map50 * 100, 1),
        "mAP50_95_pct": round(map5095 * 100, 1),
    }


def main() -> None:
    args = parse_args()
    if not args.model.is_file():
        raise SystemExit(f"Missing weights: {args.model}")

    report = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "weights": str(args.model.resolve()),
        "conf": args.conf,
        "iou": args.iou,
        "imgsz": args.imgsz,
        "evals": {},
    }

    for label, data, split in (
        ("field_test", FIELD_DATA, "test"),
        ("benchmark_test", BENCH_DATA, "test"),
        ("benchmark_val", BENCH_DATA, "val"),
    ):
        if not data.is_file():
            print(f"skip {label}: missing {data}")
            continue
        print(f"\n=== {label} ({split}) ===")
        s = eval_split(args.model, data, split, args.conf, args.iou, args.imgsz)
        report["evals"][label] = {"data": str(data), **s}
        print(f"  mAP@0.5={s['mAP50_pct']}%  P={s['precision_pct']}%  R={s['recall_pct']}%  F1={s['f1_pct']}%")

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"\nSaved: {args.out}")


if __name__ == "__main__":
    main()
