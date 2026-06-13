#!/usr/bin/env python3
"""Run v16 val on corrected test set and export Ultralytics plots (73.3% headline).

Usage:
  python scripts/eval_v16_corrected_test_plots.py
  python scripts/eval_v16_corrected_test_plots.py --skip-label-fix
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODEL = ROOT / "runs/retrain/mealybug_v16_selffix/weights/best.pt"
DATASET = ROOT / "datasets/mealybug_v13afix"
LABELS = DATASET / "test/labels"
LABELS_CORRECTED = DATASET / "test/labels_v16_corrected"
LABELS_BACKUP = DATASET / "test/labels_pre_eval_backup"
DATA_YAML = ROOT / "runs/calibration/data_v16_corrected_test.yaml"
PANEL_OUT = ROOT / "docs/thesis/assets/v16_selffix"
VAL_NAME = "v16_corrected_test"

PLOT_FILES = (
    "BoxPR_curve.png",
    "BoxF1_curve.png",
    "BoxP_curve.png",
    "BoxR_curve.png",
    "confusion_matrix.png",
    "confusion_matrix_normalized.png",
    "results.png",
)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="v16 corrected-test val + plots")
    p.add_argument("--skip-label-fix", action="store_true")
    p.add_argument("--imgsz", type=int, default=1280)
    p.add_argument("--conf", type=float, default=0.001)
    p.add_argument("--iou", type=float, default=0.6)
    return p.parse_args()


def write_data_yaml() -> None:
    DATA_YAML.parent.mkdir(parents=True, exist_ok=True)
    path = DATASET.as_posix()
    DATA_YAML.write_text(
        f"path: {path}\ntrain: train/images\nval: test/images\ntest: test/images\n\n"
        "nc: 1\nnames:\n  0: mealybug\n",
        encoding="utf-8",
    )


def ensure_corrected_labels(skip_fix: bool) -> bool:
    if not skip_fix and not LABELS_CORRECTED.is_dir():
        print("Running fix_test_labels.py --apply ...")
        subprocess.run(
            [sys.executable, str(ROOT / "scripts/fix_test_labels.py"), "--apply"],
            check=True,
            cwd=ROOT,
        )
    return LABELS_CORRECTED.is_dir()


def swap_labels(use_corrected: bool) -> None:
    if not use_corrected:
        return
    if LABELS.is_dir() and not LABELS_BACKUP.is_dir():
        shutil.copytree(LABELS, LABELS_BACKUP)
    if LABELS.is_dir():
        shutil.rmtree(LABELS)
    shutil.copytree(LABELS_CORRECTED, LABELS)


def restore_labels() -> None:
    if not LABELS_BACKUP.is_dir():
        return
    if LABELS.is_dir():
        shutil.rmtree(LABELS)
    shutil.move(str(LABELS_BACKUP), str(LABELS))


def main() -> None:
    args = parse_args()
    if not MODEL.is_file():
        raise SystemExit(
            f"Missing weights: {MODEL}\n"
            "Download from Vast:\n"
            "  scp -P <PORT> root@<HOST>:/workspace/runs/train/mealybug_v16_selffix/weights/best.pt "
            f" {MODEL}"
        )
    if not (DATASET / "test/images").is_dir():
        raise SystemExit(f"Missing test images: {DATASET / 'test/images'}")

    use_corrected = ensure_corrected_labels(args.skip_label_fix)
    write_data_yaml()
    swap_labels(use_corrected)
    try:
        from ultralytics import YOLO

        model = YOLO(str(MODEL))
        metrics = model.val(
            data=str(DATA_YAML),
            split="test",
            imgsz=args.imgsz,
            conf=args.conf,
            iou=args.iou,
            plots=True,
            verbose=True,
            project=str(ROOT / "runs/detect"),
            name=VAL_NAME,
            exist_ok=True,
        )
    finally:
        restore_labels()

    run_dir = ROOT / "runs/detect" / VAL_NAME
    PANEL_OUT.mkdir(parents=True, exist_ok=True)
    for name in PLOT_FILES:
        src = run_dir / name
        if src.is_file():
            shutil.copy2(src, PANEL_OUT / f"v16_test_{name}")

    map50 = float(metrics.box.map50) * 100
    print(f"\n=== Test metrics (expect ~73.3% mAP@0.5 on corrected labels) ===")
    print(f"  mAP@0.5:      {map50:.2f}%")
    print(f"  Precision:    {float(metrics.box.mp) * 100:.2f}%")
    print(f"  Recall:       {float(metrics.box.mr) * 100:.2f}%")
    print(f"  mAP@0.5:0.95: {float(metrics.box.map) * 100:.2f}%")
    print(f"\nPlots copied to: {PANEL_OUT}")
    for name in PLOT_FILES:
        p = PANEL_OUT / f"v16_test_{name}"
        if p.is_file():
            print(f"  - {p.name}")


if __name__ == "__main__":
    main()
