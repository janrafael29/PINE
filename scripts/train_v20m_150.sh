#!/usr/bin/env bash
# Train v20m @ 150 epochs (early stop patience=30). Run after v20s completes.
set -euo pipefail

ROOT="${ROOT:-/workspace/pine}"
cd "$ROOT"
PYTHON="${PYTHON:-/venv/main/bin/python3}"
YOLO_BIN="${YOLO_BIN:-/venv/main/bin/yolo}"
DATA_V20="${ROOT}/datasets/mealybug_v20/data.yaml"
LOG_DIR="${ROOT}/runs/v18_pipeline"
mkdir -p "$LOG_DIR"

log() { echo "[$(date -Iseconds)] $*" | tee -a "$LOG_DIR/pipeline.log"; }

source "$ROOT/scripts/resolve_weights.sh"

log "=== Wave 3b: train v20m (YOLO26m @ 1280, 150 epochs max) ==="
"$YOLO_BIN" detect train \
  model=yolo26m.pt \
  data="$DATA_V20" \
  epochs=150 imgsz=1280 batch="${BATCH_M:-0.8}" workers=12 \
  optimizer=AdamW lr0=0.001 lrf=0.01 cos_lr=True \
  warmup_epochs=3 patience=30 close_mosaic=10 \
  iou=0.45 box=7.5 dropout=0.1 \
  hsv_h=0.015 hsv_s=0.5 hsv_v=0.4 degrees=10 translate=0.1 scale=0.5 fliplr=0.5 \
  mosaic=1.0 copy_paste=0 \
  project=runs/retrain name=mealybug_v20m \
  2>&1 | tee -a "$LOG_DIR/wave3_v20m.log"

log "=== M3 eval: v20m on corrected test ==="
V20M_WEIGHTS="$(resolve_weights mealybug_v20m)"
log "Using weights: $V20M_WEIGHTS"
"$PYTHON" scripts/capture_v16_baseline.py --skip-label-fix \
  --model "$V20M_WEIGHTS" \
  --out-subdir v20m_m3 \
  2>&1 | tee -a "$LOG_DIR/m3_eval.log"

log "=== v20m @ 150 DONE ==="
