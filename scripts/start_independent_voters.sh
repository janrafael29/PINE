#!/usr/bin/env bash
# Cache OWLv2 then YOLO-World predictions (sequential, in one tmux session,
# so they don't fight the main training run for GPU).
cd /workspace/pine
mkdir -p runs/consensus
tmux kill-session -t voters 2>/dev/null
tmux new-session -d -s voters '
cd /workspace/pine
PY=/venv/main/bin/python3
$PY scripts/cache_detections.py --backend owlv2 \
  --images datasets/mealybug_v20/train/images \
  --out runs/consensus/owlv2_train.jsonl >> runs/consensus/owlv2.log 2>&1
$PY scripts/cache_detections.py --backend yoloworld \
  --images datasets/mealybug_v20/train/images \
  --out runs/consensus/yoloworld_train.jsonl >> runs/consensus/yoloworld.log 2>&1
echo DONE > runs/consensus/voters_done.txt
'
sleep 10
tmux ls
tail -3 runs/consensus/owlv2.log 2>/dev/null || echo "(owlv2 starting)"
