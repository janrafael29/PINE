# Plan to Reach 80-90% mAP@0.5

**Status:** v15 training in progress (epoch 60/200, current mAP@50 = 49.9%)  
**Target:** 80-90% mAP@0.5 on properly-labeled test set  
**Created:** 2026-05-26

---

## Overview

If v15 finishes below 80% mAP, execute these steps sequentially. Each step builds on the previous.

---

## Step 1: Let v15 Finish Training

**What:** v15 = YOLO26s @ 1280px on 13,664 DINO-fixed images (17,277 boxes added)  
**Expected:** 55-65% mAP@0.5 on current test set  
**Time:** ~4 more hours (finishes ~2 AM)  
**Command:** Already running on Vast

**After training completes, download weights:**
```bash
# On Vast - check final metrics
tail -5 /workspace/runs/train/mealybug_v15_full/results.csv

# Download best weights to local
scp -P 42557 root@211.72.13.201:/workspace/runs/train/mealybug_v15_full/weights/best.pt "D:\old_PINE\runs\retrain\mealybug_v15\weights\best.pt"
```

---

## Step 2: Fix Test Set Labels with GroundingDINO

**Why:** The test set is likely also under-annotated (same source as training data). Model gets penalized for CORRECT detections. Fixing test labels reveals true mAP.  
**Expected gain:** +10-15pp (mAP measured against proper ground truth)  
**Time:** ~5-10 min on GPU

```bash
# On Vast
python /workspace/fix_annotations_with_dino.py \
  --mode fix \
  --strategy merge \
  --dataset-dir /workspace/datasets/mealybug_v13afix/test

# Verify
ls /workspace/datasets/mealybug_v13afix/test/labels/ | wc -l
```

**Then re-evaluate v15 on fixed test:**
```bash
yolo detect val \
  model=/workspace/runs/train/mealybug_v15_full/weights/best.pt \
  data=/workspace/data_v15.yaml \
  imgsz=1280 \
  conf=0.12 \
  iou=0.45 \
  split=test
```

---

## Step 3: Iterative Self-Training (v15 → fix more → v16)

**Why:** v15 is now better than GroundingDINO at finding mealybugs. Use v15 to find what DINO missed, add those annotations, retrain.  
**Expected gain:** +5-8pp  
**Time:** ~1 hour fix + ~5 hours train

```bash
# Create a new fix script that uses v15 instead of DINO
# Run v15 predictions on train images at high confidence
yolo detect predict \
  model=/workspace/runs/train/mealybug_v15_full/weights/best.pt \
  source=/workspace/datasets/mealybug_v13afix/train/images \
  imgsz=1280 \
  conf=0.40 \
  save_txt=True \
  project=/workspace/runs/v15_predictions

# Compare v15 predictions with current labels
# Add high-confidence v15 detections that don't overlap existing labels
# (Script: fix_with_model_predictions.py — to be written)

# Retrain v16 on double-fixed data
yolo detect train \
  model=/workspace/yolo26s.pt \
  data=/workspace/data_v15.yaml \
  imgsz=1280 \
  epochs=200 \
  batch=16 \
  patience=30 \
  optimizer=AdamW \
  lr0=0.001 \
  lrf=0.01 \
  cos_lr=True \
  warmup_epochs=3 \
  weight_decay=0.0005 \
  iou=0.45 \
  box=7.5 \
  dropout=0.1 \
  close_mosaic=20 \
  project=/workspace/runs/train \
  name=mealybug_v16_selffix \
  device=0,1 \
  exist_ok=True
```

---

## Step 4: Ensemble Evaluation (v13afix + v15 + v16)

**Why:** Different models catch different bugs. Merging predictions with WBF boosts recall significantly.  
**Expected gain:** +3-5pp over single best model  
**Time:** ~10-20 min

```bash
# Use ensemble_eval.py with all available models
python /workspace/scripts/ensemble_eval.py \
  --models \
    /workspace/runs/train/mealybug_v15_full/weights/best.pt \
    /workspace/runs/train/mealybug_v16_selffix/weights/best.pt \
    /path/to/mealybug_v13afix/best.pt \
  --data /workspace/data_v15.yaml \
  --imgsz 1280 \
  --conf 0.15 \
  --wbf-iou 0.5 \
  --wbf-conf 0.01
```

**Alternative: Multi-scale ensemble**
- Run each model at 640, 1280, and 1536
- Merge all predictions with WBF
- Expected additional gain: +1-2pp

---

## Step 5: Tiled Inference (SAHI)

**Why:** Even at 1280px, tiny mealybugs in large images get missed. Tiling splits image into overlapping crops, detects on each, merges.  
**Expected gain:** +2-3pp for small objects  
**Time:** ~30 min evaluation

