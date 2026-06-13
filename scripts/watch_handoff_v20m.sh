#!/usr/bin/env bash
# Wait for v20s to finish, then hand off to v20m @ 150 epochs (replaces pipeline's 120-epoch step).
set -euo pipefail

ROOT="${ROOT:-/workspace/pine}"
cd "$ROOT"
LOG="$ROOT/runs/v18_pipeline/handoff.log"
mkdir -p "$(dirname "$LOG")"

log() { echo "[$(date -Iseconds)] $*" | tee -a "$LOG"; }

log "Handoff watcher started — waiting for v20s to finish..."

while pgrep -f 'yolo detect train.*mealybug_v20s' >/dev/null 2>&1; do
  sleep 60
done

log "v20s training done — waiting for M1 eval..."
while pgrep -f 'capture_v16_baseline.*v20s' >/dev/null 2>&1; do
  sleep 10
done
sleep 5

log "Stopping old pipeline before 120-epoch v20m starts..."
pkill -f '[v]18_full_pipeline_vast' 2>/dev/null || true
sleep 3
pkill -f 'yolo detect train.*mealybug_v20m' 2>/dev/null || true
sleep 3

log "Launching v20m @ 150 epochs..."
bash scripts/train_v20m_150.sh 2>&1 | tee -a "$LOG"

log "Handoff complete."
