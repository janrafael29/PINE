#!/usr/bin/env bash
# Re-run Phase 0 eval jobs with the correct venv python (threshold sweep already done).
set -uo pipefail
cd /workspace/pine
PY=/venv/main/bin/python3

echo "=== baseline ==="
"$PY" scripts/capture_v16_baseline.py --skip-label-fix

echo "=== confusion export (1952) ==="
"$PY" scripts/export_confusion_cases.py --max-images 1952 --samples-per-class 8 --conf 0.25

echo "=== CVAT queues @ 640 ==="
"$PY" scripts/build_cvat_audit_queues.py --limit 0 --package 50 --imgsz 640 --batch 4 --chunk 32

echo "=== verify ==="
ls -la runs/audit/cvat_queues/
grep -E "images_with_fn|total_fn" runs/audit/cvat_queues/summary.json || true
echo "=== PHASE0 FIX DONE ==="
