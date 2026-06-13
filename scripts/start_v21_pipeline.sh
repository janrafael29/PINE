#!/usr/bin/env bash
cd /workspace/pine
chmod +x scripts/run_consensus_strict.sh scripts/train_v21_vast.sh scripts/run_v21_full_pipeline.sh
mkdir -p runs/v21_pipeline runs/consensus
tmux kill-session -t v21 2>/dev/null || true
tmux new-session -d -s v21 \
  'cd /workspace/pine && bash scripts/run_v21_full_pipeline.sh >> runs/v21_pipeline/nohup.log 2>&1'
sleep 3
tmux ls
tail -8 runs/consensus/strict.log 2>/dev/null || tail -8 runs/v21_pipeline/nohup.log 2>/dev/null
