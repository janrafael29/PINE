# Chapter IV — Model Performance (draft text for thesis)

> **Updated:** For paste-ready tables (v2→v13afix comparison, VAL1–3 manual validation, native 61.0% mAP), use **`docs/thesis/THESIS_CHAPTER_IV_METRICS_SECTION.md`** first. This file retains narrative discussion; refresh numbers below from that doc before pasting.

**Purpose:** Paste or adapt into **Section 4.1** (Model Performance Evaluation) and/or **Chapter V Discussion**. Aligns with fair benchmark in `docs/training/MODEL_COMPARISON_V2_V10_V11_V12.md`, `docs/training/MODEL_METRICS_V2_V13.md`, and `docs/training/ACCURACY_METRICS.md`.

**Suggested placement:** New subsection **4.1.4 Interpretation of Detection Metrics and Reported Performance** (after 4.1.1–4.1.3), or **5.x Discussion — Model Generalization**.

---

## 4.1.4 Interpretation of Detection Metrics and Reported Performance

The mealybug detector was evaluated as an **object-detection** task, not as single-label image classification. In classification, *accuracy* is often defined as the proportion of correct predictions over all predictions. That definition is a poor fit for PINYA-PIC because a single leaf image may contain **zero, one, or many** mealybug instances, and a prediction is counted correct only when both the **class** and the **bounding-box location** satisfy an intersection-over-union (IoU) criterion (typically IoU ≥ 0.5). For this reason, the study reports **mean average precision at IoU 0.5 (mAP@0.5)** as the primary metric, together with **precision**, **recall**, and the **F1-score** derived from them. These measures are standard in the YOLO literature and are stricter than image-level accuracy because localization errors and duplicate or missed boxes are penalized.

All comparative results in this section use the same Roboflow v10 export (`mealybug.v10-8th-yolo26n.yolo26`), with approximately 16,175 augmented training images, 923 validation images, and **462 held-out test images**. Models were evaluated at **confidence 0.12**, **IoU 0.45**, and **input size 640×640**, so that improvements across training iterations (v2 through v13afix) reflect model and data changes rather than different evaluation protocols.

The final deployed model (**mealybug_v13afix**) achieved **61.0% mAP@0.5** on its native held-out test split (1,952 images) and **56.7% mAP@0.5** on the fixed 462-image v10 comparison set, with **64.3% precision**, **59.7% recall**, and **61.9% F1** on that benchmark. Although these percentages may appear modest when compared with classification accuracies often reported above 90%, they are **defensible for small-object agricultural pest detection** for three reasons. First, **absolute mAP is less informative than progression on a fixed benchmark**: the legacy baseline (v2) reached only **21.1% mAP@0.5** on the same test set, while v10 reached **42.1%**, v11 **43.0%**, v12 **43.8%**, and v13afix **56.7%**—more than doubling performance relative to the legacy baseline. Second, **the biological and imaging task is inherently difficult**: mealybugs are small relative to the frame, low-contrast against leaf tissue, and frequently clustered; mobile photographs introduce blur, uneven lighting, and compression that degrade box-level matching. Third, the system deliberately uses a **lightweight YOLO26n** architecture exported to **TensorFlow Lite** for **offline** inference on farmer-grade Android devices; this trades some peak accuracy for deployability (model size, latency, and RAM), which is appropriate for a field screening tool rather than laboratory enumeration.

Separate **manual expert validation** on 12 field images (VAL1–VAL3; see `docs/thesis/THESIS_CHAPTER_IV_METRICS_SECTION.md`) reported **91.75% F1**, **99.58% precision**, and **85.64% recall** at app operating thresholds. That evaluation measures expert-reviewed TP/FP/FN counts and **must not** be reported as mAP@0.5.

The deployed application uses the **v13afix** TFLite model. Operational threshold in the mobile client is **0.30** (30%) for displayed detections, counts, severity, and saved records; it differs from the **0.12** confidence used for benchmark mAP reporting, which follows common practice for comparing detectors across studies.

**Limitations** should be stated clearly: benchmark metrics are computed on labeled test splits and may not fully reflect performance on all in-field captures; residual **domain gap** between curated exports and crown close-ups collected during farm visits remains an active concern. Per-box detection JSON is not always restored from cloud sync, so historical map analytics may underrepresent fine-grained box detail. Nevertheless, the reported **61.0% native test mAP@0.5 (v13afix)** and the large gain over the legacy model support the conclusion that the PINYA-PIC detection pipeline is **fit for purpose as a mobile screening and mapping aid**, provided users treat outputs as decision support and follow recommended rescanning and field verification practices.

---

## Suggested table caption (update Table 4.x)

**Table 4.x. Fair benchmark comparison of YOLO26n training iterations on Roboflow v10 test split (n = 462 images; conf = 0.12; IoU = 0.45; imgsz = 640).**

| Model | Description | Precision | Recall | F1 | mAP@0.5 | mAP@0.5:0.95 |
|-------|-------------|----------:|-------:|---:|--------:|-------------:|
| v2 | Legacy baseline | 41.1% | 38.6% | 39.8% | 21.1% | 7.8% |
| v10 | Full ~17k train | 55.7% | 49.4% | 52.4% | 42.1% | 16.7% |
| v11 | Label-clean fine-tune (deployed TFLite) | 56.2% | 49.2% | 52.5% | 43.0% | 16.8% |
| v12 | High-res fine-tune from v11 | 58.6% | 51.3% | 54.7% | 43.8% | 16.9% |
| **v13afix** | v13afix pool (deployed) | **64.3%** | **59.7%** | **61.9%** | **56.7%** | **24.6%** |

*Note:* v2 weights were trained on an earlier, smaller `datasets/` split; values in this table evaluate all models on the same v10 test set for comparability. Full tables (native 61.0% mAP, VAL1–3): `docs/thesis/THESIS_CHAPTER_IV_METRICS_SECTION.md`.

---

## One-sentence summary for adviser (optional)

> The deployed mealybug_v13afix model reached **61.0% mAP@0.5** on its native test split and **56.7% mAP@0.5** on the fixed 462-image comparison set—a substantial improvement over the v2 baseline (21.1% mAP@0.5). Manual expert validation on 12 field images reported **91.75% F1**.

---

## Cross-references in repo

- Metrics source: `runs/calibration/model_comparison_eval.json`, `runs/calibration/accuracy_report.json`, `runs/calibration/mealybug_v13afix_native_eval.json`
- Full comparison + VAL tables: `docs/thesis/THESIS_CHAPTER_IV_METRICS_SECTION.md`, `docs/training/MODEL_METRICS_V2_V13.md`
- Threshold / app alignment: `docs/training/ACCURACY_METRICS.md`, `runs/calibration/THESIS_TABLE_4_2_5.csv`
