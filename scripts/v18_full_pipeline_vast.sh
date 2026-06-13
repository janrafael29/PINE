#!/usr/bin/env bash
# V18 full pipeline: Phase 0 + Wave 1 auto-audit + Wave 2 dataset + Wave 3 v20s/v20m train
set -euo pipefail

ROOT="${ROOT:-/workspace/pine}"
cd "$ROOT"
PYTHON="${PYTHON:-/venv/main/bin/python3}"

MODEL="${MODEL:-runs/retrain/mealybug_v16_selffix/weights/best.pt}"
DATA_V20="${ROOT}/datasets/mealybug_v20/data.yaml"
LOG_DIR="${ROOT}/runs/v18_pipeline"
mkdir -p "$LOG_DIR"

log() { echo "[$(date -Iseconds)] $*" | tee -a "$LOG_DIR/pipeline.log"; }

require_train_data() {
  if [[ ! -d datasets/mealybug_v13afix/train/images ]]; then
    log "ERROR: datasets/mealybug_v13afix/train missing."
    log "Upload pine train bundle to /workspace and unzip into pine/datasets/"
    exit 1
  fi
}

YOLO_BIN="${YOLO_BIN:-/venv/main/bin/yolo}"

if [[ "${SKIP_PHASE0:-0}" == "1" ]]; then
  log "=== Phase 0 skipped (SKIP_PHASE0=1) ==="
else
  log "=== Phase 0: baseline + queues + confusion + threshold sweep ==="
  bash scripts/v18_wave1_day1_vast.sh 2>&1 | tee -a "$LOG_DIR/phase0.log"
fi

require_train_data

log "=== Wave 1: audit reports + auto-fix -> mealybug_v20_audit ==="
if [[ "${SKIP_AUDIT:-0}" != "1" ]]; then
  "$PYTHON" scripts/audit_annotations.py \
    --model "$MODEL" \
    --out runs/audit/train_audit_report.json \
    2>&1 | tee -a "$LOG_DIR/wave1_audit.log" || true
fi

"$PYTHON" scripts/prepare_mealybug_v20_audit.py --apply --add-conf 0.50 \
  2>&1 | tee -a "$LOG_DIR/wave1_autofix.log"

log "=== Wave 2: build mealybug_v20 ==="
"$PYTHON" scripts/build_mealybug_v20_dataset.py \
  2>&1 | tee -a "$LOG_DIR/wave2_build.log"

log "=== Wave 3a: train v20s (YOLO26s @ 1280) ==="
"$YOLO_BIN" detect train \
  model=yolo26s.pt \
  data="$DATA_V20" \
  epochs=80 imgsz=1280 batch="${BATCH_S:-0.8}" workers=12 \
  optimizer=AdamW lr0=0.0005 lrf=0.01 cos_lr=True \
  warmup_epochs=3 patience=25 close_mosaic=15 \
  iou=0.45 box=7.5 dropout=0.1 \
  hsv_h=0.015 hsv_s=0.5 hsv_v=0.4 degrees=10 translate=0.1 scale=0.5 fliplr=0.5 \
  mosaic=1.0 copy_paste=0 \
  project=runs/retrain name=mealybug_v20s \
  2>&1 | tee -a "$LOG_DIR/wave3_v20s.log"

log "=== M1 eval: v20s on corrected test ==="
"$PYTHON" scripts/capture_v16_baseline.py --skip-label-fix \
  --model runs/detect/runs/retrain/mealybug_v20s/weights/best.pt \
  --out-subdir v20s_m1 \
  2>&1 | tee -a "$LOG_DIR/m1_eval.log"

log "=== Wave 3b: train v20m (YOLO26m @ 1280) ==="
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
"$PYTHON" scripts/capture_v16_baseline.py --skip-label-fix \
  --model runs/detect/runs/retrain/mealybug_v20m/weights/best.pt \
  --out-subdir v20m_m3 \
  2>&1 | tee -a "$LOG_DIR/m3_eval.log"

log "=== DONE ==="
log "Download: docs/thesis/assets/v18_baseline/, runs/retrain/mealybug_v20m/, runs/v18_pipeline/"
