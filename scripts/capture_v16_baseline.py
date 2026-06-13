#!/usr/bin/env python3
"""Capture v16 corrected-test baseline metrics for V18 Phase 0.

Writes JSON (+ optional Ultralytics plots) to docs/thesis/assets/v18_baseline/.

Usage:
  python scripts/capture_v16_baseline.py
  python scripts/capture_v16_baseline.py --skip-label-fix
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from label_eval_utils import ensure_corrected_eval_staging, run_fix_test_labels_if_missing

MODEL = ROOT / "runs/retrain/mealybug_v16_selffix/weights/best.pt"
ARCHIVE = ROOT / "runs/retrain/mealybug_v16_selffix/weights/best_v16_baseline_archive.pt"
OUT_DIR = ROOT / "docs/thesis/assets/v18_baseline"

PLOT_FILES = (
    "BoxPR_curve.png",
    "BoxF1_curve.png",
    "BoxP_curve.png",
    "BoxR_curve.png",
    "confusion_matrix.png",
    "confusion_matrix_normalized.png",
)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Phase 0: lock v16 baseline metrics")
    p.add_argument("--model", type=Path, default=MODEL)
    p.add_argument("--skip-label-fix", action="store_true")
    p.add_argument("--skip-archive", action="store_true", help="Do not copy weights to archive")
    p.add_argument("--out-subdir", type=str, default="", help="Subfolder under v18_baseline/ for JSON")
    p.add_argument("--imgsz", type=int, default=1280)
    p.add_argument("--conf", type=float, default=0.001)
    p.add_argument("--iou", type=float, default=0.6)
    p.add_argument("--no-plots", action="store_true")
    return p.parse_args()


def archive_weights(weights: Path, archive: Path, skip: bool) -> None:
    if skip:
        return
    if not weights.is_file():
        raise SystemExit(f"Missing model: {weights}")
    archive.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(weights, archive)
    print(f"Archived weights -> {archive}")


def ensure_corrected_labels(skip_fix: bool) -> bool:
    corrected = ROOT / "datasets/mealybug_v13afix/test/labels_v16_corrected"
    if corrected.is_dir() and any(corrected.glob("*.txt")):
        return True
    if skip_fix:
        return False
    return run_fix_test_labels_if_missing()


def main() -> int:
    args = parse_args()
    weights = args.model.resolve()
    if not weights.is_file():
        raise SystemExit(f"Missing weights: {weights}")

    archive_weights(weights, ARCHIVE, args.skip_archive)
    if not ensure_corrected_labels(args.skip_label_fix):
        raise SystemExit("Corrected test labels missing. Run: python scripts/fix_test_labels.py --apply")

    data_yaml = ensure_corrected_eval_staging()
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    val_name = "v16_baseline_capture"

    from ultralytics import YOLO

    model = YOLO(str(weights))
    metrics = model.val(
        data=str(data_yaml),
        split="test",
        imgsz=args.imgsz,
        conf=args.conf,
        iou=args.iou,
        plots=not args.no_plots,
        verbose=True,
        project=str(ROOT / "runs/detect"),
        name=val_name,
        exist_ok=True,
    )

    p = float(metrics.box.mp)
    r = float(metrics.box.mr)
    map50 = float(metrics.box.map50)
    map5095 = float(metrics.box.map)
    f1 = (2 * p * r / (p + r)) if (p + r) else 0.0

    payload = {
        "captured_at": datetime.now(timezone.utc).isoformat(),
        "phase": "V18 Phase 0 baseline lock",
        "model": str(weights.relative_to(ROOT.resolve())),
        "archive": str(ARCHIVE.relative_to(ROOT)) if ARCHIVE.is_file() else None,
        "ground_truth": "labels_v16_corrected (eval staging junction)",
        "data_yaml": str(data_yaml.relative_to(ROOT)),
        "protocol": {
            "split": "test",
            "images": 1952,
            "conf": args.conf,
            "iou": args.iou,
            "imgsz": args.imgsz,
        },
        "metrics": {
            "mAP50": round(map50, 4),
            "mAP50_pct": round(map50 * 100, 2),
            "mAP50_95": round(map5095, 4),
            "mAP50_95_pct": round(map5095 * 100, 2),
            "precision": round(p, 4),
            "precision_pct": round(p * 100, 2),
            "recall": round(r, 4),
            "recall_pct": round(r * 100, 2),
            "f1": round(f1, 4),
            "f1_pct": round(f1 * 100, 2),
        },
        "expected_headline": {
            "mAP50_pct": 73.3,
            "precision_pct": 80.6,
            "recall_pct": 64.7,
            "mAP50_95_pct": 40.7,
        },
    }

    out_dir = OUT_DIR / args.out_subdir if args.out_subdir else OUT_DIR
    out_dir.mkdir(parents=True, exist_ok=True)
    json_name = (
        "v16_corrected_test_metrics.json"
        if not args.out_subdir
        else f"{args.out_subdir}_corrected_test_metrics.json"
    )
    json_path = out_dir / json_name
    json_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(f"\nWrote {json_path}")

    run_dir = ROOT / "runs/detect" / val_name
    if not args.no_plots:
        for name in PLOT_FILES:
            src = run_dir / name
            if src.is_file():
                shutil.copy2(src, OUT_DIR / name)

    delta = payload["metrics"]["mAP50_pct"] - payload["expected_headline"]["mAP50_pct"]
    print(f"mAP@0.5: {payload['metrics']['mAP50_pct']}% (delta vs 73.3% headline: {delta:+.2f} pp)")
    if abs(delta) > 0.5:
        print("WARNING: baseline differs from headline by > 0.5 pp — check labels/protocol.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