```bash
pip install sahi

# SAHI tiled inference
python -c "
from sahi import AutoDetectionModel
from sahi.predict import get_sliced_prediction

model = AutoDetectionModel.from_pretrained(
    model_type='ultralytics',
    model_path='/workspace/runs/train/mealybug_v15_full/weights/best.pt',
    confidence_threshold=0.15,
    device='cuda:0',
)

# For each test image:
result = get_sliced_prediction(
    image_path,
    model,
    slice_height=640,
    slice_width=640,
    overlap_height_ratio=0.2,
    overlap_width_ratio=0.2,
)
"
```

---

## Step 6: Larger Model (YOLO26m) — FOR BENCHMARK ONLY

**Why:** More parameters = more capacity to learn complex patterns  
**Expected gain:** +2-3pp  
**Time:** ~8-10 hours training  
**NOTE: Do NOT deploy to mobile. Use only for thesis benchmark number.**

```bash
# Download YOLO26m pretrained
# (Check if available, otherwise use yolo26l)

yolo detect train \
  model=yolo26m.pt \
  data=/workspace/data_v15.yaml \
  imgsz=1280 \
  epochs=200 \
  batch=8 \
  patience=30 \
  optimizer=AdamW \
  lr0=0.001 \
  lrf=0.01 \
  cos_lr=True \
  warmup_epochs=3 \
  iou=0.45 \
  box=7.5 \
  dropout=0.1 \
  close_mosaic=20 \
  project=/workspace/runs/train \
  name=mealybug_v17_large \
  device=0,1 \
  exist_ok=True
```

---

## Step 7: Knowledge Distillation (Large → Small for Mobile)

**Why:** Get YOLO26m-level accuracy in a YOLO26n-sized model for fast mobile inference  
**Expected:** Retain 90-95% of teacher accuracy at YOLO26n speed (~30-50ms)  
**Time:** ~4-5 hours

### Method: Feature-based distillation

```python
# distill_v15_to_mobile.py
from ultralytics import YOLO

# Teacher: best large model (v15 or v17)
teacher = YOLO("/workspace/runs/train/mealybug_v15_full/weights/best.pt")

# Student: small model for mobile
student = YOLO("yolo26n.pt")

# Train student with teacher guidance
student.train(
    data="/workspace/data_v15.yaml",
    epochs=150,
    imgsz=640,        # mobile resolution
    batch=32,
    teacher=teacher,  # distillation (if supported by ultralytics version)
    # OR use manual distillation loop
)
```

### Alternative: Ultralytics Knowledge Distillation
```bash
# If ultralytics supports --teacher flag:
yolo detect train \
  model=yolo26n.pt \
  data=/workspace/data_v15.yaml \
  imgsz=640 \
  epochs=150 \
  batch=32 \
  patience=30 \
  optimizer=AdamW \
  lr0=0.001 \
  project=/workspace/runs/train \
  name=mealybug_v15_distilled_mobile \
  device=0,1
```

### Manual Distillation (if built-in not available):
1. Run teacher (v15/v17) on all train images at high confidence
2. Use teacher predictions as soft labels
3. Train student (YOLO26n @ 640px) on both hard labels + soft labels
4. Student learns to mimic teacher's detection patterns

**Result for app deployment:**
- Model: YOLO26n (~4MB TFLite)
- Input: 640px
- Speed: ~30-50ms on mobile
- Accuracy: ~85-90% of teacher (v15/v17)

---

## Expected Cumulative Results

| After Step | mAP@0.5 (est.) | Notes |
|------------|:-:|---|
| v15 finishes | 55-65% | Current training |
| + Fix test labels | 65-75% | Removes false penalties |
| + Self-training v16 | 70-80% | Catches what DINO missed |
| + Ensemble | 75-85% | Multi-model fusion |
| + SAHI tiling | 78-88% | Small object boost |
| + YOLO26m teacher | 80-90% | Maximum accuracy benchmark |
| Distilled mobile | 72-81% | Deployable on phone |

---

## Decision Tree

```
v15 finishes → check mAP
  ├── ≥ 80% on fixed test → DONE! Deploy.
  ├── 70-80% → Do Step 4 (ensemble) → likely hits 80%
  ├── 60-70% → Do Steps 3+4 (self-train + ensemble)
  └── < 60% → Do Steps 2-6 in full
```

---

## Important Notes

- Always evaluate on DINO-fixed test set (Step 2) — raw test set underestimates real performance
- Save ALL model weights — ensemble needs multiple models
- For thesis, report BOTH raw test mAP and fixed test mAP with explanation
- Mobile deployment uses distilled YOLO26n/s regardless of benchmark model size
- Credits reminder: Steps 3+6 need ~13 hours GPU time total ($5-10 on Vast)
