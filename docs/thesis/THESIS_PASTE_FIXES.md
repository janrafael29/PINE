# Thesis paste fixes — replace these blocks in Word

Copy each section below into your thesis document. Search for the **FIND** hint to locate the old text.

---

## 1. ABSTRACT — add after the SUS sentence

**FIND (after):**  
`yielding a mean System Usability Scale (SUS) score of 77.0 (SD = 12.9).`

**INSERT immediately after that sentence:**

> Benchmark evaluation of the final deployed detector (mealybug_v13afix) reported **61.0% mAP@0.5** on a native held-out test set (1,952 images) and **56.7% mAP@0.5** on a fixed 462-image comparison set, representing substantial improvement over the legacy v2 baseline (21.1% mAP@0.5). Manual expert validation on 21 field images (7 per validator, 3 validators) yielded **91.75% F1**, **99.58% precision**, and **85.64% recall** at the operational **30%** confidence threshold.

**Optional — tighten the closing sentence of the Abstract to:**

> Overall, PINYA-PIC supports earlier detection, improved spatial awareness, and targeted pest management through on-device mealybug detection (mealybug_v13afix), geotagged field records, and above-average usability (SUS = 77.0), contributing to enhanced agricultural practices in low-connectivity environments.

---

## 2. §1.3 Scope — still-image wording

**FIND:**

> to allow farmers to scan pests in real time without requiring an internet connection.

**REPLACE WITH:**

> to allow farmers to capture or select still images and run on-device mealybug detection without requiring an internet connection during inference.

---

## 3. §4.0.4 Camera and Detection Pipeline — add model name + threshold

**FIND (near end of first paragraph on inference):**

> The bundled TensorFlow Lite detector is then executed within the inference service. The output is parsed, confidence-filtered, and processed with Dart-side Non-Maximum Suppression.

**REPLACE WITH:**

> The bundled **mealybug_v13afix** TensorFlow Lite detector (YOLO26n exported at 640×640) is then executed within the inference service. The output is parsed, confidence-filtered at **0.30 (30%)**, and processed with Dart-side Non-Maximum Suppression.

---

## 4. §4.1.1 Training Validation Metrics — FULL REPLACEMENT

**Delete** from the start of §4.1.1 through the paragraph that ends with *"Section 3.3.2.1.6."*  
**Replace** with the text below (keeps Table 4 and Figure 26; fixes threshold, final model, duplicate Figure text).

---

### 4.1.1 Training Validation Metrics

Earlier training experiments produced the validation metrics summarized in **Table 4**, which compares an archived YOLO11n baseline with an intermediate YOLO26n training run. The YOLO11n figures reflect an earlier development stage and are included for historical comparison only. **They are not the metrics of the final deployed system.**

**Table 4.** Development Baseline (Early YOLO11n vs. Intermediate YOLO26n Validation Metrics)

*These results reflect intermediate validation metrics during early model development and are not representative of the final deployed system.*

| Metric | YOLO11n (archived baseline) | YOLO26n (intermediate training validation) |
|--------|----------------------------:|-------------------------------------------:|
| Precision | 0.667 | 0.707 |
| Recall | 0.462 | 0.594 |
| mAP@0.5 | 0.526 | 0.651 |
| mAP@0.5:0.95 | 0.247 | 0.297 |

The intermediate YOLO26n run achieved **65.1% mAP@0.5** on its training validation split. That value summarizes precision–recall integrated across confidence levels on the validation set used during that training run. It measures overall detector behavior on labeled validation images and **must not** be confused with (a) per-box confidence percentages shown in the mobile app, or (b) the **final** mealybug_v13afix benchmarks in Sections 4.1.2 and 4.1.4.

In the deployed PINYA-PIC application, a **single operational confidence threshold of 0.30 (30%)** is applied: detections below this score are not shown in the user interface and are not included in mealybug count, severity score, or saved records. Each retained detection is displayed as a percentage (0–100%) representing the model’s confidence for that bounding box. Benchmark mAP values in this chapter (typically at **conf = 0.12** for Ultralytics evaluation) follow standard practice for comparing detectors across studies and differ from the 30% deploy filter.

