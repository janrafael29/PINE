#!/usr/bin/env bash
# Fine-tune v10 on cleaned v10 labels → mealybug_v11
# Prereq: unzip pine_v11_train_bundle.zip, then:
#   cd pine && bash scripts/vast_train_v11.sh
set -euo pipefail
cd "$(dirname "$0")/.."
echo "PWD=$(pwd)"

V10="mealybug.v10-8th-yolo26n.yolo26"
# Prefer data.yaml (Roboflow relative paths). data_fixed must not contain Windows path:.
DATA="$V10/data.yaml"
if [[ ! -f "$DATA" ]]; then
  DATA="$V10/data_fixed.yaml"
fi
if [[ ! -f "$DATA" ]]; then
  echo "Missing $V10/data.yaml — unzip pine_v11_train_bundle.zip first."
  exit 1
fi

python3 -m pip install -U pip
python3 -m pip install -r scripts/requirements-train.txt

WEIGHTS="runs/retrain/mealybug_v10/weights/best.pt"
if [[ ! -f "$WEIGHTS" ]]; then
  echo "Missing $WEIGHTS — bundle must include v10 best.pt"
  exit 1
fi

# Shorter fine-tune: labels are cleaner, model already knows mealybugs
python3 -u scripts/retrain_yolo.py \
  --data "$DATA" \
  --weights "$WEIGHTS" \
  --name mealybug_v11 \
  --epochs 50 \
  --batch 16 \
  --imgsz 640 \
  --patience 15 \
  --device 0 \
  --workers 8 \
  --no-export

echo "Done. Download: runs/retrain/mealybug_v11/weights/best.pt"
echo "On Windows: python scripts/retrain_yolo.py --export-only runs/retrain/mealybug_v11/weights/best.pt"
