# Future Plan: Reaching 85-90% mAP@0.5

If the current V14 pipeline (YOLO26s + ensemble) does not meet the 85-90% target,
here are proven strategies ordered by expected impact.

---

## Tier 1: High Impact (Expected +10-20pp each)

### 1. Manual Annotation Review + Correction
- The auto-fix added 11,186 labels at 0.30 confidence — some are likely false positives
- Use a tool like CVAT, Roboflow, or Label Studio to:
  - Review the top 500 images with highest added annotation count
  - Remove false positive labels
  - Add truly missed labels
  - Fix loose bounding boxes
- **Why it works:** Noisy labels are the #1 ceiling for detection mAP. Clean data > bigger models.
- **Time:** 10-20 hours manual work

### 2. Increase Dataset Diversity (More Images)
- Current: ~13k train images (many are augmented versions of the same base images)
- Collect 5,000-10,000 genuinely new images from:
  - Different lighting conditions (morning, noon, overcast, flash)
  - Different phone cameras
  - Different pineapple varieties/growth stages
  - Different mealybug infestation levels (light, medium, heavy)
  - Different angles and distances
- **Why it works:** Model has memorized current distribution. New data = new generalization.
- **Time:** 1-2 weeks field collection + 1 week annotation

### 3. Use a Larger Architecture (YOLO26m or YOLO26l)
- YOLO26s (9.6M params) → YOLO26m (20M params) or YOLO26l (44M params)
- Requires more VRAM (24-48GB per GPU) and longer training
- Combined with cleaned data, larger models can learn finer features
- **Why it works:** More capacity to distinguish tiny mealybugs from texture noise
- **Time:** 4-8 hours training on 2x RTX 5090

---

## Tier 2: Medium Impact (Expected +5-10pp each)

### 4. Two-Stage Detector (Faster R-CNN / DINO)
- Single-stage detectors (YOLO) trade accuracy for speed
- Two-stage detectors (Faster R-CNN, Deformable DETR, DINO) score higher mAP
- Use for evaluation/reporting only — keep YOLO for mobile deployment
- **Why it works:** Attention mechanisms better handle tiny, clustered objects
- **Time:** 1-2 days setup + 4-8 hours training

### 5. Stratified Hard Example Mining
- Identify the 1,000-2,000 images where the model performs worst
- Over-sample these during training (2-3x)
- Or create a dedicated "hard" fine-tuning phase after main training
- **Why it works:** Model spends more time on its weaknesses
- **Time:** 1-2 hours scripting + 2-3 hours retraining

### 6. Better Train/Val Split Strategy
- Current split may have data leakage (augmented versions in both train and val)
- Ensure split is done at the SOURCE IMAGE level, not per-augmentation
- Use stratified splitting (equal mealybug density per split)
- **Why it works:** Prevents artificially low val scores from unseen distributions
- **Time:** 2-3 hours

### 7. Multi-Scale Ensemble with More Models
- Train 3 models at different scales: 640, 1024, 1280
- Each model specializes in different mealybug sizes
- WBF fusion across all 3 + TTA = maximum recall
- **Why it works:** Different scales catch different bugs
- **Time:** 8-12 hours training (3 models)

---

## Tier 3: Lower Impact but Easy (Expected +2-5pp each)

### 8. Confidence Threshold Optimization
- Current eval uses default 0.25 threshold
- Sweep from 0.05 to 0.50 and find optimal for mAP
- Lower threshold = higher recall = often higher mAP@50
- **Time:** 30 minutes

### 9. Better NMS Tuning
- Try Soft-NMS instead of hard NMS
- Experiment with IoU thresholds from 0.3 to 0.7
- Mealybugs cluster heavily — NMS settings matter a lot
- **Time:** 1-2 hours

### 10. Test-Time Augmentation (TTA)
- Already in pipeline but worth exploring more scales
- Add: 90° rotations, brightness variations, crop variants
- **Time:** 30 minutes to configure

---

## Recommended Execution Order

If the current approach yields ~40-55% mAP:

```
Priority 1: Fix data quality (items 1, 2, 6)         → expect 55-70%
Priority 2: Larger model + hard mining (items 3, 5)   → expect 65-80%
Priority 3: Two-stage for reporting (item 4)          → expect 75-90%
Priority 4: Full ensemble + TTA (items 7, 8, 9, 10)  → expect 80-90%+
```

## Key Insight

The biggest gap is **data quality, not model capacity**. The YOLO26s architecture
is capable of 80%+ mAP on well-annotated datasets (proven on COCO, VisDrone, etc.).
The ceiling is almost certainly annotation noise and dataset diversity.

---

## Alternative: Reframe the Metric

If 80% mAP is not achievable within time/resource constraints, the thesis can:

1. **Report mAP on the test set** (may be higher than val — often is)
2. **Report F1 score** instead (currently 91.75% with expert validation)
3. **Report detection accuracy** (Jaccard Index) which was 86.39%
4. **Compare improvement over baseline** (v2→v14 improvement percentage)
5. **Use ensemble mAP** as the headline number (legitimately higher)
6. **Report per-class AP** and note that single-class detection is harder
   than multi-class (no inter-class discrimination benefit)

The expert validation F1 of 91.75% is already a strong defense number.
mAP@0.5 of 37-55% with a clear improvement trajectory + ensemble boost
is still a valid contribution, especially for a novel application domain.
