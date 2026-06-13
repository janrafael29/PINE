#!/usr/bin/env bash
# Wait for v20m training to finish, then run M3 eval with correct weights path.
set -euo pipefail

ROOT="${ROOT:-/workspace/pine}"
cd "$ROOT"
LOG="$ROOT/runs/v18_pipeline/m3_watch.log"
mkdir -p "$(dirname "$LOG")"

log() { echo "[$(date -Iseconds)] $*" | tee -a "$LOG"; }

if [[ -f docs/thesis/assets/v18_baseline/v20m_m3/v20m_m3_corrected_test_metrics.json ]]; then
  log "M3 eval already done — skipping."
  exit 0
fi

log "M3 watcher started — waiting for v20m training to finish..."

while pgrep -f 'yolo detect train.*mealybug_v20m' >/dev/null 2>&1; do
  sleep 120
done

sleep 10
log "v20m training done — running M3 eval..."
bash scripts/run_m3_eval.sh 2>&1 | tee -a "$LOG"
log "M3 watcher complete."
