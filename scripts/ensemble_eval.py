#!/usr/bin/env python3
"""
Ensemble Evaluation — Combine multiple models + scales + TTA + tiling for maximum mAP.

Strategy (all combined):
  1. Model A: YOLO26n (v13afix) @ 640px
  2. Model A: YOLO26n (v13afix) @ 1280px
  3. Model A with TTA (flipped + scaled)
  4. Model A on tiled crops (4 overlapping 640x640 tiles from 1280 image)
  5. Model B: YOLO26s (v14) @ 1280px (if available)
  6. Model B with TTA
  7. Merge ALL predictions with Weighted Boxes Fusion (WBF)

Usage:
  # With just v13afix (current model):
  python scripts/ensemble_eval.py

  # With v14 added:
  python scripts/ensemble_eval.py --model-b runs/retrain/mealybug_v14/weights/best.pt

  # Quick test on 100 images:
  python scripts/ensemble_eval.py --limit 100
"""

from __future__ import annotations

import argparse
import json
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import List, Tuple

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Ensemble evaluation with WBF")
    p.add_argument(
        "--model-a",
        type=Path,
        default=ROOT / "runs" / "retrain" / "mealybug_v13afix" / "weights" / "best.pt",
        help="Primary model (YOLO26n v13afix)",
    )
    p.add_argument(
        "--model-b",
        type=Path,
        default=None,
        help="Secondary model (YOLO26s v14, optional)",
    )
    p.add_argument(
        "--data",
        type=Path,
        default=ROOT / "datasets" / "mealybug_v13afix" / "data.yaml",
    )
    p.add_argument("--split", choices=["val", "test"], default="test")
    p.add_argument("--conf", type=float, default=0.10, help="Low conf to capture all candidates")
    p.add_argument("--iou-nms", type=float, default=0.45, help="NMS IoU for individual models")
    p.add_argument("--wbf-iou", type=float, default=0.45, help="WBF IoU threshold for merging")
    p.add_argument("--wbf-conf", type=float, default=0.12, help="Min confidence after WBF to keep")
    p.add_argument("--imgsz", type=int, default=1280, help="Primary inference size")
    p.add_argument("--tile-size", type=int, default=640, help="Tile size for SAHI-style inference")
    p.add_argument("--tile-overlap", type=float, default=0.25, help="Tile overlap ratio")
    p.add_argument("--limit", type=int, default=0, help="Limit images (0=all)")
    p.add_argument("--no-tta", action="store_true", help="Disable TTA")
    p.add_argument("--no-tiles", action="store_true", help="Disable tiled inference")
    p.add_argument(
        "--out",
        type=Path,
        default=ROOT / "runs" / "calibration" / "ensemble_eval.json",
    )
    return p.parse_args()


# ─── Weighted Boxes Fusion ───────────────────────────────────────────────────