These historical metrics were computed on the validation split defined during the corresponding training run. They do not represent the final mealybug_v13afix evaluation (Tables 5–9, Section 4.1.2–4.1.5). On-device behavior may also differ slightly from PyTorch validation due to TensorFlow Lite export, letterboxing, and Dart-side Non-Maximum Suppression.

**Figure 26** presents training and validation performance curves for the intermediate YOLO26n run. The plots show the progression of precision, recall, mAP@0.5, and mAP@0.5:0.95 across epochs. Metrics rise and stabilize in later epochs, indicating convergence. Values at the best epoch are consistent with Table 4.

**Figure 26.** YOLO26n Training Performance Curves (Precision, Recall, mAP) — intermediate development run

The YOLO26n architecture demonstrated improved performance over the archived YOLO11n baseline during this development stage. **Subsequent dataset refinement and retraining produced the final deployed checkpoint, mealybug_v13afix** (Section 4.1.2), which supersedes the intermediate metrics in Table 4 for all claims about the shipped application.

Definitions of precision, recall, and mean Average Precision (mAP) at IoU 0.5 and 0.5:0.95 are discussed in Section 3.3.2.1.6.

---

## 5. §4.1.2 — clarify primary metrics (optional last paragraph)

**FIND (end of §4.1.2):**

> These results represent the final deployed model performance and serve as the primary indicators of detection accuracy.

**REPLACE WITH:**

> **Table 5 (61.0% mAP@0.5 on 1,952 native test images)** is the primary headline metric for the final deployed mealybug_v13afix model. **Table 6 (56.7% mAP@0.5 on 462 images)** supports fair comparison with earlier model versions (Table 8). Validation on the native split (3,904 images) reached **59.6% mAP@0.5** under the same evaluation protocol (conf = 0.12, IoU = 0.45, imgsz = 640).

---

## 6. §4.1.5 — link to UAT + threshold (add after first paragraph)

**INSERT after the paragraph that begins** *"This evaluation was conducted using expert-reviewed field samples (VAL1–VAL3)…"*

> This 21-image review (seven images per validator) complements the structured User Acceptance Testing (UAT) protocol in Section 3.4.8, in which three Department of Agriculture experts evaluated seven scenario types. Of the seven images per validator, four contained mealybug instances (used for precision/recall computation) and three were negative images (zero ground-truth population). The aggregated VAL1–VAL3 summary in Table 9 reflects expert-reviewed correctness at the same **30%** deploy threshold used in the application. These metrics are **not** mAP@0.5 and must not be reported as mAP.

---

## 7. §4.3.2 Confidence Score Distribution — FULL REPLACEMENT

**Replace entire §4.3.2** with:

---

### 4.3.2 Confidence Score Distribution

The distribution of confidence scores across all 826 detection operations shows that most retained detections fell in the **30–40%** band, with a tail extending to 75%. A small fraction of raw model outputs scored below 10% before filtering; those boxes are not shown or counted in the app because the deploy threshold is **0.30 (30%)**.

The deployment mean of **33.2%** is therefore consistent with operation near the 30% cutoff: the system keeps boxes the model scores modestly but above the minimum, which is expected for small, clustered mealybugs under variable field lighting and distance.

These statistics describe **per-detection UI confidence** during operational use. They **do not** represent precision, recall, F1, or mAP@0.5. Formal detection accuracy is reported in Tables 5, 6, and 8 (benchmark evaluation) and Table 9 (expert validation summary).

---

## 8. §4.4 Summary — add expert + v13afix line

**FIND (opening of §4.4):**

> Early training metrics (e.g., mAP@0.5 = 0.526, precision = 0.667, recall = 0.462) are included for development reference only

**REPLACE opening paragraph with:**

> The PINYA-PIC mobile application was successfully implemented and evaluated as a functional system for real-world agricultural use. The final deployed model (**mealybug_v13afix**) achieved **61.0% mAP@0.5** on a native test split (1,952 images) and **56.7% mAP@0.5** on a fixed 462-image benchmark, up from **21.1%** for the legacy v2 baseline (Table 8). Manual expert validation on 21 field images (7 per validator) reported **91.75% F1** at the 30% deploy threshold (Table 9). Early training metrics (e.g., Table 4; mAP@0.5 = 0.526 for YOLO11n) are historical development references only.

