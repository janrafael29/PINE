#!/usr/bin/env bash
# Train v21 on consensus labels — fine-tune from v16 (default) or v20m.
set -euo pipefail

ROOT="${ROOT:-/workspace/pine}"
cd "$ROOT"
PYTHON="${PYTHON:-/venv/main/bin/python3}"
YOLO_BIN="${YOLO_BIN:-/venv/main/bin/yolo}"
DATA_V21="${ROOT}/datasets/mealybug_v21/data.yaml"
LOG_DIR="${ROOT}/runs/v21_pipeline"
mkdir -p "$LOG_DIR"

source "$ROOT/scripts/resolve_weights.sh"

# Defaults: primary run from v16 (best corrected-test baseline)
START_MODEL="${START_MODEL:-mealybug_v16_selffix}"
RUN_NAME="${RUN_NAME:-mealybug_v21}"
LR0="${LR0:-0.00025}"
EPOCHS="${EPOCHS:-100}"
PATIENCE="${PATIENCE:-25}"
EVAL_SUBDIR="${EVAL_SUBDIR:-v21_final}"

START_WEIGHTS="$(resolve_weights "$START_MODEL")"

log() { echo "[$(date -Iseconds)] $*" | tee -a "$LOG_DIR/train.log"; }

if [[ ! -f "$DATA_V21" ]]; then
  log "ERROR: $DATA_V21 missing. Run run_consensus_strict.sh first."
  exit 1
fi
if [[ ! -f "$START_WEIGHTS" ]]; then
  log "ERROR: $START_WEIGHTS missing."
  exit 1
fi

log "=== Train $RUN_NAME from $START_MODEL (lr0=$LR0, epochs=$EPOCHS, patience=$PATIENCE) ==="
"$YOLO_BIN" detect train \
  model="$START_WEIGHTS" \
  data="$DATA_V21" \
  epochs="$EPOCHS" imgsz=1280 batch="${BATCH_V21:-0.8}" workers=12 \
  optimizer=AdamW lr0="$LR0" lrf=0.01 cos_lr=True \
  warmup_epochs=3 patience="$PATIENCE" close_mosaic=15 \
  iou=0.45 box=7.5 dropout=0.1 \
  hsv_h=0.015 hsv_s=0.5 hsv_v=0.4 degrees=10 translate=0.1 scale=0.5 fliplr=0.5 \
  mosaic=1.0 copy_paste=0 \
  project=runs/retrain name="$RUN_NAME" \
  2>&1 | tee -a "$LOG_DIR/${RUN_NAME}.log"

log "=== Eval $RUN_NAME on corrected test ==="
"$PYTHON" scripts/capture_v16_baseline.py --skip-label-fix \
  --model "$(resolve_weights "$RUN_NAME")" \
  --out-subdir "$EVAL_SUBDIR" \
  2>&1 | tee -a "$LOG_DIR/${RUN_NAME}_eval.log"

log "=== $RUN_NAME DONE ==="