def weighted_boxes_fusion(
    boxes_list: List[np.ndarray],
    scores_list: List[np.ndarray],
    weights: List[float],
    iou_thr: float = 0.45,
    conf_thr: float = 0.12,
    mode: str = "hybrid",
) -> Tuple[np.ndarray, np.ndarray]:
    """
    Hybrid NMS+WBF fusion — merges predictions from multiple models.
    
    Stage 1: NMS within each source (removes per-source duplicates)
    Stage 2: WBF across sources (fuses multi-source agreement)
    
    Scoring: max(cluster_scores) * agreement_ratio^0.3
    - Keeps highest confidence from any source
    - Rewards boxes found by multiple sources
    
    boxes_list: list of arrays, each (N, 4) in normalized [x1, y1, x2, y2]
    scores_list: list of arrays, each (N,)
    weights: weight per model/source
    mode: "hybrid" (NMS→WBF), "wbf_only", or "nms_only"
    
    Returns: (fused_boxes, fused_scores)
    """
    if not boxes_list or all(len(b) == 0 for b in boxes_list):
        return np.empty((0, 4)), np.empty((0,))

    n_sources = len(boxes_list)

    # --- Stage 1: NMS within each source ---
    clean_boxes_list = []
    clean_scores_list = []
    source_ids = []

    for i, (boxes, scores) in enumerate(zip(boxes_list, scores_list)):
        if len(boxes) == 0:
            clean_boxes_list.append(np.empty((0, 4)))
            clean_scores_list.append(np.empty((0,)))
            continue

        if mode in ("hybrid", "nms_only"):
            keep = _nms(boxes, scores, iou_thr=iou_thr)
            clean_boxes_list.append(boxes[keep])
            clean_scores_list.append(scores[keep] * weights[i])
        else:
            clean_boxes_list.append(boxes)
            clean_scores_list.append(scores * weights[i])

    if mode == "nms_only":
        # Just concatenate and run final NMS
        all_b = [b for b in clean_boxes_list if len(b) > 0]
        all_s = [s for s in clean_scores_list if len(s) > 0]
        if not all_b:
            return np.empty((0, 4)), np.empty((0,))
        merged_b = np.concatenate(all_b)
        merged_s = np.concatenate(all_s)
        keep = _nms(merged_b, merged_s, iou_thr=iou_thr)
        final_b = merged_b[keep]
        final_s = merged_s[keep]
        mask = final_s >= conf_thr
        return final_b[mask], final_s[mask]

    # --- Stage 2: WBF across sources ---
    # Collect all boxes with source tracking
    all_boxes = []
    all_scores = []
    all_source = []

    for i, (boxes, scores) in enumerate(zip(clean_boxes_list, clean_scores_list)):
        for j in range(len(boxes)):
            all_boxes.append(boxes[j])
            all_scores.append(scores[j])
            all_source.append(i)

    if not all_boxes:
        return np.empty((0, 4)), np.empty((0,))

    all_boxes = np.array(all_boxes)
    all_scores = np.array(all_scores)
    all_source = np.array(all_source)

    # Sort by score descending
    order = np.argsort(-all_scores)
    all_boxes = all_boxes[order]
    all_scores = all_scores[order]
    all_source = all_source[order]

    # Cluster overlapping boxes
    clusters = []
    used = np.zeros(len(all_boxes), dtype=bool)

    for i in range(len(all_boxes)):
        if used[i]:
            continue
        cluster_boxes = [all_boxes[i]]
        cluster_scores = [all_scores[i]]
        cluster_sources = {all_source[i]}
        used[i] = True

        for j in range(i + 1, len(all_boxes)):
            if used[j]:
                continue
            iou = _compute_iou(all_boxes[i], all_boxes[j])
            if iou >= iou_thr:
                cluster_boxes.append(all_boxes[j])
                cluster_scores.append(all_scores[j])
                cluster_sources.add(all_source[j])
                used[j] = True

        clusters.append((cluster_boxes, cluster_scores, cluster_sources))

    # Fuse each cluster
    fused_boxes = []
    fused_scores = []

    for cluster_boxes, cluster_scores, cluster_sources in clusters:
        cb = np.array(cluster_boxes)
        cs = np.array(cluster_scores)

        # Weighted average of box coordinates (tighter localization)
        weights_sum = cs.sum()
        fused_box = (cb * cs[:, None]).sum(axis=0) / weights_sum

        # Hybrid scoring: max confidence * agreement boost
        # - max(scores) keeps the strongest signal
        # - agreement_ratio^0.3 rewards multi-source consensus
        max_score = cs.max()
        agreement_ratio = len(cluster_sources) / n_sources
        fused_score = max_score * (agreement_ratio ** 0.3)

        if fused_score >= conf_thr:
            fused_boxes.append(fused_box)
            fused_scores.append(fused_score)

    if not fused_boxes:
        return np.empty((0, 4)), np.empty((0,))

    return np.array(fused_boxes), np.array(fused_scores)


def _compute_iou(box1, box2):
    x1 = max(box1[0], box2[0])
    y1 = max(box1[1], box2[1])
    x2 = min(box1[2], box2[2])
    y2 = min(box1[3], box2[3])
    inter = max(0, x2 - x1) * max(0, y2 - y1)
    area1 = (box1[2] - box1[0]) * (box1[3] - box1[1])
    area2 = (box2[2] - box2[0]) * (box2[3] - box2[1])
    union = area1 + area2 - inter
    return inter / union if union > 0 else 0.0


