# Chapter IV — Paste-ready metrics section (manual validation + model comparison)

Use this block in **Section 4.1 Model Performance Evaluation**. It separates three evaluation types examiners expect:

1. **Benchmark mAP@0.5** (labeled test set, Ultralytics)
2. **Model lineage v2 → v13afix** (same 462-image test)
3. **Manual expert validation** (VAL1–VAL3 field photos — **not mAP**)

**Do not** derive mAP from Table 3. **Do not** mix Table 2 and Table 1 mAP in one sentence without naming the split.

---

## 4.1.1 Benchmark evaluation — final deployed model (mealybug_v13afix)

The shipped application bundles **mealybug_v13afix** (YOLO26n → TensorFlow Lite @ 640×640). Benchmark metrics were computed with Ultralytics validation at **confidence 0.12**, **IoU 0.45**, **imgsz 640**. For a single-class detector, **AP@0.5 = mAP@0.5**.

**Table X — v13afix native holdout (primary headline for final model)**

| Split | Images | Precision | Recall | F1 | **mAP@0.5** | mAP@0.5:0.95 |
|-------|-------:|----------:|-------:|---:|------------:|-------------:|
| Val | 3,904 | 71.2% | 57.7% | 63.8% | 59.6% | 28.4% |
| **Test** | **1,952** | **72.8%** | **58.9%** | **65.1%** | **61.0%** | **29.2%** |

*Dataset: `mealybug_v13afix` (19,520 images, 70/20/10 resplit, seed 42). Source: `runs/calibration/mealybug_v13afix_native_eval.json`.*

**Suggested sentence:** *On the held-out native test set (1,952 images), mealybug_v13afix achieved **61.0% mAP@0.5** at IoU 0.5.*

---

## 4.1.2 Model evolution — v2 through v13afix (fixed benchmark)

To compare model generations fairly, all checkpoints below were scored on the **same** Roboflow v10 export holdout: **923 validation** and **462 test** images (`mealybug.v10-8th-yolo26n.yolo26`).

**Table Y — Model comparison on 462-image test split (conf 0.12, IoU 0.45)**

| Model | Trained on | Precision | Recall | F1 | **mAP@0.5** | mAP@0.5:0.95 |
|-------|------------|----------:|-------:|---:|------------:|-------------:|
| **v2** | Legacy ~2.3k (`datasets/`) | 41.1% | 38.6% | 39.8% | **21.1%** | 7.8% |
| **v10** | v10 (~16k aug train) | 55.7% | 49.4% | 52.4% | **42.1%** | 16.7% |
| **v11** | v10 (cleaned labels) | 56.2% | 49.2% | 52.5% | **43.0%** | 16.8% |
| **v12** | v10 @ 1024 train | 58.6% | 51.3% | 54.7% | **43.8%** | 16.9% |
| **v13afix** | v13afix pool (13,664 train) | **64.3%** | **59.7%** | **61.9%** | **56.7%** | **24.6%** |

**Headline progression (test mAP@0.5):** 21.1% → 42.1% → 43.0% → 43.8% → **56.7%** (v2 → v10 → v11 → v12 → v13afix).

**Table Y-b — Same models on 923-image validation split**

| Model | Precision | Recall | F1 | mAP@0.5 |
|-------|----------:|-------:|---:|--------:|
| v2 | 34.6% | 29.0% | 31.6% | 15.0% |
| v10 | 62.1% | 49.7% | 55.2% | 45.7% |
| v11 | 62.3% | 50.4% | 55.8% | 47.4% |
| v12 | 62.3% | 49.0% | 54.9% | 45.8% |
| **v13afix** | **62.3%** | **55.0%** | **58.4%** | **50.9%** |

**Caveat (include in Limitations or a footnote):** v13afix was trained on a reshuffled 19.5k pool; some v10 benchmark test images may appear in v13afix training. Use Table Y for **relative** improvement vs v12, and Table X for **final model** reporting.

