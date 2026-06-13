# Thesis Find & Replace

Open Word → `Ctrl+H` (Find and Replace). Copy each **FIND** exactly. Paste **REPLACE WITH**.

**Skip** any row marked *(keep as-is)* or *(add after — don't replace)*.

---

## Model: YOLO26n → YOLO26s (final / deployed model only)

Do **NOT** replace YOLO26n in Table 3, Table 4, Figure 26, or §4.1.1 "intermediate YOLO26n".

| FIND | REPLACE WITH |
|------|----------------|
| `YOLO26n TensorFlow Lite model with preprocessing` | `YOLO26s TensorFlow Lite model (mealybug_v16_selffix) with preprocessing` |
| `integrates a YOLO26n-based object detection model` | `integrates a YOLO26s-based object detection model (mealybug_v16_selffix)` |
| `YOLO26n-based model with geotagging` | `YOLO26s-based model (mealybug_v16_selffix) with geotagging` |
| `bundled YOLO26n TensorFlow Lite detector` | `bundled YOLO26s TensorFlow Lite detector (mealybug_v16_selffix)` |
| `A YOLO26n TensorFlow Lite detector configured for mealybug detection` | `A YOLO26s TensorFlow Lite detector (mealybug_v16_selffix) configured for mealybug detection` |
| `integrated with a bundled TensorFlow Lite detector from the YOLO26n` | `integrated with a bundled TensorFlow Lite detector exported from mealybug_v16_selffix (YOLO26s)` |
| `Ultralytics YOLO26n) – The final deployed model is based on Ultralytics YOLO26n` | `Ultralytics YOLO26s) – The final deployed model is mealybug_v16_selffix, based on Ultralytics YOLO26s` |
| `deployed mobile application uses the YOLO26n model optimized` | `deployed mobile application uses mealybug_v16_selffix (YOLO26s), optimized` |
| `bundled mealybug_v16_selffix TensorFlow Lite detector (YOLO26n architecture` | `bundled mealybug_v16_selffix TensorFlow Lite detector (YOLO26s architecture` |
| `The integration of a YOLO26n TensorFlow Lite detector enables` | `The integration of a YOLO26s TensorFlow Lite detector (mealybug_v16_selffix) enables` |
| `lightweight YOLO26n TensorFlow Lite model with integrated` | `YOLO26s TensorFlow Lite model (mealybug_v16_selffix) with integrated` |
| `Extend the deployed YOLO26n detector to identify` | `Extend the deployed YOLO26s detector (mealybug_v16_selffix) to identify` |
| `fine-tune the deployed YOLO26n model` | `fine-tune mealybug_v16_selffix (prior revision runs v20–v22 did not beat v16)` |
| `adapt the YOLO26n detector for other crops` | `adapt the YOLO26s-based detector for other crops` |
| `AI model (YOLO26n) running directly on your device` | `AI model (YOLO26s, mealybug_v16_selffix) running directly on your device` |
| `YOLO26n` *(Glossary only — last entry)* | `YOLO26s (mealybug_v16_selffix). Earlier development used YOLO26n (see Table 4).` |
| `selection of a lightweight YOLO26n model in this study` | `selection of YOLO26s for the final checkpoint (mealybug_v16_selffix); YOLO26n was used in earlier development runs` |

---

## Threshold: 0.30 → 0.25

| FIND | REPLACE WITH |
|------|----------------|
| `operational 30% confidence threshold` | `operational 25% confidence threshold (manual-check hints at 12–24%)` |
| `inference confidence threshold was set to 0.30` | `confirmed detection threshold was set to 0.25 (manual-check hints at 0.12–0.24)` |
| `A confidence threshold of 0.30—set only 0.05 above` | `A confirmed threshold of 0.25—set for recall-friendly scouting` |
| `detections below 30% are suppressed before display` | `detections below 25% are not counted or saved; 12–24% appear as manual-check hints only` |
| `confidence-filtered at 0.30 (30%)` | `confidence-filtered at 0.25 (25%) for confirmed detections; 0.12–0.24 shown as manual-check hints` |
| `deploy threshold is 0.30 (30%)` | `confirmed deploy threshold is 0.25 (25%); manual-check band 0.12–0.24` |
| `operation near the 30% cutoff` | `operation near the 25% confirmed cutoff` |
| `at the 30% app threshold, not benchmark mAP` | `at the 25% confirmed threshold (manual-check band 0.12–0.24 not counted), not benchmark mAP` |
| `91.75% F1, 99.58% precision, and 85.64% recall at the operational 30% confidence threshold` | `91.75% F1, 99.58% precision, and 85.64% recall at the operational 30% confidence threshold on 21 expert-reviewed field images (current app uses 25% confirmed; not equivalent to benchmark mAP)` |
| `detection is shown and counted only when its confidence is 30% or higher` | `confirmed detections require confidence ≥ 25%; 12–24% may appear as dashed manual-check hints (not counted)` |
| `Scores below 30% are filtered out before display and saving` | `Scores below 12% are hidden; 12–24% are manual-check hints only; ≥ 25% are confirmed and saved` |
| `Expert validation at app deploy threshold 0.30` | `Expert validation at app deploy threshold 0.30 (current release v17.0.0 uses 0.25 confirmed; re-validation at 0.25 not yet done)` |

---

## Training & dataset (Ch III)

| FIND | REPLACE WITH |
|------|----------------|
| `The final deployed model is based on Ultralytics YOLO26n (Nano variant)` | `The final deployed model is mealybug_v16_selffix (YOLO26s), trained at 1280 px and exported to TFLite at 640 px` |
| `default configuration uses yolo26n.pt` | `final checkpoint fine-tuned from v15 best.pt (YOLO26s); early runs used yolo26n.pt` |
| `input size 640×640, batch size 1` *(in §3.3.2.1.3 if describing FINAL model)* | `final v16 training: input size 1280×1280; TFLite export at 640×640; early runs used 640×640` |

**ADD AFTER** (don't use Find/Replace — insert new paragraph after §3.3.2.1.2):

> The final canonical dataset (mealybug_v13afix) contains 19,520 images (13,664 train, 3,904 validation, 1,952 test; 70/20/10 split, seed 42). The shipped detector (mealybug_v16_selffix) was trained in Python using Ultralytics YOLO and PyTorch on cloud GPUs. Training followed: GroundingDINO label correction (+17,277 boxes) → v15 (YOLO26s, 1280 px, 200 epochs) → self-training (+2,744 boxes) → v16 fine-tune (100 epochs, lr0=0.0005). TensorFlow was used only for TFLite export (PyTorch .pt → ONNX → TensorFlow → TFLite), not for training.

---

## §4.1.2 — extend v19 sentence

| FIND | REPLACE WITH |
|------|----------------|
| `A follow-up fine-tune (mealybug_v19_retry, initialized from v16) reached 61.9% mAP@0.5 on the corrected test versus 73.3% for v16; v16 remained the deployed model.` | `A follow-up fine-tune (mealybug_v19_retry) reached 61.9% mAP@0.5 on the corrected test versus 73.3% for v16. Subsequent revision runs also failed to beat v16: v20s (61.6%), v20m (63.5%), v21 (64.6%), v21m (62.2%), v22 (64.3%) — see Section 4.1.7. v16 remained the deployed model (app v17.0.0).` |

---

## Abstract — add at end (before Keywords)

**FIND:** `contributing to enhanced agricultural practices in low-connectivity environments.`

**REPLACE WITH:**

`contributing to enhanced agricultural practices in low-connectivity environments. Post-panel revision training (v20–v22, June 2026) did not exceed v16 on the held-out corrected test; v16 remains the deployed model.`

---

## §4.4 Summary — add at end

**FIND:** `particularly in environments with limited connectivity.`

**REPLACE WITH:**

`particularly in environments with limited connectivity. A full post-panel revision cycle (v20–v22) did not surpass v16 on corrected-test metrics; panel targets (≥85% mAP@0.5, ≥80% recall) were not met.`

---

## §5.0 Conclusion — add after v16 metrics paragraph

**FIND:** `compared to earlier validation metrics.`

**REPLACE WITH:**

`compared to earlier validation metrics. The system is a promising prototype but not deployment-ready by panel benchmarks: recall (64.7%) and mAP@0.5:0.95 (40.7%) remain below recommended thresholds. Revision training (v20–v22) did not improve held-out performance beyond v16.`

---

## §5.1.2 — retrain recommendation

| FIND | REPLACE WITH |
|------|----------------|
| `Model Retraining with Field Data: Use the real-world detections and verified labels gathered during field deployment to fine-tune the deployed YOLO26n model, potentially improving confidence scores and reducing false negatives.` | `Model improvement: Collect ≥2,500 new hard-case field images; conduct expert re-validation at the 25% deploy threshold. Prior automated relabeling and retraining (v21/v22) regressed on held-out metrics—further GPU retrains without new field data are not recommended.` |

*(Fix YOLO26n in FIND above if you already ran Section A.)*

---

## NEW SECTION — paste after §4.1.2 (not find/replace)

**Title:** `4.1.7 Post-Panel Model Revision Cycle (June 2026)`

**Paste:**

Following panel feedback, a revision cycle was executed on an H100 GPU: label audit (mealybug_v20), six-model consensus labeling (+12,182 adds, +34,218 tightens, −7,357 removes), and retraining (v20s, v20m, v21, v21m, v22). All models were evaluated on the same locked protocol as v16 (1,952 images; 18,891 instances; labels_v16_corrected; imgsz=1280; conf=0.001; IoU=0.6). None exceeded v16. Training-validation metrics during v21 (~73% mAP@0.5) were not predictive of corrected-test results.

**Table X. Revision models vs. v16 (corrected test)**

| Model | mAP@0.5 | Precision | Recall | mAP@0.5:0.95 |
|-------|--------:|----------:|-------:|-------------:|
| **v16 (deployed)** | **73.3%** | **80.6%** | **64.7%** | **40.7%** |
| v20s | 61.6% | 73.6% | 55.4% | 31.4% |
| v20m | 63.5% | 76.9% | 57.0% | 33.4% |
| v21 | 64.6% | 78.1% | 59.6% | 33.7% |
| v21m | 62.2% | 73.3% | 57.1% | 31.9% |
| v22 | 64.3% | 77.6% | 58.3% | 33.8% |
| Panel target | ≥85% | ≥80% | ≥80% | ≥55% |

---

## §4.0.4 — add advisory UX (paste after detection paragraph)

**Paste:**

For negative scans, the application displays "No mealybug detected in this image" and advises rescanning or manual inspection—it does not claim the plant is healthy. For positive scans, wording is decision-support only ("Possible mealybug detected—verify visually before control measures"), per panel guidance on advisory safeguards.

---

## DO NOT REPLACE (leave as-is)

| Text | Why |
|------|-----|
| `73.3%` / `80.6%` / `64.7%` / `40.7%` in Table 5 | Correct |
| `~66%` in Table 6 | Correct |
| Table 8 (v2–v13afix on 462 images) | Historical benchmark |
| `mAP@0.5 = 0.526` / Table 4 YOLO26n | Early development only |
| `mean SUS score of 77.0` | Valid |
| `826 detection` / `33.2%` mean confidence | Field deployment data |
| `91.75%` / `99.58%` / `85.64%` in Table 9 | Keep — add footnote via row B12 above |

---

## Quick order

1. Section **YOLO26n → YOLO26s** (skip Table 3/4/Fig 26)
2. Section **0.30 → 0.25**
3. Section **Training & dataset** (insert paragraph)
4. **§4.1.2** extend v19
5. **Paste §4.1.7** + table
6. **Abstract** + **§4.4** + **§5.0** endings
7. **§5.1.2** retrain bullet
8. **Paste §4.0.4** advisory paragraph
