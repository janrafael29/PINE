#!/usr/bin/env bash
# v16 selffix round 2 → mealybug_v22 → train → corrected-test eval.
set -euo pipefail

ROOT="${ROOT:-/workspace/pine}"
cd "$ROOT"
PY="${PYTHON:-/venv/main/bin/python3}"
LOG="$ROOT/runs/v22_pipeline/full.log"
mkdir -p runs/v22_pipeline

log() { echo "[$(date -Iseconds)] $*" | tee -a "$LOG"; }

log "========== V22 SELFFIX PIPELINE START =========="

log "=== Step 1: Build mealybug_v22 (v16 @ add_conf=0.45, train add-only) ==="
"$PY" scripts/prepare_mealybug_v22_selffix.py --apply 2>&1 | tee -a "$LOG"

log "=== Step 2: Train + eval mealybug_v22 from v16 ==="
bash scripts/train_v22_vast.sh 2>&1 | tee -a "$LOG"

log "========== V22 SELFFIX PIPELINE DONE =========="
log "Results: docs/thesis/assets/v18_baseline/v22_from_v16_selffix/"