---

## 9. USER MANUAL §4.4 — threshold

**FIND:**

> Note: A confidence score of 20% or higher is the minimum threshold for a detection to appear. Higher confidence means the AI is more certain it has found a mealybug.

**REPLACE WITH:**

> Note: A detection is shown and counted only when its confidence is **30% or higher**. Higher percentages mean the AI is more certain it has found a mealybug. Scores below 30% are filtered out before display and saving.

---

## 10. §4.2 — table reference fixes (search-replace in body)

| FIND in text | REPLACE WITH |
|--------------|--------------|
| Table 8 summarizes their demographics | **Table 11** summarizes their demographics |
| Table 8 presents the SUS scores | **Table 12** presents the SUS scores |
| distribution is shown in Table 10 | distribution is shown in **Table 13** |
| Table 11). Odd-numbered | **Table 14**). Odd-numbered |
| presented in Table 12 | presented in **Table 15** |
| shown in Table 13 | shown in **Table 16** |
| Table 14 summarizes the per | **Table 17** summarizes the per |

---

## 11. Chapter III §3.3.2.1.6 — fix prose to match Table 3

Your **Table 3** uses **0.717 / 0.574 / 0.528 / 0.260** (v13afix-era training validation). Update the narrative paragraphs as follows.

**FIND:**

> These metrics represent archived validation results from earlier YOLO11 training experiments

**REPLACE WITH:**

> These metrics represent validation results from an intermediate YOLO26n training run (reported in Table 3) and are included for methodological reference. The **deployed** application uses the later **mealybug_v13afix** checkpoint (Chapter IV, Tables 5–8).

**FIND:**

> Precision (0.667):

**REPLACE WITH:**

> Precision (0.717):

**FIND:**

> approximately 66.7% of the bounding boxes

**REPLACE WITH:**

> approximately 71.7% of the bounding boxes

**FIND:**

> Recall (0.462):

**REPLACE WITH:**

> Recall (0.574):

**FIND:**

> The recall value of 0.462 indicates that this early model iteration successfully localized 46.2%

**REPLACE WITH:**

> The recall value of 0.574 indicates that this model iteration successfully localized 57.4%

**FIND:**

> mAP@0.5 (0.526):

**REPLACE WITH:**

> mAP@0.5 (0.528):

**FIND:**

> A score of 0.526 (52.6%)

**REPLACE WITH:**

> A score of 0.528 (52.8%)

**FIND:**

> mAP@0.5:0.95 (0.247):

**REPLACE WITH:**

> mAP@0.5:0.95 (0.260):

**FIND:**

> the achieved score of 0.247 (24.7%)

**REPLACE WITH:**

> the achieved score of 0.260 (26.0%)

**FIND:**

> Achieving a precision baseline of 0.667 at this training stage

**REPLACE WITH:**

> Achieving a precision of 0.717 at this training stage

---

## 12. TOC — suggested §4.1 headings (update in Word)

```
4.1 Model Performance Evaluation
  4.1.1 Training Validation Metrics
  4.1.2 Final Deployed Model (mealybug_v13afix)
  4.1.3 Inference Performance
  4.1.4 Comparison with Earlier Model Versions
  4.1.5 Manual Expert Validation (Field-Based)
  4.1.6 Model Size Optimization
```

Remove obsolete entries: *Confidence Threshold Calibration* as a separate §4.1.2 if it no longer exists in the body.

---

## 13. Optional — Table 9 footnote

Add under **Table 9** (Expert Validation Grand-Average):

> *Expert validation at app deploy threshold 0.30. Not mAP. 21 images total (7 per validator); 12 positive images pooled: TP = 101, FP = 1, FN = 21 (122 ground-truth instances). 9 negative images contained no mealybugs.*

---

## Checklist after paste

- [ ] Abstract includes 61.0%, 56.7%, 91.75% F1
- [ ] §4.1.1: single **30%** only; final model = **v13afix**; one Figure 26 block
- [ ] §4.3.2: **30%** only; no 40%
- [ ] User Manual: **30%**
- [ ] §4.2 / §4.3 table numbers 11–17
- [ ] §3.3.2.1.6 numbers match Table 3
- [ ] §4.0.4 names mealybug_v13afix
