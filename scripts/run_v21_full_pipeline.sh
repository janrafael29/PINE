#!/usr/bin/env bash
# Strict consensus -> v21 from v16 (primary) -> v21m from v20m (backup).
set -euo pipefail

ROOT="${ROOT:-/workspace/pine}"
cd "$ROOT"
LOG="$ROOT/runs/v21_pipeline/full.log"
mkdir -p runs/v21_pipeline

log() { echo "[$(date -Iseconds)] $*" | tee -a "$LOG"; }

log "========== V21 FULL PIPELINE START =========="

bash scripts/run_consensus_strict.sh 2>&1 | tee -a "$LOG"

log "=== Primary: v21 from v16 weights ==="
START_MODEL=mealybug_v16_selffix RUN_NAME=mealybug_v21 LR0=0.00025 \
  EVAL_SUBDIR=v21_from_v16 bash scripts/train_v21_vast.sh 2>&1 | tee -a "$LOG"

log "=== Backup: v21m from v20m weights ==="
START_MODEL=mealybug_v20m RUN_NAME=mealybug_v21m LR0=0.0003 \
  EVAL_SUBDIR=v21m_from_v20m bash scripts/train_v21_vast.sh 2>&1 | tee -a "$LOG"

log "========== V21 FULL PIPELINE DONE =========="
log "Compare: docs/thesis/assets/v18_baseline/v21_from_v16/ vs v21m_from_v20m/"
