#!/usr/bin/env bash
# mealybug_va — field-only annotations (~877 images)
# Prereq: unzip pine_va_field_bundle.zip, then:
#   cd pine && bash scripts/vast_train_va.sh
set -euo pipefail
cd "$(dirname "$0")/.."
echo "PWD=$(pwd)"

DATA="datasets/mealybug_va_field/data.yaml"
if [[ ! -f "$DATA" ]]; then
  echo "Missing $DATA — upload pine_va_field_bundle.zip first."
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
  --preset va \
  --data "$DATA" \
  --weights "$WEIGHTS" \
  --batch "$BATCH" \
  --device 0 \
  --workers 8 \
  --no-export

echo "Done. Download: runs/retrain/mealybug_va/weights/best.pt"
echo "Eval:"
echo "  python scripts/eval_va_field.py"
