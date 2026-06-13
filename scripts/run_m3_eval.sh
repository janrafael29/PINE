#!/usr/bin/env bash
# M3 eval: v20m on corrected test (locked protocol).
set -euo pipefail

ROOT="${ROOT:-/workspace/pine}"
cd "$ROOT"
PYTHON="${PYTHON:-/venv/main/bin/python3}"
LOG_DIR="${ROOT}/runs/v18_pipeline"
mkdir -p "$LOG_DIR"

source "$ROOT/scripts/resolve_weights.sh"

V20M_WEIGHTS="$(resolve_weights mealybug_v20m)"
echo "[$(date -Iseconds)] M3 eval using $V20M_WEIGHTS" | tee -a "$LOG_DIR/m3_eval.log"

"$PYTHON" scripts/capture_v16_baseline.py --skip-label-fix \
  --model "$V20M_WEIGHTS" \
  --out-subdir v20m_m3 \
  2>&1 | tee -a "$LOG_DIR/m3_eval.log"

echo "[$(date -Iseconds)] M3 eval DONE" | tee -a "$LOG_DIR/m3_eval.log"