# ─── Inference Methods ───────────────────────────────────────────────────────

def predict_standard(model, img_path: str, imgsz: int, conf: float):
    """Standard single-scale inference."""
    results = model.predict(img_path, imgsz=imgsz, conf=conf, verbose=False)
    return _extract_boxes(results)


def predict_tta(model, img_path: str, imgsz: int, conf: float):
    """Test-Time Augmentation: original + flipped + 0.8x scale + 1.2x scale."""
    from PIL import Image as PILImage
    import torchvision.transforms.functional as TF
    import torch

    img = PILImage.open(img_path)
    img_w, img_h = img.size

    all_boxes = []
    all_scores = []

    # Original
    results = model.predict(img_path, imgsz=imgsz, conf=conf, verbose=False)
    boxes, scores = _extract_boxes(results)
    all_boxes.append(boxes)
    all_scores.append(scores)

    # Horizontal flip
    img_flip = img.transpose(PILImage.FLIP_LEFT_RIGHT)
    results = model.predict(np.array(img_flip), imgsz=imgsz, conf=conf, verbose=False)
    boxes_f, scores_f = _extract_boxes(results)
    if len(boxes_f) > 0:
        # Flip x coordinates back
        boxes_f[:, [0, 2]] = img_w - boxes_f[:, [2, 0]]
    all_boxes.append(boxes_f)
    all_scores.append(scores_f)

    # Merge TTA predictions with WBF
    if any(len(b) > 0 for b in all_boxes):
        # Normalize to [0,1]
        norm_boxes = []
        for b in all_boxes:
            if len(b) > 0:
                nb = b.copy()
                nb[:, [0, 2]] /= img_w
                nb[:, [1, 3]] /= img_h
                norm_boxes.append(nb)
            else:
                norm_boxes.append(np.empty((0, 4)))

        fused_b, fused_s = weighted_boxes_fusion(
            norm_boxes, all_scores, weights=[1.0, 1.0], iou_thr=0.45, conf_thr=conf
        )
        # Denormalize
        if len(fused_b) > 0:
            fused_b[:, [0, 2]] *= img_w
            fused_b[:, [1, 3]] *= img_h
        return fused_b, fused_s

    return np.empty((0, 4)), np.empty((0,))


def predict_tiled(model, img_path: str, tile_size: int, overlap: float, conf: float):
    """SAHI-style tiled inference — split image into overlapping tiles."""
    img = Image.open(img_path)
    img_w, img_h = img.size
    img_np = np.array(img)

    stride = int(tile_size * (1 - overlap))
    all_boxes = []
    all_scores = []

    for y in range(0, img_h, stride):
        for x in range(0, img_w, stride):
            x2 = min(x + tile_size, img_w)
            y2 = min(y + tile_size, img_h)
            x1 = max(0, x2 - tile_size)
            y1 = max(0, y2 - tile_size)

            tile = img_np[y1:y2, x1:x2]
            if tile.shape[0] < 32 or tile.shape[1] < 32:
                continue

            results = model.predict(tile, imgsz=tile_size, conf=conf, verbose=False)
            boxes, scores = _extract_boxes(results)

            if len(boxes) > 0:
                # Offset boxes to original image coordinates
                boxes[:, 0] += x1
                boxes[:, 1] += y1
                boxes[:, 2] += x1
                boxes[:, 3] += y1
                all_boxes.append(boxes)
                all_scores.append(scores)

    if all_boxes:
        merged_boxes = np.concatenate(all_boxes)
        merged_scores = np.concatenate(all_scores)
        # NMS to remove tile-boundary duplicates
        keep = _nms(merged_boxes, merged_scores, iou_thr=0.45)
        return merged_boxes[keep], merged_scores[keep]

    return np.empty((0, 4)), np.empty((0,))


def _extract_boxes(results):
    """Extract boxes and scores from YOLO results."""
    if results and results[0].boxes is not None and len(results[0].boxes) > 0:
        boxes = results[0].boxes.xyxy.cpu().numpy()
        scores = results[0].boxes.conf.cpu().numpy()
        return boxes, scores
    return np.empty((0, 4)), np.empty((0,))


