# MEALYBUG V15 Training Log

**Config:** YOLO26s | 1280px | AdamW | batch=16 | 2× RTX 5090  
**Dataset:** 13,664 train (DINO-fixed: +17,277 boxes) | val/test: 1,952 images (legacy labels)  
**Run name:** `mealybug_v15_full`  
**Started:** 2026-05-26 ~19:38 UTC+8  
**Completed:** 200/200 epochs | **Total time:** ~6.6 h (23,744 s)

---

## What Changed from V14

### Problem Identified
GroundingDINO audit on 3,027-image sample showed **49% under-annotated** training images. V14 pseudo-labeling made this worse (+11,186 biased boxes).

### Annotation Fix Applied (before training)

| Metric | Count |
|--------|-------|
| Images scanned | 12,951 |
| Images fixed | 3,052 |
| New label files created (GT=0) | 1,585 |
| **Total boxes added** | **17,277** |
| Skipped (already good) | 8,314 |

**Tool:** `scripts/fix_annotations_with_dino.py`  
**Prompt:** `mealybug . white insect . pest on leaf`  
**Strategy:** merge, IoU 0.4, box_thresh 0.30, text_thresh 0.25

### Hyperparameters (V14 → V15)

| Parameter | V14 | V15 |
|-----------|-----|-----|
| Start weights | v13afix best.pt | **yolo26s.pt (COCO)** |
| lr0 | 0.0001 | **0.001** |
| freeze | 10 epochs | **0** |
| box | 10.0 | **7.5** |
| close_mosaic | 30 | **20** |
| copy_paste | 0.3 | **0** |
| scale | 0.9 | **0.5** |
| patience | 50 | **30** |
| epochs | 200 | 200 |
| imgsz | 1280 | 1280 |
| batch | 32 | 16 |

---

## Training Command (Vast)

```bash
yolo detect train \
  model=yolo26s.pt \
  data=/workspace/data_v15.yaml \
  epochs=200 imgsz=1280 batch=16 \
  optimizer=AdamW lr0=0.001 lrf=0.01 cos_lr=True \
  warmup_epochs=3 patience=30 \
  iou=0.45 box=7.5 close_mosaic=20 \
  dropout=0.1 weight_decay=0.0005 \
  project=/workspace/runs/train name=mealybug_v15_full \
  device=0,1
```

---

## Validation Metrics During Training (val split)

Best validation **mAP@0.5** during training: **57.9%** (epoch 156).  
Training ran all **200 epochs** (no early stop).

| Epoch | Time (s) | Box | Cls | P (%) | R (%) | mAP@50 (%) | mAP@50-95 (%) |
|-------|----------|-----|-----|-------|-------|------------|----------------|
| 1 | 135 | 1.979 | 5.870 | 16.9 | 19.7 | 8.8 | 3.2 |
| 10 | 1195 | 1.712 | 4.040 | 40.0 | 38.8 | 28.7 | 11.7 |
| 20 | 2390 | 1.658 | 3.652 | 47.5 | 43.0 | 35.8 | 15.2 |
| 30 | 3596 | 1.609 | 3.424 | 53.1 | 48.7 | 42.7 | 18.4 |
| 40 | 4780 | 1.602 | 3.168 | 56.2 | 51.1 | 45.4 | 19.6 |
| 50 | 5969 | 1.555 | 3.017 | 59.2 | 52.8 | 48.1 | 21.0 |
| 60 | 7156 | 1.535 | 2.871 | 60.4 | 55.1 | 49.9 | 22.0 |
| 70 | 8355 | 1.510 | 2.723 | 60.9 | 56.4 | 51.0 | 22.6 |
| 80 | 9520 | 1.486 | 2.606 | 61.7 | 57.0 | 51.9 | 23.2 |
| 90 | 10677 | 1.462 | 2.527 | 62.5 | 57.6 | 52.5 | 23.6 |
| 100 | 11876 | 1.439 | 2.424 | 63.0 | 58.0 | 53.1 | 23.9 |
| 110 | 13076 | 1.418 | 2.336 | 62.8 | 58.8 | 53.7 | 24.3 |
| 120 | 14271 | 1.406 | 2.270 | 63.2 | 59.4 | 54.2 | 24.5 |
| 130 | 15452 | 1.374 | 2.220 | 63.9 | 59.8 | 54.7 | 24.9 |
| 140 | 16639 | 1.344 | 2.127 | 64.3 | 60.2 | 55.1 | 25.1 |
| 150 | 17822 | 1.355 | 2.135 | 64.9 | 60.4 | 55.5 | 25.3 |
| **156** | 18528 | 1.355 | 2.085 | 64.9 | 60.5 | **57.9** | 25.5 |
| 160 | 18998 | 1.341 | 2.050 | 65.0 | 60.6 | 56.0 | 25.6 |
| 170 | 20179 | 1.321 | 2.048 | 64.8 | 61.5 | 56.4 | 25.8 |
| 180 | 21378 | 1.329 | 2.041 | 64.8 | 61.7 | 56.5 | 26.0 |
| 190 | 22560 | 1.365 | 1.780 | 65.2 | 61.9 | 56.7 | 26.1 |
| **200** | **23744** | **1.378** | **1.735** | **65.2** | **61.9** | **56.7** | **26.1** |

*Full per-epoch log:* `runs/retrain/mealybug_v15_full/results.csv`

---

## Held-Out Test Evaluation (after training)

Eval: `yolo detect val`, imgsz=1280, conf=0.001, iou=0.6, split=test

| Test labels | mAP@0.5 | mAP@0.5:0.95 | P | R | Instances |
|-------------|---------|--------------|-----|-----|-----------|
| **Legacy** (original) | **56.7%** | **26.1%** | **65.2%** | **61.9%** | 14,124 |
| DINO-fixed test | **61.1%** | **32.1%** | **71.4%** | 60.0% | 17,378 |

**vs V14 @ same legacy test:** 37.6% → 56.7% (**+19.1 pp**)

---

## Growth Phases

| Phase | Epochs | mAP@50 (val) | Notes |
|-------|--------|--------------|-------|
| Rapid climb | 1–30 | 9% → 43% | No frozen backbone (unlike V14) |
| Steady gain | 31–100 | 43% → 53% | ~0.1 pp/epoch |
| Diminishing | 101–200 | 53% → 57% (val) | LR decay; close_mosaic @ 180 |
| Legacy test | final | **56.7%** | Matches end of training val trend |

---

## Key Outcomes

1. **+19.1 pp** over V14 on legacy test — almost entirely from DINO-fixed **train** labels.  
2. Recall **61.9%** vs V14 **46.9%** — model stops suppressing valid detections.  
3. Best weights: `runs/retrain/mealybug_v15_full/weights/best.pt`  
4. Foundation for **v16** self-training fine-tune.

---

## Files

| File | Location |
|------|----------|
| results.csv | `runs/retrain/mealybug_v15_full/results.csv` |
| best.pt | `runs/retrain/mealybug_v15_full/weights/best.pt` |
| DINO fix log | `/workspace/runs/annotation_fix/fix_log.csv` |
| Plan | `docs/training/PLAN_TO_80_PERCENT.md` |
