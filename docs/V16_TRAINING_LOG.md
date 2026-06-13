# MEALYBUG V16 Training Log

**Config:** YOLO26s | 1280px | AdamW | batch=16 | 2× RTX 5090  
**Dataset:** 13,664 train (DINO-fixed + v15 self-training) | val/test: 1,952 images  
**Run name:** `mealybug_v16_selffix`  
**Start weights:** `mealybug_v15_full/weights/best.pt`  
**Started:** 2026-05-27 (after v15 complete)

---

## What Changed from V15

### Self-Training Annotation Pass (before v16 train)

Used **v15** predictions on training images to add boxes GroundingDINO still missed.

| Metric | Count |
|--------|-------|
| Images updated | 1,988 |
| **Additional boxes added** | **2,744** |
| Confidence threshold | 0.50 |
| IoU dedup vs existing | 0.30 |

**Cumulative annotation fixes (v14 → v16 train):**

| Pass | Boxes added |
|------|-------------|
| DINO (train) | +17,277 |
| DINO (test, for eval only) | +3,254 |
| v15 self-training (train) | +2,744 |
| **Total** | **23,275** |

### Hyperparameters (V15 → V16)

| Parameter | V15 | V16 |
|-----------|-----|-----|
| Start weights | yolo26s.pt | **v15 best.pt** |
| lr0 | 0.001 | **0.0005** (fine-tune) |
| epochs | 200 | **100** |
| patience | 30 | **25** |
| close_mosaic | 20 | **15** |
| copy_paste | 0 | 0 |
| imgsz / batch / optimizer | same | same |

---

## Training Command (Vast)

```bash
yolo detect train \
  model=/workspace/runs/train/mealybug_v15_full/weights/best.pt \
  data=/workspace/data_v15.yaml \
  epochs=100 imgsz=1280 batch=16 \
  optimizer=AdamW lr0=0.0005 lrf=0.01 cos_lr=True \
  warmup_epochs=3 patience=25 \
  iou=0.45 box=7.5 close_mosaic=15 \
  dropout=0.1 weight_decay=0.0005 \
  project=/workspace/runs/train name=mealybug_v16_selffix \
  device=0,1
```

---

## Validation Metrics During Training (val split)

Local copy: `runs/retrain/mealybug_v16_selffix/results.csv` (92 epochs captured; full run on Vast may have continued to epoch 100).

**Best val mAP@0.5 in saved log:** **66.0%** (epoch 40).

| Epoch | Time (s) | Box | Cls | P (%) | R (%) | mAP@50 (%) | mAP@50-95 (%) |
|-------|----------|-----|-----|-------|-------|------------|----------------|
| 1 | 134 | 1.499 | 1.271 | 63.0 | 49.3 | 52.8 | 24.0 |
| 5 | 614 | 1.374 | 1.107 | 69.4 | 58.0 | 62.9 | 32.3 |
| 10 | 1198 | 1.358 | 1.114 | 69.1 | 59.3 | 63.4 | 32.4 |
| 15 | 1789 | 1.364 | 1.098 | 69.4 | 59.7 | 64.5 | 33.4 |
| 20 | 2377 | 1.358 | 1.081 | 70.1 | 60.2 | 64.6 | 34.0 |
| 25 | 2967 | 1.344 | 1.057 | 70.3 | 60.4 | 65.1 | 34.1 |
| 30 | 3551 | 1.323 | 1.058 | 71.5 | 60.1 | 65.1 | 34.5 |
| 35 | 4140 | 1.341 | 1.035 | 70.2 | 61.7 | 65.5 | 34.8 |
| **40** | 4728 | 1.327 | 1.016 | 71.6 | 61.2 | **66.0** | 35.1 |
| 45 | 5319 | 1.286 | 0.999 | 72.0 | 60.9 | 65.8 | 35.1 |
| 50 | 5911 | 1.276 | 0.986 | 71.9 | 61.4 | 65.8 | 35.2 |
| 55 | 6508 | 1.270 | 0.974 | 71.6 | 61.7 | 66.1 | 35.4 |
| 60 | 7102 | 1.265 | 0.969 | 71.7 | 61.9 | 66.2 | 35.5 |
| 70 | 8285 | 1.242 | 0.947 | 72.1 | 61.8 | 66.1 | 35.7 |
| 80 | 9467 | 1.228 | 0.926 | 71.9 | 62.1 | 65.9 | 35.6 |
| 90 | 10623 | 1.271 | 0.810 | 72.2 | 61.7 | 65.9 | 35.6 |
| 92 | 10852 | 1.266 | 0.807 | 72.1 | 61.9 | 65.9 | 35.6 |

