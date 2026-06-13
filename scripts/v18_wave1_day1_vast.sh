#!/usr/bin/env bash
# V18 Wave 1 — Day 1 GPU jobs (run on Vast)
set -euo pipefail
cd /workspace/pine
PYTHON="${PYTHON:-/venv/main/bin/python3}"

echo "=== Phase 0: baseline lock ==="
"$PYTHON" scripts/capture_v16_baseline.py --skip-label-fix

echo "=== Phase 0: full confusion export ==="
"$PYTHON" scripts/export_confusion_cases.py --max-images 1952 --samples-per-class 8 --conf 0.25

echo "=== Day 1: CVAT audit queues (full test) ==="
"$PYTHON" scripts/build_cvat_audit_queues.py --limit 0 --package 50 --imgsz 640 --batch 4 --chunk 32

echo "=== Day 4: threshold sweep v16 @ 1280 ==="
"$PYTHON" scripts/sweep_detection_threshold.py \
  --model runs/retrain/mealybug_v16_selffix/weights/best.pt \
  --data runs/calibration/data_v16_corrected_test.yaml \
  --deploy-focus --imgsz 1280 \
  --out runs/calibration/threshold_sweep_v16_1280.json

echo "=== Done. Download to PC: ==="
echo "  docs/thesis/assets/v18_baseline/"
echo "  docs/thesis/assets/confusion_cases_v16/"
echo "  runs/audit/cvat_queues/"
echo "  datasets/cvat_import/Q1_false_negatives_top50/"
echo "  datasets/cvat_import/Q2_poor_localization_top50/"
echo "  datasets/cvat_import/Q3_false_positives_top50/"