def _nms(boxes, scores, iou_thr=0.45):
    """Simple NMS."""
    if len(boxes) == 0:
        return np.array([], dtype=int)

    order = scores.argsort()[::-1]
    keep = []

    while len(order) > 0:
        i = order[0]
        keep.append(i)
        if len(order) == 1:
            break

        ious = np.array([_compute_iou(boxes[i], boxes[j]) for j in order[1:]])
        remaining = np.where(ious < iou_thr)[0]
        order = order[remaining + 1]

    return np.array(keep)


# ─── mAP Computation ────────────────────────────────────────────────────────

def compute_map(
    all_predictions: List[Tuple[np.ndarray, np.ndarray]],
    all_ground_truths: List[np.ndarray],
    iou_threshold: float = 0.5,
) -> dict:
    """Compute mAP@0.5 from predictions and ground truths."""
    all_tp = []
    all_conf = []
    total_gt = 0

    for (pred_boxes, pred_scores), gt_boxes in zip(all_predictions, all_ground_truths):
        total_gt += len(gt_boxes)

        if len(pred_boxes) == 0:
            continue

        # Sort predictions by confidence
        order = np.argsort(-pred_scores)
        pred_boxes = pred_boxes[order]
        pred_scores = pred_scores[order]

        gt_matched = np.zeros(len(gt_boxes), dtype=bool)

        for pi in range(len(pred_boxes)):
            best_iou = 0
            best_gi = -1

            for gi in range(len(gt_boxes)):
                if gt_matched[gi]:
                    continue
                iou = _compute_iou(pred_boxes[pi], gt_boxes[gi])
                if iou > best_iou:
                    best_iou = iou
                    best_gi = gi

            if best_iou >= iou_threshold and best_gi >= 0:
                all_tp.append(1)
                gt_matched[best_gi] = True
            else:
                all_tp.append(0)

            all_conf.append(pred_scores[pi])

    if total_gt == 0:
        return {"mAP50": 0, "precision": 0, "recall": 0, "f1": 0, "total_gt": 0}

    # Sort by confidence
    all_tp = np.array(all_tp)
    all_conf = np.array(all_conf)
    order = np.argsort(-all_conf)
    all_tp = all_tp[order]

    # Cumulative TP and FP
    cum_tp = np.cumsum(all_tp)
    cum_fp = np.cumsum(1 - all_tp)

    recalls = cum_tp / total_gt
    precisions = cum_tp / (cum_tp + cum_fp)

    # AP using all-point interpolation
    mrec = np.concatenate(([0.0], recalls, [1.0]))
    mpre = np.concatenate(([1.0], precisions, [0.0]))

    for i in range(len(mpre) - 2, -1, -1):
        mpre[i] = max(mpre[i], mpre[i + 1])

    # Find points where recall changes
    idx = np.where(mrec[1:] != mrec[:-1])[0] + 1
    ap = np.sum((mrec[idx] - mrec[idx - 1]) * mpre[idx])

    # Final precision/recall at optimal F1 point
    f1_scores = 2 * precisions * recalls / (precisions + recalls + 1e-8)
    best_f1_idx = np.argmax(f1_scores)

    return {
        "mAP50": round(float(ap) * 100, 1),
        "precision": round(float(precisions[best_f1_idx]) * 100, 1),
        "recall": round(float(recalls[best_f1_idx]) * 100, 1),
        "f1": round(float(f1_scores[best_f1_idx]) * 100, 1),
        "total_gt": int(total_gt),
        "total_predictions": len(all_tp),
    }


# ─── Ground Truth Loading ────────────────────────────────────────────────────

