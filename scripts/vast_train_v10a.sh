#!/usr/bin/env bash
# mealybug_v10a — v10 + field annotations (combined), 640 fine-tune from v11
# Prereq: unzip pine_v10a_train_bundle.zip, then:
#   cd pine && bash scripts/vast_train_v10a.sh
set -euo pipefail
cd "$(dirname "$0")/.."
echo "PWD=$(pwd)"

DATA="datasets/mealybug_v10_plus_annotations/data.yaml"
if [[ ! -f "$DATA" ]]; then
  echo "Missing $DATA — upload pine_v10a_train_bundle.zip first."
  exit 1
fi

python3 -m pip install -U pip
python3 -m pip install -r scripts/requirements-train.txt

WEIGHTS="runs/retrain/mealybug_v11/weights/best.pt"
if [[ ! -f "$WEIGHTS" ]]; then
  echo "Missing $WEIGHTS"
  exit 1
fi

BATCH="${BATCH:-16}"

python3 -u scripts/retrain_yolo.py \
  --preset v10a \
  --data "$DATA" \
  --weights "$WEIGHTS" \
  --batch "$BATCH" \
  --device 0 \
  --workers 8 \
  --no-export

echo "Done. Download: runs/retrain/mealybug_v10a/weights/best.pt"
echo "Compare vs v12:"
echo "  python scripts/compare_v10a_v12.py"
