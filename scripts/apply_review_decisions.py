#!/usr/bin/env python3
"""Apply decisions.json from the review grid onto consensus labels.

- add?    accepted  -> append box to label file (if not already present)
- add?    rejected  -> nothing (box never added)
- remove? accepted  -> drop the GT box (human confirmed it's not a mealybug)
- remove? rejected  -> keep the GT box (human says it's real)

Usage:
  python scripts/apply_review_decisions.py \
      --decisions runs/consensus/review/decisions.json \
      --labels datasets/mealybug_v21/train/labels \
      --images datasets/mealybug_v20/train/images
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import cv2

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--decisions", type=Path, required=True)
    ap.add_argument("--labels", type=Path, required=True)
    ap.add_argument("--images", type=Path, required=True)
    ap.add_argument("--iou-dup", type=float, default=0.6)
    args = ap.parse_args()

    decisions = json.loads(args.decisions.read_text(encoding="utf-8"))
    sizes: dict[str, tuple[int, int]] = {}
    added = removed = kept = 0

    def size_of(image: str) -> tuple[int, int]:
        if image not in sizes:
            im = cv2.imread(str(args.images / image))
            sizes[image] = (im.shape[1], im.shape[0])
        return sizes[image]

    def iou(a, b) -> float:
        ix1, iy1 = max(a[0], b[0]), max(a[1], b[1])
        ix2, iy2 = min(a[2], b[2]), min(a[3], b[3])
        iw, ih = max(0.0, ix2 - ix1), max(0.0, iy2 - iy1)
        inter = iw * ih
        if inter <= 0:
            return 0.0
        aa = (a[2] - a[0]) * (a[3] - a[1])
        ab = (b[2] - b[0]) * (b[3] - b[1])
        return inter / (aa + ab - inter)

    by_image: dict[str, list[dict]] = {}
    for d in decisions:
        by_image.setdefault(d["image"], []).append(d)

    for image, ds in by_image.items():
        w, h = size_of(image)
        lbl = args.labels / f"{Path(image).stem}.txt"
        boxes: list[list[float]] = []
        if lbl.is_file():
            for line in lbl.read_text(encoding="utf-8").splitlines():
                parts = line.split()
                if len(parts) < 5:
                    continue
                xc, yc, bw, bh = (float(v) for v in parts[1:5])
                boxes.append(
                    [(xc - bw / 2) * w, (yc - bh / 2) * h, (xc + bw / 2) * w, (yc + bh / 2) * h]
                )

        for d in ds:
            box = d["box"]
            if d["kind"] == "add?" and d["accepted"]:
                if all(iou(box, b) < args.iou_dup for b in boxes):
                    boxes.append(box)
                    added += 1
            elif d["kind"] == "remove?" and d["accepted"]:
                before = len(boxes)
                boxes = [b for b in boxes if iou(box, b) < args.iou_dup]
                removed += before - len(boxes)
            else:
                kept += 1

        lines = []
        for b in boxes:
            xc = (b[0] + b[2]) / 2 / w
            yc = (b[1] + b[3]) / 2 / h
            bw = (b[2] - b[0]) / w
            bh = (b[3] - b[1]) / h
            lines.append(f"0 {xc:.6f} {yc:.6f} {bw:.6f} {bh:.6f}")
        lbl.write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")

    print(f"added={added} removed={removed} unchanged_decisions={kept}")


if __name__ == "__main__":
    main()
