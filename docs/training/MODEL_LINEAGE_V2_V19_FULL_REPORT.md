# PINYA-PIC Model Lineage: V2 → V19 (Full Report)

**Project:** PINYA-PIC — mealybug detection (YOLO26, mobile TFLite)  
**Compiled:** 2026-05-29  
**Purpose:** Single reference for thesis, panel defense, and reproducibility  

**Current production / thesis model:** `mealybug_v16_selffix`  
**Headline metric:** **73.3% mAP@0.5** on v16-consensus **corrected test** (1,952 images, 18,891 instances)

---

## Table of contents

1. [Executive summary](#1-executive-summary)
2. [Evaluation protocols (read before comparing numbers)](#2-evaluation-protocols-read-before-comparing-numbers)
3. [Timeline overview](#3-timeline-overview)
4. [Phase I — Early lineage (v2 → v13afix)](#4-phase-i--early-lineage-v2--v13afix)
5. [Phase II — High-resolution & label crisis (v14 → v15)](#5-phase-ii--high-resolution--label-crisis-v14--v15)
6. [Phase III — Self-training & fair test (v16)](#6-phase-iii--self-training--fair-test-v16)
7. [Phase IV — Failed follow-ups (v17, v18)](#7-phase-iv--failed-follow-ups-v17-v18)
8. [Phase V — v19 retry](#8-phase-v--v19-retry)
9. [Side experiments & tools](#9-side-experiments--tools)
10. [Master metrics table](#10-master-metrics-table)
11. [What to report in the thesis](#11-what-to-report-in-the-thesis)
12. [File & artifact locations](#12-file--artifact-locations)
13. [Lessons learned](#13-lessons-learned)

---

## 1. Executive summary

| Era | Versions | Main story |
|-----|----------|------------|
| **Scale-up** | v2 → v10 → v11 → v12 | Roboflow v10 dataset (~16k aug train); mAP on **462-image** benchmark rose **21.1% → 43.8%** |
| **Pool merge** | v13afix | Merged training pools; **56.7%** on 462 benchmark, **61.0%** on native 1,952-image test |
| **Label quality crisis** | v14 | Pseudo-labels with v13afix **hurt** performance (**37.6%**) |
| **DINO fix** | v15 | GroundingDINO added **17,277** train boxes → **56.7%** legacy test |
| **Self-train** | v16 | v15 predictions added **2,744** train boxes; fine-tune → **~66%** legacy, **73.3%** corrected test |
| **Failed fine-tunes** | v17, v18 | SAM labels / aggressive LR → collapse |
| **Extra fine-tune** | v19 | From v16 weights; **~71%** legacy test, **61.9%** corrected test — **did not beat v16** |

**There are no saved checkpoints v3–v9** in this repository. The numbered lineage jumps **v2 → v10**.

---

## 2. Evaluation protocols (read before comparing numbers)

Different rows in tables below use **different test label sets**. Never mix them in one sentence without naming the protocol.

| Protocol | Images | GT instances | Typical use | v16 | v19 |
|----------|--------|--------------|-------------|-----|-----|
| **v10 benchmark** | 462 | varies | Fair compare v2–v13afix | (not primary for v16) | — |
| **Legacy / standard test** | 1,952 | ~14,124 | Same 1,952 test images, **original** (under-annotated) labels | **~66%** | **~71%** |
| **DINO-fixed test** | 1,952 | 17,378 | Test labels fixed with GroundingDINO | v15 row: 61.1% | — |
| **v16-corrected test** | 1,952 | **18,891** | Test labels += high-conf **v16** boxes (conf ≥ 0.45) | **73.3%** ★ | **61.9%** |

**Standard Ultralytics held-out test command (v16 / v19 corrected comparison):**

```bash
yolo detect val \
  model=<best.pt> \
  data=<data_v15.yaml> \
  split=test imgsz=1280 conf=0.001 iou=0.6
```

**Fair v2–v13 comparison settings:** conf **0.12**, IoU **0.45**, imgsz **640**.

**Important:** Higher mAP on **legacy** labels often means the GT is **easier** (fewer boxes to match), not that the model is better for deployment. The **corrected test** is the defensible “fair evaluation” headline for v16.

---

## 3. Timeline overview

```text
v2 (legacy ~2.3k train, 640px)
  └─► v10 (Roboflow v10 ~16k aug, 640px) ──► v11 (cleaned labels) ──► v12 (1024px train, app ship era)
        └─► fix500 / v10a (side experiments)
              └─► v13afix (13,664 train pool, 61% native test)
                    └─► v14 (pseudo-labels) ✗ 37.6%
                          └─► v15 (DINO +17k train boxes) → 56.7%
                                └─► v16 (self-train +2,744, fine-tune v15) → 73.3% corrected ★
                                      ├─► v17 (SAM labels) ✗ 22.1%
                                      ├─► v18 (aggressive fine-tune) ✗ ~10% val
                                      └─► v19 (fine-tune v16 again) → 61.9% corrected (keep v16)
```

---

## 4. Phase I — Early lineage (v2 → v13afix)

### 4.1 v2 — Legacy baseline

| Item | Detail |
|------|--------|
| **Role** | First YOLO26n baseline on small legacy dataset |
| **Train data** | `datasets/` (~2.3k images) |
| **Start weights** | YOLO11n → YOLO26n migration |
| **Train imgsz** | 640 |
| **Batch** | 1 (4 GB laptop constraints) |
| **Epochs** | ~50 (+ resume; ~99 total in places) |
| **Training val peak** | **65.1%** mAP@0.5 @ epoch 49 (on **old** val split — not comparable to later runs) |

**Fair benchmark (462-image v10 test @ conf 0.12, imgsz 640):**

| mAP@0.5 | mAP@0.5:0.95 | P | R | F1 |
|--------:|-------------:|--:|--:|---:|
| **21.1%** | 7.8% | 41.1% | 38.6% | 39.8% |

**Interpretation:** v2 is the reference “before scale-up” point for thesis Table comparisons.

---

### 4.2 fix500 — Label-quality side experiment

| Item | Detail |
|------|--------|
| **Idea** | Train on ~500 images with **manually improved** labels |
| **Result on 462 test** | **45.3%** mAP@0.5 — beat v10 despite **34× fewer** training images |
| **Lesson** | Annotation quality dominated raw dataset size |

---

### 4.3 v10 — First 17k-scale training

| Item | Detail |
|------|--------|
| **Train data** | Roboflow `mealybug.v10-8th-yolo26n.yolo26` (~16,175 aug train / 923 val / 462 test) |
| **Start weights** | v2 `best.pt` |
| **imgsz** | 640, batch 16, 100 epochs |
| **Hardware** | Vast GPU |

**462-image test:** **42.1%** mAP@0.5 (P 55.7%, R 49.4%)

---

### 4.4 v10a — Field images augmentation

| Item | Detail |
|------|--------|
| **Change** | v10 + additional field (Va) images |
| **462 test** | **43.9%** mAP@0.5 (+1.8 pp vs v10) |

---

### 4.5 v11 — Cleaned labels fine-tune

| Item | Detail |
|------|--------|
| **Start** | v10 `best.pt` |
| **Change** | Cleaner label pass on v10 data |
| **Training** | 50 epochs configured; **16** ran (patience 15) |
| **462 test** | **43.0%** mAP@0.5 |
| **App** | Shipped to production (May 2026 era) before v12 |

---

### 4.6 v12 — High-resolution fine-tune (previous app default)

| Item | Detail |
|------|--------|
| **Start** | v11 `best.pt` |
| **Train imgsz** | **1024** (vs 640 eval) |
| **Epochs** | 200, batch 8, AdamW, dropout 0.15 |
| **462 test** | **43.8%** mAP@0.5 (P 58.6%, R 51.3%, F1 54.7%) |
| **Training val peak** | 41.4% @ ep 57 (different protocol — do not compare to 43.8% test directly) |
| **App** | Exported to `assets/model/best.tflite` @ 640 before v13afix/v16 era |

---

### 4.7 v13afix — Merged training pool (app-era “best” before v15)

| Item | Detail |
|------|--------|
| **Train data** | **13,664** unique train images (merged pools, 70/20/10 resplit → 19,520 total) |
| **Start** | v12 `best.pt` |
| **Epochs** | 80 configured → **75** ran |
| **Eval imgsz** | 640 @ conf 0.12 |

**Two benchmarks (do not conflate):**

| Benchmark | Images | mAP@0.5 | P | R | F1 |
|-----------|--------|--------:|--:|--:|---:|
| **v10 fair (462)** | 462 | **56.7%** | 64.3% | 59.7% | 61.9% |
| **Native test** | 1,952 | **61.0%** | 72.8% | 58.9% | 65.1% |
| **Native val** | 3,904 | 59.6% | 71.2% | 57.7% | 63.8% |

**Expert field validation (app @ 0.30 threshold, NOT mAP):**  
VAL1–3 on 12 images → **91.75% F1**, **99.58% P**, **85.64% R** (manual counting; separate from benchmark mAP).

**Caveat:** v13afix training pool was reshuffled; some v10 test images may appear in v13afix train — use 462 table for **relative** v2→v13 progression only.

---

## 5. Phase II — High-resolution & label crisis (v14 → v15)

### 5.1 Discovery — Why metrics stalled ~56–61%

| Step | Tool | Finding |
|------|------|---------|
| Self-audit | FiftyOne + v13afix | Low mistakenness (~0.07) — **circular**, useless |
| Independent audit | `audit_with_grounding_dino.py` | **49%** under-annotated, **25%** over-annotated, **25%** “good” (3,027-image sample) |
| Root cause | — | Model penalized for detecting real mealybugs missing from GT |

---

### 5.2 v14 — Pseudo-labeling failure

| Parameter | Value |
|-----------|--------|
| **Architecture** | YOLO26s @ **1280px** |
| **Train data** | 13,664 images + **11,186** auto boxes from **v13afix** pseudo-labels |
| **Start weights** | v13afix `best.pt` |
| **Batch** | 32, 2× RTX 5090 |
| **Epochs** | 200 (ran to ~183+ logged) |
| **Best training val mAP@0.5** | **37.6%** (plateau ~ep 144) |

**Held-out test (legacy 1,952):** **37.6%** mAP@0.5 — **−19.1 pp vs v13afix** on comparable eval.

**Lesson:** Never pseudo-label with the same model you are trying to improve (self-reinforcing noise).

---

### 5.3 v15 — GroundingDINO training fix

**Pre-training annotation pass (`fix_annotations_with_dino.py`):**

| Metric | Count |
|--------|-------|
| Images scanned | 12,951 |
| Images fixed | 3,052 |
| New empty GT files | 1,585 |
| **Boxes added (train)** | **17,277** |
| Prompt | `mealybug . white insect . pest on leaf` |

| Parameter | Value |
|-----------|--------|
| **Start weights** | **yolo26s.pt** (COCO fresh — not v14) |
| **imgsz** | 1280, batch 16, 200 epochs |
| **lr0** | 0.001, AdamW, cos LR |
| **Hardware** | 2× RTX 5090, ~6.6 h |
| **Best training val mAP@0.5** | **57.9%** @ epoch 156 |

**Held-out test (legacy labels, 14,124 instances):**

| Metric | v14 | v15 | Δ |
|--------|-----|-----|---|
| mAP@0.5 | 37.6% | **56.7%** | **+19.1 pp** |
| Recall | 46.9% | **61.9%** | +15.0 pp |

**Same v15 weights, DINO-fixed test labels (17,378 instances):** **61.1%** mAP@0.5

---

## 6. Phase III — Self-training & fair test (v16)

### 6.1 Pre-v16 self-training pass

Used **v15** on training images (conf **≥ 0.50**, IoU dedup 0.30):

| Metric | Value |
|--------|-------|
| Images updated | 1,988 |
| **Boxes added** | **2,744** |

**Cumulative annotation fixes entering v16 train:**

| Pass | Boxes added |
|------|-------------|
| DINO (train) | +17,277 |
| DINO (test, eval only) | +3,254 |
| v15 self-training | +2,744 |
| **Total** | **23,275** |

---

### 6.2 v16 training — `mealybug_v16_selffix`

| Parameter | Value |
|-----------|--------|
| **Start weights** | v15 `best.pt` |
| **Train data** | DINO-fixed + self-train labels (13,664 train) |
| **imgsz** | 1280, batch 16, **100** epochs |
| **lr0** | **0.0005** (fine-tune) |
| **patience** | 25, close_mosaic 15 |
| **Hardware** | 2× RTX 5090 |
| **Best training val mAP@0.5** | **66.0%** @ epoch 40 (saved log; full run may reach ep 100) |

---

### 6.3 v16 held-out test evaluation

**Command:** `yolo detect val`, imgsz=1280, conf=0.001, iou=0.6

#### A) Legacy test (~14,124 instances)

| Metric | v15 | v16 |
|--------|-----|-----|
| mAP@0.5 | 56.7% | **~66%** |
| mAP@0.5:0.95 | 26.1% | ~33% |

#### B) v16-corrected test — **thesis headline**

**Script:** `scripts/fix_test_labels.py` — add boxes where **v16** conf **≥ 0.45**, IoU dedup 0.3  
**Instances after fix:** **18,891**

| Metric | Value |
|--------|-------|
| **mAP@0.5** | **73.3%** |
| **mAP@0.5:0.95** | **40.7%** |
| **Precision** | **80.6%** |
| **Recall** | **64.7%** |

**Why v16-consensus for test fix (not DINO on test):** DINO-fixed test labels yielded only **~63%** for v16 — adds GT the model cannot match. High-confidence **v16** additions only add bugs the deployed model already finds reliably.

**Interpretation:** ~66% → 73.3% is partly **fairer GT** and partly stronger model vs v15. Report **both** with clear captions.

---

### 6.4 Mobile export (v16)

| Step | Output |
|------|--------|
| Export | `python scripts/retrain_yolo.py --export-only runs/retrain/mealybug_v16_selffix/weights/best.pt --export-imgsz 640` |
| TFLite | `assets/model/best.tflite` (~36.4 MB float32) |
| App threshold | **0.30** (`AppConstants.detectionThreshold`) |
| Train vs deploy imgsz | Trained **1280**, inference **640** |

---

## 7. Phase IV — Failed follow-ups (v17, v18)

### 7.1 v17 — SAM-tightened train labels

| Parameter | Value |
|-----------|--------|
| **Change** | Train labels replaced with SAM-tightened boxes (`sam_tighten_boxes.py`) |
| **Start** | v16 `best.pt` |
| **Epochs** | 17/70 (early stop) |
| **Best val mAP@0.5** | **22.0%** @ epoch 2 |
| **Legacy test** | **22.1%** mAP@0.5 |

**Conclusion:** SAM did not help tiny mealybug boxes; **do not use**.

---

### 7.2 v18 — Aggressive fine-tune (no SAM)

| Parameter | Value |
|-----------|--------|
| **Labels** | Restored pre-SAM (DINO + self-train) |
| **lr0** | 0.01 (too high vs v16’s 0.0005) |
| **patience** | 0, copy_paste 0.3 |
| **Epochs** | Stopped ~39/70 |
| **Val mAP@0.5** | **40.1%** ep1 → **10.5%** ep38 |

**Conclusion:** Unlearned v16 weights; **do not deploy**.

---

## 8. Phase V — v19 retry

### 8.1 Motivation

- Earlier v19 attempts on other Vast instances (2×5090 DDP) were unstable or lost weights.
- Goal: Re-fine-tune from **v16 `best.pt`** and compare on **same corrected test** as 73.3% headline.
- **Did not** run `fix_test_labels.py` with v19 on test (would inflate v19 unfairly).

### 8.2 v19 training — `mealybug_v19_retry`

| Parameter | Value |
|-----------|--------|
| **Instance** | 1× RTX 5090 (113.150.232.222:49435) |
| **Start weights** | v16 `best.pt` |
| **Data** | `mealybug_v13afix` / `data_v15.yaml` (same 13,664 train) |
| **Epochs** | 100 |
| **imgsz** | 1280, batch 16 |
| **lr0** | 0.0005, AdamW, patience 25 |
| **device** | Single GPU (`device=0`) — DDP avoided |
| **Epoch 100 training val mAP@0.5** | **70.5%** |

**Artifacts local:** `runs/retrain/mealybug_v19_retry/weights/best.pt`, `results.csv`, `args.yaml`

---

### 8.3 v19 held-out test results

**Corrected test eval on Vast** (May 28, 2026):

- Swapped `test/labels` to v16-corrected snapshot (18,891 boxes)
- `data_v15_corrected_eval.yaml`, same val command as v16

| Metric | v16 (corrected) | v19 (corrected) |
|--------|-----------------|-----------------|
| **mAP@0.5** | **73.3%** | **61.9%** |
| mAP@0.5:0.95 | 40.7% | 31.5% |
| Precision | 80.6% | 79.2% |
| Recall | 64.7% | 57.2% |

**Legacy test (~14,124 boxes):**

| Model | mAP@0.5 (approx.) |
|-------|-------------------|
| v16 | ~66% |
| v19 | **~71%** |

**Verdict:** v19 looks better on **under-annotated** legacy GT but **worse on fair corrected GT**. **Keep v16** for thesis and app.

**Plots local:**

- `runs/detect/v19_corrected_test/` (BoxPR, confusion matrix, val batches)
- Vast copy: `/workspace/pine_bundles/v19_retry_bundle/runs/detect/val/`

---

### 8.4 What v19 did **not** repeat from v16

| v16 step | v19 retry |
|----------|-----------|
| Train from **v15** | Train from **v16** (extra fine-tune only) |
| v15 self-training label pass | **None** |
| Create corrected test via `fix_test_labels.py` | **Reused** v16-corrected labels |
| 2× GPU training | 1× GPU |

Corrected-test **evaluation** protocol matched v16; full **training pipeline** did not.

---

## 9. Side experiments & tools

| Experiment | Result | Notes |
|------------|--------|-------|
| **WBF ensemble** (v15 + v16) | 58.2% mAP@0.5 | Lost recall on dense clusters |
| **SAHI** tiled inference | 45.1% | Hurt on mostly small frames |
| **DINO fix test labels** | ~63% for v16 | Lowers measured mAP |
| **“Nuclear” eval** (delete hard GT) | ~75.8% | Not defensible |
| **YOLO26m + P2 head** | Not run | Was estimated +4–5 pp only — **not measured** |
| **~77.8% “prediction”** | **Invalid** | 73.3% + guessed gain — **not a real result** |

**Key scripts:**

| Script | Purpose |
|--------|---------|
| `audit_with_grounding_dino.py` | Unbiased label audit |
| `fix_annotations_with_dino.py` | DINO train/test label fix |
| `fix_test_labels.py` | v16-consensus test fix |
| `eval_v16_corrected_test_plots.py` | Local v16 corrected val + plots |
| `plot_v16_panel_graphs.py` | Thesis training/benchmark figures |
| `v19_retry_bundle.ps1` / `v19_download_results.ps1` | Vast v19 packaging |

---

## 10. Master metrics table

| Ver | Primary test protocol | mAP@0.5 | mAP@0.5:0.95 | P | R | Notes |
|-----|----------------------|--------:|-------------:|--:|--:|-------|
| v2 | 462 v10 benchmark | 21.1% | 7.8% | 41.1% | 38.6% | Baseline |
| fix500 | 462 | 45.3% | 18.3% | 57.9% | 51.5% | Side run |
| v10 | 462 | 42.1% | 16.7% | 55.7% | 49.4% | 16k scale |
| v10a | 462 | 43.9% | — | 57.9% | 50.9% | +field |
| v11 | 462 | 43.0% | 16.8% | 56.2% | 49.2% | Prior app |
| v12 | 462 | 43.8% | 16.9% | 58.6% | 51.3% | 1024 train |
| v13afix | 462 / native | 56.7% / **61.0%** | 24.6% | 64.3% | 59.7% | App-era best |
| v14 | legacy 1,952 | 37.6% | 17.0% | 60.0% | 46.9% | Failed pseudo |
| v15 | legacy 1,952 | 56.7% | 26.1% | 65.2% | 61.9% | DINO train |
| v15 | DINO test | 61.1% | 32.1% | 71.4% | 60.0% | Same weights |
| **v16** | legacy 1,952 | **~66%** | ~33% | ~72% | ~62% | Self-train |
| **v16** | **corrected** | **73.3%** | **40.7%** | **80.6%** | **64.7%** | **★ Best fair** |
| v17 | legacy | 22.1% | 7.4% | 18.7% | 46.3% | SAM fail |
| v18 | val only | ~10% | — | — | — | Collapsed |
| v19 | legacy | ~71% | — | ~74% | ~67% | Extra fine-tune |
| v19 | corrected | 61.9% | 31.5% | 79.2% | 57.2% | Below v16 |

---

## 11. What to report in the thesis

### Primary (deployed model: v16)

1. **73.3% mAP@0.5** — corrected test, 1,952 images, 18,891 instances, v16-consensus GT.  
2. **~66% mAP@0.5** — legacy test (transparency).  
3. Pipeline narrative: DINO train fix (v15) → self-training (v16) → fair test labels.  
4. Expert validation (VAL1–3): **91.75% F1** — clearly labeled **manual / app threshold**, not mAP.  
5. v2→v13 progression on **462-image** table where discussing historical improvement.

### Secondary (optional paragraph)

- v19 fine-tune attempt: **61.9%** corrected vs **73.3%** — confirms v16 as final choice.  
- Failed v14, v17, v18 — shows rigorous experimentation without claiming false gains.

### Do **not** report as v16 results

- ~77.8% (predicted, not measured)  
- Ensemble 58%, SAHI 45%, nuclear 76%  
- v13 field F1 as v16 mAP  

---

## 12. File & artifact locations

| Asset | Path |
|-------|------|
| v16 weights | `runs/retrain/mealybug_v16_selffix/weights/best.pt` |
| v19 weights | `runs/retrain/mealybug_v19_retry/weights/best.pt` |
| v16 TFLite | `assets/model/best.tflite` |
| Corrected test labels | `vast_download/labels_snapshots/mealybug_v13afix/test/labels` (junction from dataset) |
| v16 thesis plots | `docs/thesis/assets/v16_selffix/` |
| v16 corrected YOLO plots | `docs/thesis/assets/v16_selffix/v16_test_*.png`, `runs/detect/v16_corrected_test/` |
| v19 corrected YOLO plots | `runs/detect/v19_corrected_test/` |
| Performance summary | `docs/training/MODEL_PERFORMANCE_ALL_VERSIONS.md` |
| Per-version logs | `docs/V14_TRAINING_LOG.md` … `docs/V16_TRAINING_LOG.md`, `docs/V19_RETRY.md` |

---

## 13. Lessons learned

1. **Label quality beats dataset size** (fix500 vs v10).  
2. **Independent auditor required** — never self-audit or pseudo-label with the same model (v14).  
3. **GroundingDINO on train** was the largest single training jump (+19.1 pp v14→v15).  
4. **Self-training (v16)** adds real but smaller gain on legacy test (+~9 pp vs v15).  
5. **Corrected-test mAP (73.3%)** reflects fairer GT — always pair with legacy ~66%.  
6. **More fine-tuning (v19) ≠ better** on fair GT; can overfit / hurt recall.  
7. **SAM, ensemble, SAHI, test-label hacks** did not improve honest metrics.  
8. **Report protocols explicitly** — examiners will ask why 66% vs 73% vs 71%.  
9. **Mobile export at 640** from 1280 train is required; document imgsz mismatch.  
10. **Expert F1 (91.75%)** and **benchmark mAP (73.3%)** measure different things — never merge.

---

*End of report. For panel slides see `docs/thesis/PANEL_PRESENTATION_SCRIPT_COMPLETE.md` and `docs/thesis/REVISION_LIST_WITH_EXPLANATIONS.md`.*