def load_ground_truths(label_path: Path, img_w: int, img_h: int) -> np.ndarray:
    """Load YOLO labels as xyxy pixel coordinates."""
    boxes = []
    if not label_path.exists():
        return np.empty((0, 4))
    for line in label_path.read_text().strip().split("\n"):
        if not line.strip():
            continue
        parts = line.strip().split()
        if len(parts) >= 5:
            cx, cy, w, h = float(parts[1]), float(parts[2]), float(parts[3]), float(parts[4])
            x1 = (cx - w / 2) * img_w
            y1 = (cy - h / 2) * img_h
            x2 = (cx + w / 2) * img_w
            y2 = (cy + h / 2) * img_h
            boxes.append([x1, y1, x2, y2])
    return np.array(boxes) if boxes else np.empty((0, 4))


# ─── Main ────────────────────────────────────────────────────────────────────

def main():
    args = parse_args()

    from ultralytics import YOLO
    import yaml

    # Load data config
    with open(args.data) as f:
        data_cfg = yaml.safe_load(f)

    data_root = args.data.parent
    split_dir = data_cfg.get(args.split, f"{args.split}/images")
    img_dir = data_root / split_dir
    label_dir = img_dir.parent.parent / img_dir.parent.name.replace("images", "labels") / "" \
        if "images" in str(img_dir) else img_dir

    # Fix label path
    label_dir = Path(str(img_dir).replace("images", "labels"))

    image_files = sorted(img_dir.glob("*.*"))
    image_files = [f for f in image_files if f.suffix.lower() in (".jpg", ".jpeg", ".png", ".bmp")]
    if args.limit > 0:
        image_files = image_files[:args.limit]

    print("=" * 70)
    print("  ENSEMBLE EVALUATION — Maximum mAP Mode")
    print("=" * 70)
    print(f"  Model A: {args.model_a.name} ({args.model_a.parent.parent.name})")
    if args.model_b and args.model_b.exists():
        print(f"  Model B: {args.model_b.name} ({args.model_b.parent.parent.name})")
    print(f"  Split: {args.split} ({len(image_files)} images)")
    print(f"  Methods: standard + {'TTA + ' if not args.no_tta else ''}{'tiles + ' if not args.no_tiles else ''}WBF")
    print(f"  ImgSz: {args.imgsz} | Tile: {args.tile_size} | Conf: {args.conf}")
    print("=" * 70)

    # Load models
    model_a = YOLO(str(args.model_a))
    model_b = None
    if args.model_b and args.model_b.exists():
        model_b = YOLO(str(args.model_b))

    # --- Run evaluation ---
    all_predictions_single = []
    all_predictions_ensemble = []
    all_ground_truths = []

    start_time = time.time()

    for i, img_path in enumerate(image_files):
        if (i + 1) % 100 == 0:
            elapsed = time.time() - start_time
            eta = elapsed / (i + 1) * (len(image_files) - i - 1)
            print(f"  [{i+1}/{len(image_files)}] elapsed: {elapsed:.0f}s, ETA: {eta:.0f}s")

        img = Image.open(img_path)
        img_w, img_h = img.size

        # Load ground truth
        label_path = label_dir / (img_path.stem + ".txt")
        gt_boxes = load_ground_truths(label_path, img_w, img_h)
        all_ground_truths.append(gt_boxes)

        # --- Collect predictions from all sources ---
        source_boxes = []
        source_scores = []
        source_weights = []

        # 1. Model A @ primary resolution (standard)
        boxes, scores = predict_standard(model_a, str(img_path), args.imgsz, args.conf)
        source_boxes.append(boxes)
        source_scores.append(scores)
        source_weights.append(1.0)

        # Save single-model prediction for comparison
        all_predictions_single.append((boxes.copy(), scores.copy()))

        # 2. Model A @ 640 (different scale)
        if args.imgsz != 640:
            boxes2, scores2 = predict_standard(model_a, str(img_path), 640, args.conf)
            source_boxes.append(boxes2)
            source_scores.append(scores2)
            source_weights.append(0.8)

        # 3. Model A with TTA
        if not args.no_tta:
            boxes_tta, scores_tta = predict_tta(model_a, str(img_path), args.imgsz, args.conf)
            source_boxes.append(boxes_tta)
            source_scores.append(scores_tta)
            source_weights.append(0.9)

        # 4. Tiled inference
        if not args.no_tiles:
            boxes_tile, scores_tile = predict_tiled(
                model_a, str(img_path), args.tile_size, args.tile_overlap, args.conf
            )
            source_boxes.append(boxes_tile)
            source_scores.append(scores_tile)
            source_weights.append(1.0)

        # 5. Model B (if available)
        if model_b is not None:
            boxes_b, scores_b = predict_standard(model_b, str(img_path), args.imgsz, args.conf)
            source_boxes.append(boxes_b)
            source_scores.append(scores_b)
            source_weights.append(1.2)  # Higher weight for bigger model

            if not args.no_tta:
                boxes_b_tta, scores_b_tta = predict_tta(model_b, str(img_path), args.imgsz, args.conf)
                source_boxes.append(boxes_b_tta)
                source_scores.append(scores_b_tta)
                source_weights.append(1.0)

        # --- Merge with WBF ---
        # Normalize all boxes to [0,1]
        norm_boxes = []
        norm_scores = []
        for b, s in zip(source_boxes, source_scores):
            if len(b) > 0:
                nb = b.copy()
                nb[:, [0, 2]] = np.clip(nb[:, [0, 2]] / img_w, 0, 1)
                nb[:, [1, 3]] = np.clip(nb[:, [1, 3]] / img_h, 0, 1)
                norm_boxes.append(nb)
                norm_scores.append(s)
            else:
                norm_boxes.append(np.empty((0, 4)))
                norm_scores.append(np.empty((0,)))

        fused_boxes, fused_scores = weighted_boxes_fusion(
            norm_boxes, norm_scores, source_weights,
            iou_thr=args.wbf_iou, conf_thr=args.wbf_conf
        )

        # Denormalize
        if len(fused_boxes) > 0:
            fused_boxes[:, [0, 2]] *= img_w
            fused_boxes[:, [1, 3]] *= img_h

        all_predictions_ensemble.append((fused_boxes, fused_scores))

    elapsed_total = time.time() - start_time

    # --- Compute mAP ---
    print(f"\n{'─'*70}")
    print("  COMPUTING mAP...")

    map_single = compute_map(all_predictions_single, all_ground_truths, iou_threshold=0.5)
    map_ensemble = compute_map(all_predictions_ensemble, all_ground_truths, iou_threshold=0.5)

    print(f"\n{'='*70}")
    print(f"  RESULTS")
    print(f"{'='*70}")
    print(f"")
    print(f"  SINGLE MODEL (Model A @ {args.imgsz}):")
    print(f"    mAP@0.5:   {map_single['mAP50']}%")
    print(f"    Precision:  {map_single['precision']}%")
    print(f"    Recall:     {map_single['recall']}%")
    print(f"    F1:         {map_single['f1']}%")
    print(f"")
    print(f"  ENSEMBLE (all methods + WBF):")
    print(f"    mAP@0.5:   {map_ensemble['mAP50']}%")
    print(f"    Precision:  {map_ensemble['precision']}%")
    print(f"    Recall:     {map_ensemble['recall']}%")
    print(f"    F1:         {map_ensemble['f1']}%")
    print(f"")
    gain = map_ensemble['mAP50'] - map_single['mAP50']
    print(f"  ENSEMBLE GAIN: +{gain:.1f}pp mAP@0.5")
    print(f"  Time: {elapsed_total:.0f}s ({elapsed_total/len(image_files):.2f}s/image)")
    print(f"{'='*70}")

    # Save report
    report = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "config": {
            "model_a": str(args.model_a),
            "model_b": str(args.model_b) if args.model_b else None,
            "split": args.split,
            "images": len(image_files),
            "imgsz": args.imgsz,
            "tile_size": args.tile_size,
            "conf": args.conf,
            "wbf_iou": args.wbf_iou,
            "wbf_conf": args.wbf_conf,
            "tta_enabled": not args.no_tta,
            "tiles_enabled": not args.no_tiles,
        },
        "single_model": map_single,
        "ensemble": map_ensemble,
        "gain_pp": round(gain, 1),
        "elapsed_seconds": round(elapsed_total, 1),
    }

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"\n  Report: {args.out}")


if __name__ == "__main__":
    main()
