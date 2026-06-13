#!/usr/bin/env bash
# Start GroundingDINO prediction caching in tmux (runs alongside training).
cd /workspace/pine
mkdir -p runs/consensus
tmux kill-session -t gdino 2>/dev/null
tmux new-session -d -s gdino \
  'cd /workspace/pine && /venv/main/bin/python3 scripts/cache_detections.py --backend gdino --images datasets/mealybug_v20/train/images --out runs/consensus/gdino_train.jsonl >> runs/consensus/gdino.log 2>&1'
sleep 15
tmux ls
echo "--- gdino.log ---"
tail -5 runs/consensus/gdino.log 2>/dev/null || echo "(log not written yet)"
