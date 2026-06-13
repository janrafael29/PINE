#!/usr/bin/env bash
# Train on full Roboflow v10 export (~17.5k images) on Vast GPU.
# Unzip bundle, then: cd pine && bash scripts/vast_train_v10.sh
set -euo pipefail
cd "$(dirname "$0")/.."
echo "PWD=$(pwd)"

V10="mealybug.v10-8th-yolo26n.yolo26"
if [[ ! -f "$V10/data.yaml" ]]; then
  echo "Missing $V10/data.yaml — unzip pine_v10_train_bundle.zip first."
  exit 1
fi

python3 -m pip install -U pip
python3 -m pip install -r scripts/requirements-train.txt

# Start from v2 (better field photo scores than fix500); or yolo26n.pt for fresh head.
WEIGHTS="runs/retrain/mealybug_v2/weights/best.pt"
if [[ ! -f "$WEIGHTS" ]]; then
  WEIGHTS="yolo26n.pt"
fi

python3 -u scripts/retrain_yolo.py \
  --data "$V10/data.yaml" \
  --weights "$WEIGHTS" \
  --name mealybug_v10 \
  --epochs 100 \
  --batch 16 \
  --imgsz 640 \
  --patience 20 \
  --device 0 \
  --workers 8 \
  --no-export

echo "Done. Download: runs/retrain/mealybug_v10/weights/best.pt"
echo "Export TFLite on Windows: python scripts/retrain_yolo.py --export-only runs/retrain/mealybug_v10/weights/best.pt"
