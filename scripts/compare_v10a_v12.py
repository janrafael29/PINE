#!/usr/bin/env python3
"""Fair eval: mealybug_v10a vs mealybug_v12 on the original 17k benchmark test split."""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DATA = ROOT / "mealybug.v10-8th-yolo26n.yolo26" / "data.yaml"
OUT = ROOT / "runs" / "calibration" / "v10a_vs_v12_eval.json"


def default_v10a_weights() -> Path:
    """v10 + field annotations run (mealybug_v10a)."""
    for rel in (
        "runs/retrain/mealybug_v10a/weights/best.pt",
    ):
        p = ROOT / rel
        if p.is_file():
            return p
    return ROOT / "runs/retrain/mealybug_v10a/weights/best.pt"


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Compare v10a vs v12 on val/test.")
    p.add_argument("--data", type=Path, default=DEFAULT_DATA)
    p.add_argument("--v10a", type=Path, default=None, help="v10a weights (default: auto-find)")
    p.add_argument(
        "--v12",
        type=Path,
        default=ROOT / "runs" / "retrain" / "mealybug_v12" / "weights" / "best.pt",
    )
    p.add_argument("--conf", type=float, default=0.12)
    p.add_argument("--iou", type=float, default=0.45)
    p.add_argument("--imgsz", type=int, default=640)
    p.add_argument("--out", type=Path, default=OUT)
    return p.parse_args()


def eval_one(model_path: Path, data: Path, split: str, conf: float, iou: float, imgsz: int) -> dict:
    from ultralytics import YOLO

    if not model_path.is_file():
        raise SystemExit(f"Missing weights: {model_path}")

    metrics = YOLO(str(model_path)).val(
        data=str(data),
        split=split,
        conf=conf,
        iou=iou,
        imgsz=imgsz,
        verbose=False,
    )
    p, r, map50, map5095 = metrics.box.mean()[:4].tolist()
    f1 = 2 * p * r / (p + r) if (p + r) > 0 else 0.0
    return {
        "split": split,
        "conf": conf,
        "iou": iou,
        "precision_pct": round(p * 100, 1),
        "recall_pct": round(r * 100, 1),
        "f1_pct": round(f1 * 100, 1),
        "mAP50_pct": round(map50 * 100, 1),
        "mAP50_95_pct": round(map5095 * 100, 1),
    }


def main() -> None:
    args = parse_args()
    v10a_path = args.v10a or default_v10a_weights()
    if not args.data.is_file():
        raise SystemExit(f"Missing data yaml: {args.data}")

    report = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "data": str(args.data.resolve()),
        "conf": args.conf,
        "iou": args.iou,
        "imgsz": args.imgsz,
        "models": {},
    }

    for key, path in (("mealybug_v10a", v10a_path), ("mealybug_v12", args.v12)):
        print(f"\n=== {key} ===")
        print(f"  weights: {path}")
        entry = {"weights": str(path.resolve()), "splits": {}}
        for split in ("val", "test"):
            s = eval_one(path, args.data, split, args.conf, args.iou, args.imgsz)
            entry["splits"][split] = s
            print(
                f"  {split}: mAP@0.5={s['mAP50_pct']}%  "
                f"P={s['precision_pct']}%  R={s['recall_pct']}%  F1={s['f1_pct']}%"
            )
        report["models"][key] = entry

    v10a_test = report["models"]["mealybug_v10a"]["splits"]["test"]["mAP50_pct"]
    v12_test = report["models"]["mealybug_v12"]["splits"]["test"]["mAP50_pct"]
    delta = round(v10a_test - v12_test, 1)
    winner = "v10a" if delta > 0 else ("v12" if delta < 0 else "tie")
    report["test_mAP50_delta_pp"] = delta
    report["winner_test_mAP50"] = winner

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2), encoding="utf-8")

    print(f"\nTest mAP@0.5: v10a {v10a_test}% vs v12 {v12_test}%  (delta {delta:+.1f} pp)")
    print(f"Winner on test: {winner}")
    print(f"Saved: {args.out}")


if __name__ == "__main__":
    main()