**Suggested sentence:** *On the fixed 462-image test set, v13afix reached **56.7% mAP@0.5**, compared with **43.8%** for v12 and **21.1%** for the legacy v2 baseline.*

Sources: `runs/calibration/model_comparison_eval.json`, `accuracy_report.json`, `mealybug_v13afix_native_eval.json`. See `docs/training/MODEL_METRICS_V2_V13.md`.

---

## 4.1.3 Manual expert validation — field test photos (VAL1–VAL3)

During on-field testing (May 2026), three validators independently reviewed detection outputs on assigned image sets. For each image, experts counted **ground-truth mealybugs** (manual inspection) and compared them to **application detections** (bounding boxes from the deployed v13afix TFLite pipeline at operational thresholds). Metrics below are **per-image, single-threshold expert review** — they complement but **do not replace** mAP@0.5 in Tables X and Y.

**Method (state explicitly in Methodology or this section):**

- **TP:** detected box matched a real mealybug (expert judgment / IoU ≥ 0.5 if box matching was used)
- **FP:** detection with no corresponding mealybug
- **FN:** mealybug present but not detected
- **Precision** = TP / (TP + FP); **Recall** = TP / (TP + FN); **F1** = harmonic mean
- **Accuracy** = TP / (TP + FP + FN) for each image, then averaged across images in the set
- **Avg detection confidence:** mean of per-box confidence scores shown by the app (%)

**Table Z-a — Validator 1 (VAL1)**

| Image | Total population | TP | FP | FN | Precision | Recall | F1 | Accuracy | Avg conf. |
|------:|-----------------:|---:|---:|---:|----------:|-------:|---:|---------:|----------:|
| 1 | 10 | 6 | 0 | 4 | 100.0% | 60.0% | 75.0% | 60.0% | 51% |
| 2 | 26 | 19 | 1 | 6 | 95.0% | 76.0% | 84.4% | 73.1% | 53% |
| 3 | 9 | 8 | 0 | 1 | 100.0% | 88.9% | 94.1% | 88.9% | 58% |
| 4 | 9 | 8 | 0 | 1 | 100.0% | 88.9% | 94.1% | 88.9% | 56% |
| **Average** | — | — | — | — | **98.75%** | **78.44%** | **86.92%** | **77.71%** | **54.50%** |

**Table Z-b — Validator 2 (VAL2)**

| Image | Total population | TP | FP | FN | Precision | Recall | F1 | Accuracy | Avg conf. |
|------:|-----------------:|---:|---:|---:|----------:|-------:|---:|---------:|----------:|
| 1 | 14 | 11 | 0 | 3 | 100.0% | 78.6% | 88.0% | 78.6% | 55% |
| 2 | 12 | 11 | 0 | 1 | 100.0% | 91.7% | 95.7% | 91.7% | 47% |
| 3 | 4 | 4 | 0 | 0 | 100.0% | 100.0% | 100.0% | 100.0% | 55% |
| 4 | 3 | 3 | 0 | 0 | 100.0% | 100.0% | 100.0% | 100.0% | 74% |
| **Average** | — | — | — | — | **100.00%** | **92.56%** | **95.91%** | **92.56%** | **57.75%** |

**Table Z-c — Validator 3 (VAL3)**

| Image | Total population | TP | FP | FN | Precision | Recall | F1 | Accuracy | Avg conf. |
|------:|-----------------:|---:|---:|---:|----------:|-------:|---:|---------:|----------:|
| 1 | 14 | 12 | 0 | 2 | 100.0% | 85.7% | 92.3% | 85.7% | 65% |
| 2 | 6 | 5 | 0 | 1 | 100.0% | 83.3% | 90.9% | 83.3% | 52% |
| 3 | 9 | 8 | 0 | 1 | 100.0% | 88.9% | 94.1% | 88.9% | 74% |
| 4 | 7 | 6 | 0 | 1 | 100.0% | 85.7% | 92.3% | 85.7% | 48% |
| **Average** | — | — | — | — | **100.00%** | **85.91%** | **92.41%** | **85.91%** | **59.75%** |

