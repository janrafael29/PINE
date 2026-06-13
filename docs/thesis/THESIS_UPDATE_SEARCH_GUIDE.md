# Thesis Update Search Guide

**Use in Word:** `Ctrl+F` each **SEARCH** string → apply **CHANGE TO** (or follow **ACTION**).

**Sources:** `MODEL_PERFORMANCE_ALL_VERSIONS.md`, `PANEL_STATUS_REPORT_2026-06-11.md`, app `lib/core/constants.dart`.

**Shipped app:** v17.0.0+2045 · model `mealybug_v16_selffix` · conf **0.25** · manual-check **0.12–0.24**

---

## Quick index (jump to section)

| Topic | Section |
|-------|---------|
| YOLO26n → YOLO26s | [A](#a-model-name-yolo26n--yolo26s) |
| Threshold 0.30 → 0.25 | [B](#b-deploy-threshold-030--025) |
| Training story (640 / Roboflow only) | [C](#c-training--methodology-ch-iii) |
| PyTorch vs TensorFlow | [D](#d-pytorch-train--tflite-export) |
| New section v20–v22 results | [E](#e-new-content-ch-iv--revision-cycle) |
| Abstract | [F](#f-abstract) |
| Conclusion & recommendations | [G](#g-conclusion--recommendations-ch-v) |
| User manual | [H](#h-user-manual-appendix) |
| Panel letter paragraph | [I](#i-panel-response-paragraph-copy-paste) |
| Do not change | [J](#j-leave-unchanged) |

---

## A. Model name: YOLO26n → YOLO26s

Final deployed checkpoint is **YOLO26s** (`mealybug_v16_selffix`), not nano. Keep **YOLO26n** only where you mean **early/intermediate** runs (Table 3, Table 4, Figure 26).

| # | SEARCH (Ctrl+F) | CHANGE TO |
|---|-----------------|-----------|
| A1 | `YOLO26n TensorFlow Lite model` (Abstract — deployed detector) | `YOLO26s TensorFlow Lite model (mealybug_v16_selffix)` |
| A2 | `integrates a YOLO26n-based object detection model` (§1.0 Background) | `integrates a YOLO26s-based object detection model (mealybug_v16_selffix)` |
| A3 | `YOLO26n-based model with geotagging` (§1.2.1 General Objective) | `YOLO26s-based model (mealybug_v16_selffix) with geotagging` |
| A4 | `bundled YOLO26n TensorFlow Lite detector` (§1.5 Inference definition) | `bundled YOLO26s TensorFlow Lite detector (mealybug_v16_selffix)` |
| A5 | `selection of a lightweight YOLO26n model` (§2.0.3 end) | `selection of a lightweight YOLO26s model for the final checkpoint (mealybug_v16_selffix); YOLO26n was used in earlier development runs` |
| A6 | `A YOLO26n TensorFlow Lite detector configured for mealybug detection` (§2.1.5 synthesis) | `A YOLO26s TensorFlow Lite detector (mealybug_v16_selffix) configured for mealybug detection` |
| A7 | `integrated with a bundled TensorFlow Lite detector from the YOLO26n` (§3.0 Implementation) | `integrated with a bundled TensorFlow Lite detector exported from mealybug_v16_selffix (YOLO26s)` |
| A8 | `Ultralytics YOLO26n` (§3.3.2.1.1 title / “final deployed”) | `Ultralytics YOLO26s (mealybug_v16_selffix)` |
| A9 | `deployed mobile application uses the YOLO26n model` (§3.3.2.1.1 body) | `deployed mobile application uses mealybug_v16_selffix (YOLO26s), exported to TensorFlow Lite` |
| A10 | `default configuration uses yolo26n.pt` (§3.3.2.1.1 — if describing **final** model) | `final checkpoint: fine-tuned YOLO26s from v15 best.pt; early runs used yolo26n.pt` |
| A11 | `bundled mealybug_v16_selffix TensorFlow Lite detector (YOLO26n architecture` (§4.0.4) | `bundled mealybug_v16_selffix TensorFlow Lite detector (YOLO26s architecture` |
| A12 | `The integration of a YOLO26n TensorFlow Lite detector` (§5.0.1) | `The integration of a YOLO26s TensorFlow Lite detector (mealybug_v16_selffix)` |
| A13 | `lightweight YOLO26n TensorFlow Lite model` (§5.0.3) | `YOLO26s TensorFlow Lite model (mealybug_v16_selffix)` |
| A14 | `Extend the deployed YOLO26n detector` (§5.1.2) | `Extend the deployed YOLO26s detector (mealybug_v16_selffix)` |
| A15 | `fine-tune the deployed YOLO26n model` (§5.1.2) | `fine-tune mealybug_v16_selffix (note: v20–v22 revision attempts did not beat v16)` |
| A16 | `adapt the YOLO26n detector` (§5.1.3) | `adapt the YOLO26s-based detector` |
| A17 | `AI model (YOLO26n) running directly` (User manual §4) | `AI model (YOLO26s, mealybug_v16_selffix) running directly` |
| A18 | `YOLO26n` (Glossary) | `YOLO26s (mealybug_v16_selffix) — earlier development used YOLO26n; see Table 4` |

**Keep YOLO26n (do not replace) when text refers to:**
- Table 3, Table 4, Figure 26 caption (“intermediate YOLO26n”)
- §4.1.1 “archived YOLO11n vs intermediate YOLO26n”
- §4.3.1 note “Earlier YOLO11 results…”

---

## B. Deploy threshold 0.30 → 0.25

App now: **0.25** confirmed · **0.12–0.24** manual-check (dashed, not counted).

| # | SEARCH | CHANGE TO |
|---|--------|-----------|
| B1 | `operational 30% confidence threshold` (Abstract) | `operational 25% confidence threshold (with manual-check hints at 0.12–0.24)` |
| B2 | `inference confidence threshold was set to 0.30` (§3.3.2.1.5) | `the confirmed detection threshold was set to 0.25; scores from 0.12 to 0.24 appear as manual-check hints (dashed overlays, not counted or saved)` |
| B3 | `A confidence threshold of 0.30` (§3.3.2.1.5) | `A confirmed threshold of 0.25` |
| B4 | `detections below 30% are suppressed` (§3.3.2.1.5) | `detections below 0.25 are not counted or saved; 0.12–0.24 may appear as manual-check hints only` |
| B5 | `Deploy threshold` `0.30` (any table in Ch III/IV if present) | `0.25` (confirmed); add row `Manual-check band` `0.12–0.24` |
| B6 | `confidence-filtered at 0.30 (30%)` (§4.0.4) | `confidence-filtered at 0.25 (25%) for confirmed detections; 0.12–0.24 shown as manual-check hints` |
| B7 | `deploy threshold is 0.30 (30%)` (§4.3.2) | `confirmed deploy threshold is 0.25 (25%); manual-check band 0.12–0.24` |
| B8 | `operation near the 30% cutoff` (§4.3.2) | `operation near the 25% confirmed cutoff` |
| B9 | `Field deployment (mean confidence 33.2%, 826 scans) reflects operational use at the 30% app threshold` (§4.3.5) | `…at the 25% confirmed threshold (manual-check band 0.12–0.24 not included in counts)` |
| B10 | `detection is shown and counted only when its confidence is 30% or higher` (User manual §4.4) | `confirmed detections require confidence ≥ 25%; 0.12–0.24 may appear as dashed manual-check hints (not counted)` |
| B11 | `Scores below 30% are filtered out` (User manual §4.4) | `Scores below 0.12 are hidden; 0.12–0.24 are hints only; ≥ 0.25 are confirmed` |

**Expert validation Table 9 (@ 0.30):** Do **not** silently change numbers. Add footnote:

> *Expert validation (Table 9) used the earlier 30% deploy threshold on 21 field images. The current release (v17.0.0) uses 25% confirmed with a 0.12–0.24 manual-check band; equivalent expert metrics at 0.25 have not yet been collected.*

---

## C. Training & methodology (Ch III)

| # | SEARCH | ACTION |
|---|--------|--------|
| C1 | `The export contained 2,328 training images and 665 validation images` (§3.3.2.1.2) | **Keep** as *initial Roboflow export*; **add after:** `The final canonical dataset (mealybug_v13afix) comprises 19,520 images (13,664 train / 3,904 val / 1,952 test, 70/20/10, seed 42).` |
| C2 | `Training was run in two legs due to VRAM constraints` (§3.3.2.1.3) | **Keep** for *early* YOLO11n/26n runs; **add new subsection** `3.3.2.1.X Final model training (mealybug_v16_selffix)` — see [E2](#e2-new-subsection-3321x--paste-after-31314) |
| C3 | `input size 640×640` (§3.3.2.1.3 — as **final** train size) | For **v16**: `input size 1280×1280`; TFLite export at 640×640 for mobile |
| C4 | `The final deployed model is based on Ultralytics YOLO26n` | Replace with [A8](#a-model-name-yolo26n--yolo26s) |
| C5 | (missing) PyTorch / Ultralytics training | **Add:** Training used **Python, Ultralytics YOLO, PyTorch** on Vast.ai GPUs (RTX 5090 for v15/v16; H100 for v20–v22). **TensorFlow is used only for TFLite export**, not training. |
| C6 | `generated arm64‑v8a release APK was approximately 79 MB` (§3.5.3) | Optional update: `v17.0.0+2045 split-per-ABI: arm64-v8a ~77 MB (includes ~37 MB TFLite model)` |

### E2. New subsection 3.3.2.1.X — paste after §3.3.2.1.4

**Title:** `3.3.2.1.X Final Detector Training Pipeline (mealybug_v16_selffix)`

**Paste:**

> The shipped detector followed a label-quality-first pipeline on dataset mealybug_v13afix (19,520 images). GroundingDINO audit identified widespread under-annotation (~49% of sampled train images). Training labels were corrected (+17,277 boxes), producing mealybug_v15 (YOLO26s, 1280 px, 200 epochs, AdamW, from COCO yolo26s.pt). A conservative self-training pass added +2,744 high-confidence boxes (v15 @ conf ≥ 0.50), then mealybug_v16_selffix was trained by fine-tuning from v15 (100 epochs, lr0=0.0005, 1280 px). Weights were exported to TensorFlow Lite (640 px input) for Android. Post-panel revision runs (v20s, v20m, v21, v21m, v22; June 2026) did not exceed v16 on the locked corrected test (Section 4.1.7).

---

## D. PyTorch train / TFLite export

| # | SEARCH | ADD nearby |
|---|--------|------------|
| D1 | `TensorFlow Lite` + `training` in same paragraph without distinction | Add: `Model weights were trained in PyTorch via Ultralytics; TensorFlow was used only in the export chain (PyTorch .pt → ONNX → TensorFlow SavedModel → TFLite).` |
| D2 | `Python 3.10+ for model training` (§3.3.2.2) | Add: `Ultralytics YOLO, PyTorch, torchvision; export: TensorFlow 2.x, tf-keras, onnx2tf` |

---

## E. New content Ch IV — revision cycle

### E1. New subsection — insert after §4.1.2 (before §4.1.3)

**Title:** `4.1.7 Post-Panel Model Revision Cycle (June 2026)`

**Paste table:**

**Table X. Revision models vs. v16 on corrected held-out test**  
*(1,952 images; 18,891 instances; labels_v16_corrected; imgsz=1280; conf=0.001; IoU=0.6)*

| Model | Strategy | mAP@0.5 | Precision | Recall | mAP@0.5:0.95 |
|-------|----------|--------:|----------:|-------:|-------------:|
| **v16** (deployed) | DINO + selffix fine-tune | **73.3%** | **80.6%** | **64.7%** | **40.7%** |
| v20s | Audited labels; YOLO26s from scratch | 61.6% | 73.6% | 55.4% | 31.4% |
| v20m | Audited labels; YOLO26m from scratch | 63.5% | 76.9% | 57.0% | 33.4% |
| v21 | 6-model consensus labels; fine-tune v16 | 64.6% | 78.1% | 59.6% | 33.7% |
| v21m | Consensus labels; fine-tune v20m | 62.2% | 73.3% | 57.1% | 31.9% |
| v22 | v16 selffix round 2 (+15,954 label adds) | 64.3% | 77.6% | 58.3% | 33.8% |
| Panel target | — | ≥85% | ≥80% | ≥80% | ≥55% |

**Paste paragraph:**

> In response to panel feedback, a full revision cycle was executed on an H100 GPU (Vast.ai): automated label audit (mealybug_v20), six-model strict consensus labeling (+12,182 adds, +34,218 tightens, −7,357 removes), and additional training runs (v20s, v20m, v21, v21m, v22). None exceeded v16 on the locked corrected test. Training-validation metrics during v21 (~73% mAP@0.5 on the validation split) were not predictive of corrected-test performance. v16 remains the thesis and application model (app release v17.0.0+2045).

### E2. Update §4.1.2 closing paragraph

| # | SEARCH | CHANGE TO |
|---|--------|-----------|
| E3 | `A follow-up fine-tune (mealybug_v19_retry, initialized from v16) reached 61.9% mAP@0.5 on the corrected test versus 73.3% for v16; v16 remained the deployed model.` | Keep v19 sentence; **append:** `Subsequent revision runs (v20s: 61.6%; v20m: 63.5%; v21: 64.6%; v21m: 62.2%; v22: 64.3%) likewise did not beat v16 (Table X, Section 4.1.7).` |

### E3. New UX / panel #8 — add to §4.0.4 or §4.0 new bullet

| # | SEARCH | ADD after detection pipeline paragraph |
|---|--------|--------------------------------------|
| E4 | `confidence-filtered at` (§4.0.4) | Add paragraph: `Advisory messaging follows panel guidance: negative scans display "No mealybug detected in this image" with guidance to rescan or inspect manually—not a claim that the plant is healthy. Positive scans use decision-support wording ("Possible mealybug detected—verify visually before control measures").` |

### E4. Update §4.4 Summary — append one sentence

> `A post-submission revision cycle (v20–v22) did not improve corrected-test metrics beyond v16; panel targets for recall (≥80%) and mAP@0.5 (≥85%) were not met, and v16 is retained as a promising prototype rather than a deployment-ready detector by those benchmarks.`

---

## F. Abstract

| # | SEARCH | CHANGE TO |
|---|--------|-----------|
| F1 | `YOLO26n TensorFlow Lite model` | `YOLO26s TensorFlow Lite model (mealybug_v16_selffix)` |
| F2 | `91.75% F1, 99.58% precision, and 85.64% recall at the operational 30% confidence threshold` | `91.75% F1, 99.58% precision, and 85.64% recall at the operational 30% confidence threshold on 21 expert-reviewed field images (distinct from benchmark mAP; current app uses 25% confirmed threshold)` |
| F3 | End of Abstract (before Keywords) | **Add sentence:** `Post-panel revision training (v20–v22, June 2026) did not exceed v16 on the held-out corrected test; v16 remains the deployed model.` |

---

## G. Conclusion & recommendations (Ch V)

### G1. §5.0 Conclusion — append after v16 metrics paragraph

> The panel’s assessment that the system is promising but not fully deployment-ready is accepted: corrected-test recall (64.7%) and strict localization mAP@0.5:0.95 (40.7%) remain below recommended scouting thresholds (≥80% recall, ≥55% mAP@0.5:0.95). A documented revision cycle (label audit, consensus relabeling, and retraining v20–v22) did not surpass v16.

### G2. §5.0.2 Achievement of Objectives — soften if needed

| # | SEARCH | ADD nuance |
|---|--------|------------|
| G3 | `Train a model for detection` achieved without caveat | Add: `Benchmark detection improved to 73.3% mAP@0.5 (corrected test), but panel numeric targets for recall and strict mAP were not met; further field data collection is the primary path forward.` |

### G3. §5.1.2 — replace generic retrain bullet

| # | SEARCH | CHANGE TO |
|---|--------|-----------|
| G4 | `Model Retraining with Field Data: Use the real-world detections...` | `Model improvement: Collect ≥2,500 new hard-case field images (early infestation, blur, negatives, varieties); expert re-validation at the 25% deploy threshold. Automated consensus relabeling and retraining (v21/v22) regressed on held-out metrics—do not repeat without new data or human-reviewed labels.` |

---

## H. User manual (Appendix)

| # | SEARCH | CHANGE TO |
|---|--------|-----------|
| H1 | `YOLO26n` | `YOLO26s (mealybug_v16_selffix)` |
| H2 | `30% or higher` / `below 30%` | See [B10–B11](#b-deploy-threshold-030--025) |
| H3 | `Confidence Score Explanation: ... <30% = "Low certainty` (§5.1.1 rec in Ch V — if mirrored in manual) | Align tiers with 0.25 confirmed + manual-check band |

**Add to manual §1.2 Key Features:**
- Two-tier detection (confirmed ≥25%; manual-check hints 0.12–0.24)
- Safer advisory text (no “healthy plant” claim on negative scans)

---

## I. Panel response paragraph (copy-paste)

Use in revision letter or Ch V if required:

> We accept that PINYA-PIC at v16 (73.3% mAP@0.5, 64.7% recall on the locked corrected test) is technically promising but not deployment-ready. We implemented safer decision-support messaging, lowered the operational threshold to 0.25 with a two-tier manual-check UI, exported confusion-case documentation, and executed a full revision cycle: automated label audit, YOLO26s and YOLO26m training at 1280px, six-model strict consensus labeling, and fine-tuned v21, v21m, and v22. None exceeded v16 on the held-out corrected test (v21: 64.6%; v22: 64.3%). We report these results transparently and retain v16 as the deployment candidate (app v17.0.0). Remaining gaps are recall, strict localization mAP, new hard-case field imagery, and expert validation at the deploy threshold.

---

## J. Leave unchanged

| Item | Value | Why |
|------|-------|-----|
| Table 5 v16 corrected test | 73.3 / 80.6 / 64.7 / 40.7 | Correct |
| Table 6 legacy ~66% | OK | Correct |
| Table 8 v2–v13afix on 462 images | OK | Historical benchmark |
| SUS mean | 77.0 (n=10) | Valid |
| Field deployment | 826 scans, 33.2% mean conf | Operational data |
| Table 9 expert F1 | 91.75% @ 0.30 | Keep with footnote (see B expert note) |
| TFLite size | ~36.4–37 MB | Matches assets |
| Inference times | 150 ms / 280 ms | OK |

---

## K. Optional new table — Panel guidance status

**Title:** Table X. Response to panel guidance (Morga et al.)

| # | Panel item | Status | Evidence in thesis |
|---|------------|--------|-------------------|
| 1 | Improve recall | Partial | Threshold 0.25 + two-tier UI; benchmark recall still 64.7% |
| 2 | Hard-case images (≥2,500) | Not done | §5.1.2 recommendation |
| 3 | Annotation quality | Major effort | §3.3.2.1.X, §4.1.7; did not improve held-out mAP |
| 4 | Field-realistic aug | Partial | v20–v22 trains; not on shipped v16 |
| 5 | 1280px training | Done | §3.3.2.1.X |
| 6 | Compare YOLO sizes | Partial (s, m) | Table in §4.1.7 |
| 7 | Confusion cases | Done | CONFUSION_CASES_V16 / appendix |
| 8 | Advisory safeguards | Done | §4.0.4 advisory paragraph |

---

## L. Word workflow checklist

- [ ] Run all **Section A** replacements (review each — skip Table 3/4/ Fig 26)
- [ ] Run all **Section B** replacements + Table 9 footnote
- [ ] Insert **§3.3.2.1.X** (Section C / E2)
- [ ] Insert **§4.1.7** + table (Section E1)
- [ ] Update **Abstract** (Section F)
- [ ] Update **§4.1.2** closing + **§4.4** (Section E)
- [ ] Update **Conclusion / Recommendations** (Section G)
- [ ] Update **User manual** (Section H)
- [ ] Add **List of Tables** entry for new Table X
- [ ] Regenerate **TOC** in Word

---

## M. Repo files (copy numbers from here)

| File | Use |
|------|-----|
| `docs/training/MODEL_PERFORMANCE_ALL_VERSIONS.md` | All metrics v2→v22 |
| `docs/thesis/PANEL_STATUS_REPORT_2026-06-11.md` | Panel 1–8, letter text |
| `docs/thesis/SYSTEM_ARCHITECTURE.md` | Ch III stack |
| `docs/thesis/CONFUSION_CASES_V16.md` | Panel #7 |
| `lib/core/constants.dart` | 0.25, 0.12, inputSize 640, shippedModelId |
| `docs/thesis/DETECTION_COLLECTOR_MIDDLEWARE.md` | Middleware framing, limitations, positive/negative |
| `docs/thesis/DA_SUPERUSER_SETUP.md` | DA/OMAG superuser account setup |
| `docs/thesis/PANEL_DEFENSE_TALKING_POINTS.md` | Defense demo script |

---

## K. Middleware & collector features (new — June 2026)

Add to **Abstract**, **Ch I**, **Ch V**:

| Topic | Paste from |
|-------|------------|
| Detection collector + middleware (not diagnostic) | `DETECTION_COLLECTOR_MIDDLEWARE.md` §1 |
| Positive-only map; all rows in tables | §4 |
| DA superuser + expert reply loop | `DA_SUPERUSER_SETUP.md`, `SYSTEM_ARCHITECTURE.md` |
| Limitations — not deployment-ready | `DETECTION_COLLECTOR_MIDDLEWARE.md` §3 |
| Recommendations — expert consultation + new features | §6 |