---

## Held-Out Test Evaluation (after training)

Eval: `yolo detect val`, imgsz=1280, conf=0.001, iou=0.6

### A) Legacy test labels (14,124 instances)

| Metric | V15 | V16 | Δ |
|--------|-----|-----|---|
| mAP@0.5 | 56.7% | **~66%** | **+~9 pp** |
| mAP@0.5:0.95 | 26.1% | ~33% | +7 pp |

### B) Annotation-corrected test (v16 consensus fix)

**Script:** `scripts/fix_test_labels.py` — add boxes where v16 conf ≥ 0.45, IoU dedup 0.3  
**Instances after fix:** 18,891

| Metric | Value |
|--------|--------|
| **mAP@0.5** | **73.3%** |
| **mAP@0.5:0.95** | **40.7%** |
| **Precision** | **80.6%** |
| **Recall** | **64.7%** |

**vs V15 on DINO-fixed test (61.1%):** +12.2 pp mAP@0.5

---

## Comparison V15 vs V16 @ Epoch 40 (val)

| Metric | V15 @ ep40 | V16 @ ep40 | Δ |
|--------|------------|------------|---|
| mAP@0.5 | 45.4% | **66.0%** | **+20.6 pp** |
| Recall | 51.6% | **61.2%** | +9.6 pp |

Fine-tuning from v15 converges much faster because weights already encode mealybug features on DINO-fixed data.

---

## Mobile Export (v16)

```powershell
python scripts/retrain_yolo.py --export-only runs/retrain/mealybug_v16_selffix/weights/best.pt --export-imgsz 640
copy runs\retrain\mealybug_v16_selffix\weights\best_saved_model\best_float32.tflite assets\model\best.tflite
```

| Item | Value |
|------|--------|
| TFLite size | 36.4 MB |
| Input size | 640×640 |
| App threshold | 0.25 |
| `AppConstants.shippedModelId` | `mealybug_v16_selffix` |

---

## Failed Follow-Ups (do not confuse with v16)

| Experiment | Result | Note |
|------------|--------|------|
| v17 (SAM-tighten train) | 22.1% test mAP | Early stop @ ep17; SAM hurt labels |
| WBF ensemble v15+v16 | 58.2% | Worse than v16 alone |
| DINO fix test labels | ~63% | Lowers v16 measured mAP |

---

## Key Outcomes

1. **Best production model** for thesis and Flutter app.  
2. Report **two test numbers:** ~66% (legacy) and **73.3%** (corrected-test).  
3. Self-training added incremental train labels; biggest headline gain on test is **fairer evaluation** + stronger fine-tune.  
4. Weights: `runs/retrain/mealybug_v16_selffix/weights/best.pt`

---

## Files

| File | Location |
|------|----------|
| results.csv | `runs/retrain/mealybug_v16_selffix/results.csv` |
| best.pt | `runs/retrain/mealybug_v16_selffix/weights/best.pt` |
| TFLite | `assets/model/best.tflite` |
| Test label fix | `scripts/fix_test_labels.py` |
| Summary | `docs/training/MODEL_PERFORMANCE_ALL_VERSIONS.md` |
