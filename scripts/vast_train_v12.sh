#!/usr/bin/env bash
# mealybug_v12 — high-res 1024 train (200 epochs, AdamW, cosine LR)
# Prereq: unzip pine_v11_train_bundle.zip (or v12 bundle with v10 data + v11 weights), then:
#   cd pine && bash scripts/vast_train_v12.sh
set -euo pipefail
cd "$(dirname "$0")/.."
echo "PWD=$(pwd)"

V10="mealybug.v10-8th-yolo26n.yolo26"
DATA="$V10/data.yaml"
if [[ ! -f "$DATA" ]]; then
  DATA="$V10/data_fixed.yaml"
fi
if [[ ! -f "$DATA" ]]; then
  echo "Missing $V10/data.yaml — upload dataset + weights first."
  exit 1
fi

python3 -m pip install -U pip
python3 -m pip install -r scripts/requirements-train.txt

WEIGHTS="runs/retrain/mealybug_v11/weights/best.pt"
if [[ ! -f "$WEIGHTS" ]]; then
  echo "Missing $WEIGHTS — start from v11 or set --weights mealybug_v10/..."
  WEIGHTS="runs/retrain/mealybug_v10/weights/best.pt"
fi

# 1024 @ batch 8 fits most 24GB GPUs; override: BATCH=16 bash scripts/vast_train_v12.sh
BATCH="${BATCH:-8}"

python3 -u scripts/retrain_yolo.py \
  --preset v12-highres \
  --data "$DATA" \
  --weights "$WEIGHTS" \
  --batch "$BATCH" \
  --device 0 \
  --workers 8 \
  --no-export

echo "Done. Download: runs/retrain/mealybug_v12/weights/best.pt"
echo "On Windows:"
echo "  python scripts/retrain_yolo.py --export-only runs/retrain/mealybug_v12/weights/best.pt --export-imgsz 640"
