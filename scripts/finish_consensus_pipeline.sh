#!/usr/bin/env bash
# Resume after consensus vote — build v21 dataset + review grid.
set -euo pipefail
ROOT="${ROOT:-/workspace/pine}"
cd "$ROOT"
PY="${PYTHON:-/venv/main/bin/python3}"
LOG="$ROOT/runs/consensus/pipeline.log"
log() { echo "[$(date -Iseconds)] $*" | tee -a "$LOG"; }

if [[ ! -d runs/consensus/v21_train_labels ]]; then
  log "ERROR: runs/consensus/v21_train_labels missing — re-run consensus vote first."
  exit 1
fi

log "=== Step 3 (resume): build mealybug_v21 dataset ==="
"$PY" scripts/build_mealybug_v21_dataset.py 2>&1 | tee -a "$LOG"

log "=== Step 4 (resume): review grid HTML ==="
"$PY" scripts/make_review_grid.py \
  --csv runs/consensus/review_queue.csv \
  --images datasets/mealybug_v20/train/images \
  --out runs/consensus/review \
  2>&1 | tee -a "$LOG"

log "=== CONSENSUS PIPELINE DONE ==="
wc -l runs/consensus/review_queue.csv | tee -a "$LOG"
