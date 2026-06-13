#!/usr/bin/env bash
cd /workspace/pine
mkdir -p runs/consensus
tmux kill-session -t consensus 2>/dev/null || true
tmux new-session -d -s consensus \
  'cd /workspace/pine && bash scripts/run_consensus_pipeline.sh >> runs/consensus/nohup.log 2>&1'
sleep 3
tmux ls
tail -5 runs/consensus/pipeline.log 2>/dev/null || tail -5 runs/consensus/nohup.log 2>/dev/null
