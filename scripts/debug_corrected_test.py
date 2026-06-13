#!/usr/bin/env python3
"""Per-image error analysis on v16 vs corrected (or legacy) test labels."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument(
        "--model",
        type=Path,
        default=ROOT / "runs" / "retrain" / "mealybug_v16_selffix" / "weights" / "best.pt",
    )
    p.add_argument(
        "--images",
        type=Path,
        default=ROOT / "datasets" / "mealybug_v13afix" / "test" / "images",
    )
    p.add_argument(
        "--labels",
        type=Path,
        default=ROOT / "datasets" / "mealybug_v13afix" / "test" / "labels_v16_corrected",
    )
    p.add_argument("--imgsz", type=int, default=1280)
    p.add_argument("--conf", type=float, default=0.001, help="Val-style low conf for mAP matching")
    p.add_argument("--match-iou", type=float, default=0.5)
    p.add_argument("--top-k", type=int, default=40)
    p.add_argument(
        "--out",
        type=Path,
        default=ROOT / "runs" / "debug" / "v16_corrected_test_errors.json",
    )
    return p.parse_args()


def load_gt_xyxy(label_path: Path, w: int, h: int) -> list[np.ndarray]:
    boxes = []
    if not label_path.exists():
        return boxes
    for line in label_path.read_text(encoding="utf-8").strip().splitlines():
        if not line.strip():
            continue
        parts = line.split()
        cx, cy, bw, bh = map(float, parts[1:5])
        x1 = (cx - bw / 2) * w
        y1 = (cy - bh / 2) * h
        x2 = (cx + bw / 2) * w
        y2 = (cy + bh / 2) * h
        boxes.append(np.array([x1, y1, x2, y2], dtype=np.float32))
    return boxes


def iou_matrix(a: list[np.ndarray], b: list[np.ndarray]) -> np.ndarray:
    if not a or not b:
        return np.zeros((len(a), len(b)))
    A = np.stack(a)
    B = np.stack(b)
    inter_x1 = np.maximum(A[:, None, 0], B[None, :, 0])
    inter_y1 = np.maximum(A[:, None, 1], B[None, :, 1])
    inter_x2 = np.minimum(A[:, None, 2], B[None, :, 2])
    inter_y2 = np.minimum(A[:, None, 3], B[None, :, 3])
    inter = np.clip(inter_x2 - inter_x1, 0, None) * np.clip(inter_y2 - inter_y1, 0, None)
    area_a = (A[:, 2] - A[:, 0]) * (A[:, 3] - A[:, 1])
    area_b = (B[:, 2] - B[:, 0]) * (B[:, 3] - B[:, 1])
    union = area_a[:, None] + area_b[None, :] - inter
    return inter / np.maximum(union, 1e-9)


def main() -> None:
    args = parse_args()
    from PIL import Image
    from ultralytics import YOLO

    model = YOLO(str(args.model))
    rows = []

    for img_path in sorted(args.images.glob("*.*")):
        if img_path.suffix.lower() not in {".jpg", ".jpeg", ".png", ".bmp"}:
            continue
        img = Image.open(img_path)
        w, h = img.size
        gt = load_gt_xyxy(args.labels / f"{img_path.stem}.txt", w, h)

        r = model(str(img_path), imgsz=args.imgsz, conf=args.conf, iou=0.5, verbose=False)[0]
        preds: list[np.ndarray] = []
        if r.boxes is not None and len(r.boxes):
            for box in r.boxes.xyxy.cpu().numpy():
                preds.append(box.astype(np.float32))

        ious = iou_matrix(gt, preds)
        gt_matched = (ious.max(axis=1) >= args.match_iou) if len(gt) else np.array([], dtype=bool)
        pred_matched = (ious.max(axis=0) >= args.match_iou) if len(preds) else np.array([], dtype=bool)

        fn = int((~gt_matched).sum()) if len(gt) else 0
        fp = int((~pred_matched).sum()) if len(preds) else 0
        tp = int(gt_matched.sum()) if len(gt) else 0

        rows.append(
            {
                "image": img_path.name,
                "gt": len(gt),
                "pred": len(preds),
                "tp": tp,
                "fn": fn,
                "fp": fp,
                "error_score": fn + fp,
            }
        )

    rows.sort(key=lambda x: x["error_score"], reverse=True)
    summary = {
        "images": len(rows),
        "total_gt": sum(r["gt"] for r in rows),
        "total_pred": sum(r["pred"] for r in rows),
        "total_tp": sum(r["tp"] for r in rows),
        "total_fn": sum(r["fn"] for r in rows),
        "total_fp": sum(r["fp"] for r in rows),
        "match_iou": args.match_iou,
        "conf": args.conf,
        "worst_images": rows[: args.top_k],
    }

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps({k: summary[k] for k in summary if k != "worst_images"}, indent=2))
    print(f"Wrote {args.out}")


if __name__ == "__main__":
    main()
