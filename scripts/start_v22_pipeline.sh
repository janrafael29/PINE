#!/usr/bin/env bash
cd /workspace/pine
chmod +x scripts/prepare_mealybug_v22_selffix.py scripts/train_v22_vast.sh scripts/run_v22_selffix_pipeline.sh
mkdir -p runs/v22_pipeline runs/audit
tmux kill-session -t v22 2>/dev/null || true
tmux new-session -d -s v22 \
  'cd /workspace/pine && bash scripts/run_v22_selffix_pipeline.sh >> runs/v22_pipeline/nohup.log 2>&1'
sleep 3
tmux ls
tail -8 runs/v22_pipeline/nohup.log 2>/dev/null || tail -8 runs/v22_pipeline/full.log 2>/dev/null
