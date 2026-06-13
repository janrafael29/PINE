#!/usr/bin/env bash
# Run on Vast.ai instance after upload (project root = ~/pine or /workspace/pine)
set -euo pipefail
cd "$(dirname "$0")/.."
echo "PWD=$(pwd)"
python3 -m pip install -U pip
python3 -m pip install -r scripts/requirements-train.txt
python3 -u scripts/retrain_yolo.py \
  --weights runs/retrain/mealybug_v2/weights/best.pt \
  --name mealybug_fix500_e50 \
  --epochs 50 \
  --batch 16 \
  --imgsz 640 \
  --patience 15 \
  --device 0 \
  --workers 8 \
  --no-export
echo "Done. Download: runs/retrain/mealybug_fix500_e50/weights/best.pt"
