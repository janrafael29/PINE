#!/usr/bin/env bash
# Resolve YOLO best.pt path (Ultralytics may nest under runs/detect/runs/retrain/).
resolve_weights() {
  local name="$1"
  local p
  for p in \
    "runs/detect/runs/retrain/${name}/weights/best.pt" \
    "runs/retrain/${name}/weights/best.pt"; do
    if [[ -f "$p" ]]; then
      echo "$p"
      return 0
    fi
  done
  echo "ERROR: weights not found for ${name}" >&2
  return 1
}
