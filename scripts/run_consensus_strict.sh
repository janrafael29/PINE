#!/usr/bin/env bash
# Rebuild consensus labels with stricter rules (caches must already exist).
set -euo pipefail

ROOT="${ROOT:-/workspace/pine}"
cd "$ROOT"
PY="${PYTHON:-/venv/main/bin/python3}"
LOG="$ROOT/runs/consensus/strict.log"
mkdir -p runs/consensus

log() { echo "[$(date -Iseconds)] $*" | tee -a "$LOG"; }

log "=== Strict 6-model consensus (add_conf=0.50, min_voters=3, apply-remove) ==="
"$PY" scripts/build_consensus_labels.py \
  --labels datasets/mealybug_v20/train/labels \
  --caches \
    runs/consensus/v16_train.jsonl \
    runs/consensus/v20s_train.jsonl \
    runs/consensus/v20m_train.jsonl \
    runs/consensus/gdino_train.jsonl \
    runs/consensus/owlv2_train.jsonl \
    runs/consensus/yoloworld_train.jsonl \
  --yolo-indices 0 1 2 \
  --min-voters 3 \
  --add-conf 0.50 \
  --apply-remove \
  --out-labels runs/consensus/v21_train_labels \
  --report runs/consensus/consensus_report_strict.json \
  --review-csv runs/consensus/review_queue_strict.csv \
  2>&1 | tee -a "$LOG"

if [[ -f runs/consensus/review/decisions.json ]]; then
  log "=== Applying human review decisions ==="
  "$PY" scripts/apply_review_decisions.py \
    --decisions runs/consensus/review/decisions.json \
    --labels runs/consensus/v21_train_labels \
    --images datasets/mealybug_v20/train/images \
    2>&1 | tee -a "$LOG"
else
  log "No decisions.json — skipping review apply (all auto-consensus labels kept)."
fi

log "=== Build mealybug_v21 dataset ==="
"$PY" scripts/build_mealybug_v21_dataset.py 2>&1 | tee -a "$LOG"

log "=== Strict consensus DONE ==="