**Table Z-d — Overall summary (mean of validator averages)**

| Source | Precision | Recall | F1 | Accuracy | Avg detection confidence |
|--------|----------:|-------:|---:|---------:|-------------------------:|
| VAL1 | 98.75% | 78.44% | 86.92% | 77.71% | 54.50% |
| VAL2 | 100.00% | 92.56% | 95.91% | 92.56% | 57.75% |
| VAL3 | 100.00% | 85.91% | 92.41% | 85.91% | 59.75% |
| **Grand average** | **99.58%** | **85.64%** | **91.75%** | **85.40%** | **57.33%** |

*21 images total (7 per validator × 3 validators). 12 positive images pooled: TP = 101, FP = 1, FN = 21 (122 ground-truth instances). 9 negative images contained no mealybugs.*

**Suggested paragraph:**

> Manual expert validation on 21 field-test images (7 per validator) yielded a grand-average **F1 of 91.75%**, **precision of 99.58%**, and **recall of 85.64%**, with mean detection confidence **57.33%**. These results reflect operational performance under expert review and are reported separately from **mAP@0.5** (Tables X and Y), which integrates precision–recall across confidence levels on large labeled test splits.

**Important — do not write:** “mAP@0.5 = 81%” or any mAP derived from Table Z. That would be incorrect.

---

## 4.1.4 Application deploy threshold (link to manual validation)

The deployed app uses a single confidence threshold (see `lib/core/constants.dart`):

| Setting | Threshold | Use in app |
|------|----------:|------------|
| Detection filter | **30%** (0.30) | Show bounding box, mealybug count, severity score, persisted record |

Update User Manual §4.4 if it still states 20% minimum or separate possible/confirmed tiers.

---

## Where to place each table in the thesis

| Content | Suggested location |
|---------|------------------|
| Table X (61.0% native mAP) | **4.1.1** — primary final-model benchmark |
| Table Y (v2→v13afix, 56.7% on 462) | **4.1.2** — model evolution / comparison to prior work |
| Tables Z-a–d (VAL1–3) | **4.1.3** or **4.3.6** “Expert validation of field detections” |
| Table 14 (826 deployments) | Keep in **4.3** — operational stats, not ground-truth metrics |
| Old Table 3 / 4 (0.526, 0.651) | Move to **Appendix** as “early training milestones” OR relabel as historical baseline only |

---

## Abstract — add one sentence

> On a held-out labeled test set (1,952 images), the final mealybug_v13afix detector achieved **61.0% mAP@0.5**; manual expert validation on 21 field images (7 per validator) yielded **91.75% F1**; System Usability Scale testing (n = 10 valid) produced a mean score of **77.0**.

---

## Conclusion — replace outdated mAP line

**Remove:** repeated emphasis on mAP **0.526** as final result.

**Use instead:**

> Benchmark evaluation of the deployed mealybug_v13afix model reported **61.0% mAP@0.5** on the native test split and **56.7% mAP@0.5** on the fixed 462-image comparison set, representing substantial improvement over the v2 baseline (21.1%). Manual expert validation during field testing reported **91.75% F1** on 21 images (7 per validator), while three-day deployment recorded 826 detection operations and 4,670 counted mealybugs across 12 fields.

---

## Regenerate benchmark numbers (if needed)

```powershell
cd D:\old_PINE
python scripts/evaluate_model_accuracy.py `
  --model runs/retrain/mealybug_v13afix/weights/best.pt `
  --data datasets/mealybug_v13afix/data.yaml --conf 0.12 `
  --out runs/calibration/mealybug_v13afix_native_eval.json

python scripts/evaluate_model_accuracy.py `
  --model runs/retrain/mealybug_v13afix/weights/best.pt `
  --data mealybug.v10-8th-yolo26n.yolo26/data.yaml --conf 0.12 `
  --out runs/calibration/accuracy_report.json
```
