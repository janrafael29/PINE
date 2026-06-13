#!/usr/bin/env bash
# mealybug_v13afix — v10 + Va field + fix500 (~17.5k train), fine-tune from v12 @ 640
# After upload pine_v13afix_train_bundle.zip:
#   cd /workspace && unzip -q pine_v13afix_train_bundle.zip -d pine
#   cd pine && bash scripts/vast_train_v13afix.sh
#   DEVICE=0,1 WORKERS=16 bash scripts/vast_train_v13afix.sh   # 2 GPUs
set -euo pipefail
cd "$(dirname "$0")/.."
echo "PWD=$(pwd)"

DATA="datasets/mealybug_v13afix/data.yaml"
WEIGHTS="runs/retrain/mealybug_v12/weights/best.pt"
if [[ ! -f "$DATA" ]]; then
  echo "Missing $DATA — unzip pine_v13afix_train_bundle.zip first."
  exit 1
fi
if [[ ! -f "$WEIGHTS" ]]; then
  echo "Missing $WEIGHTS"
  exit 1
fi

python3 -m pip install -U pip
python3 -m pip install -r scripts/requirements-train.txt

BATCH="${BATCH:-16}"
DEVICE="${DEVICE:-0}"
WORKERS="${WORKERS:-8}"
echo "BATCH=$BATCH DEVICE=$DEVICE WORKERS=$WORKERS"
python3 -u scripts/retrain_yolo.py \
  --preset v13afix \
  --data "$DATA" \
  --weights "$WEIGHTS" \
  --batch "$BATCH" \
  --device "$DEVICE" \
  --workers "$WORKERS" \
  --no-export

echo ""
echo "Done. Download to your PC:"
echo "  runs/retrain/mealybug_v13afix/weights/best.pt"
echo "Compare:"
echo "  python scripts/compare_all_retrains.py"
