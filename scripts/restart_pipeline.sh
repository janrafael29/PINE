#!/usr/bin/env bash
# Clean-kill everything, then restart the pipeline inside tmux (survives any ssh cleanup).
cd /workspace/pine

pkill -f '[v]18_full_pipeline_vast' 2>/dev/null
pkill -f '[a]udit_annotations' 2>/dev/null
pkill -f '[p]repare_mealybug_v20' 2>/dev/null
pkill -f '[a]uto_fix_annotations' 2>/dev/null
pkill -f '[b]uild_mealybug_v20' 2>/dev/null
pkill -f '[y]olo detect train' 2>/dev/null
sleep 3

# v20_audit was corrupted by a half-finished copy; prepare rebuilds it from scratch anyway
rm -rf datasets/mealybug_v20_audit datasets/mealybug_v20

mkdir -p runs/v18_pipeline
tmux kill-session -t pipeline 2>/dev/null
tmux new-session -d -s pipeline \
  "cd /workspace/pine && SKIP_PHASE0=1 SKIP_AUDIT=1 bash scripts/v18_full_pipeline_vast.sh >> runs/v18_pipeline/nohup.log 2>&1"
sleep 8

echo "--- tmux sessions ---"
tmux ls
echo "--- pipeline.log ---"
tail -3 runs/v18_pipeline/pipeline.log
echo "--- processes ---"
pgrep -af '[v]18_full|[p]repare_mealybug|[a]uto_fix'
echo "--- launched ok ---"
