#!/usr/bin/env bash
# Cache domain YOLOs, 6-model consensus, build v21 dataset + review grid.
set -euo pipefail

ROOT="${ROOT:-/workspace/pine}"
cd "$ROOT"
PY="${PYTHON:-/venv/main/bin/python3}"
LOG="$ROOT/runs/consensus/pipeline.log"
mkdir -p runs/consensus

log() { echo "[$(date -Iseconds)] $*" | tee -a "$LOG"; }

source "$ROOT/scripts/resolve_weights.sh"

IMAGES="datasets/mealybug_v20/train/images"
CONSENSUS="runs/consensus"

log "=== Step 1: cache domain YOLO predictions ==="

V16="$(resolve_weights mealybug_v16_selffix)"
V20S="$(resolve_weights mealybug_v20s)"
V20M="$(resolve_weights mealybug_v20m)"

for spec in "v16:$V16" "v20s:$V20S" "v20m:$V20M"; do
  name="${spec%%:*}"
  model="${spec#*:}"
  out="$CONSENSUS/${name}_train.jsonl"
  log "Caching $name -> $out"
  "$PY" scripts/cache_detections.py --backend yolo \
    --model "$model" \
    --images "$IMAGES" \
    --out "$out" \
    --conf 0.05 --imgsz 1280 --batch 8 --chunk 32 \
    2>&1 | tee -a "$LOG"
done

log "=== Step 2: 6-model consensus vote ==="
mkdir -p runs/consensus/v21_train_labels

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
  --add-conf 0.45 \
  --out-labels runs/consensus/v21_train_labels \
  --report runs/consensus/consensus_report.json \
  --review-csv runs/consensus/review_queue.csv \
  2>&1 | tee -a "$LOG"

log "=== Step 3: build mealybug_v21 dataset ==="
"$PY" scripts/build_mealybug_v21_dataset.py 2>&1 | tee -a "$LOG"

log "=== Step 4: review grid HTML ==="
"$PY" scripts/make_review_grid.py \
  --csv runs/consensus/review_queue.csv \
  --images "$IMAGES" \
  --out runs/consensus/review \
  2>&1 | tee -a "$LOG"

log "=== CONSENSUS PIPELINE DONE ==="
log "Next: download runs/consensus/review/ -> open review.html in browser"
log "After review: upload decisions.json, run apply_review_decisions.py, then train_v21_vast.sh"
wc -l runs/consensus/review_queue.csv | tee -a "$LOG"
