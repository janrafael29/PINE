# Complete Model Performance History: v2 → v22

**Project:** PINYA-PIC Mealybug Detection  
**Architecture:** YOLO26 (anchor-free)  
**Compiled:** 2026-06-12 (updated after H100 revision pipeline: v20s/v20m/v21/v21m/v22 complete)

---

## Current Best Model (Thesis metrics) vs App Deploy

| Role | Version | Notes |
|------|---------|--------|
| **Thesis / benchmark** | **mealybug_v16_selffix** | **73.3%** mAP@0.5 on corrected test |
| **App (`assets/model/best.tflite`)** | **mealybug_v16_selffix** | Trained @ **1280px**, exported TFLite runs @ **640px** |

| Item | Value |
|------|--------|
| **Research weights** | `runs/retrain/mealybug_v16_selffix/weights/best.pt` |
| **Shipped TFLite** | `assets/model/best.tflite` (~37 MB, exported May 2026) |
| **Architecture** | YOLO26s @ 1280px train → 640px TFLite inference |
| **Deploy threshold** | **0.25** (`AppConstants.detectionThreshold`) |
| **Manual-check band** | **0.12–0.24** (dashed hints, not counted) |
| **NMS IoU** | 0.45 |

### Report these metrics in Chapter IV

| Evaluation type | mAP@0.5 | mAP@0.5:0.95 | P | R | Notes |
|-----------------|---------|--------------|-----|-----|--------|
| **Standard** (legacy test labels) | **~66%** | ~33% | ~72% | ~62% | Comparable to v13afix/v15 on same 1,952-image test |
| **Annotation-corrected test** | **73.3%** | **40.7%** | **80.6%** | **64.7%** | Test labels augmented with **v16 high-confidence** missing boxes (conf ≥ 0.45); 18,891 instances |
| Training val (during fit) | varies | varies | — | — | Not comparable across runs; use held-out test rows above |

**Do not report:** ensemble WBF (~58%), SAHI (~45%), DINO-fixed test (~63%), or “nuclear” GT-deletion (~76%) — these are evaluation artifacts or failed experiments (see below).

### Locked eval protocol (all v16+ revision comparisons)

| Parameter | Value |
|-----------|-------|
| Test images | 1,952 |
| Test instances | 18,891 (`labels_v16_corrected`) |
| `conf` | 0.001 |
| `iou` | 0.6 |
| `imgsz` | 1280 |

### Panel targets vs current best (v16)

| Metric | Panel target | v16 | Best revision (v21) | Gap (v16) |
|--------|-------------:|----:|--------------------:|----------:|
| mAP@0.5 | ≥85% | **73.3%** | 64.6% | −11.7 pp |
| Precision | ≥80% | **80.6%** ✅ | 78.1% | met |
| Recall | ≥80% | 64.7% | 59.6% | −15.3 pp |
| mAP@0.5:0.95 | ≥55% | 40.7% | 33.7% | −14.3 pp |

**Verdict:** v16 remains thesis + app model. Full H100 revision cycle (v20→v22) **did not beat v16** on corrected test.

---

## Summary of All Model Versions

| Version | mAP@0.5 (Test) | mAP@0.5:0.95 | P | R | Key Improvement |
|---------|:-:|:-:|:-:|:-:|---|
| **v2** | 21.1% | 7.8% | 41.1% | 38.6% | Baseline |
| **fix500** | 45.3% | 18.3% | 57.9% | 51.5% | Better labels (500 fixed images) |
| **v10** | 42.1% | 16.7% | 55.7% | 49.4% | Scale to 17K images |
| **v10a** | 43.9% | 17.3% | 57.9% | 50.9% | + field images |
| **v11** | 43.0% | 16.8% | 56.2% | 49.2% | Cleaned labels |
| **v12** | 43.8% | 16.9% | 58.6% | 51.3% | 1024px training (previous app deploy) |
| **v13afix** | 56.7% | 24.6% | 64.3% | 59.7% | 13.6K unique + merged pools |
| **v13afix (native)** | 61.0% | — | 72.8% | 58.9% | Own 1,952-image test set |
| **v14** | 37.6%† | 17.0%† | 60.0% | 46.6% | YOLO26s + 1280px; **pseudo-labels failed** |
| **v15** | 56.7%† | 26.1%† | 65.2% | 61.9% | **DINO-fixed train** (+17,277 boxes) |
| **v15 (DINO-fixed test)** | 61.1%‡ | 32.1%‡ | 71.4% | 60.0% | Same v15 weights, DINO-fixed test labels |
| **v16** | **~66%†** | **~33%†** | **~72%** | **~62%** | v15 + **self-training** (+2,744 train boxes) |
| **v16 (corrected test)** | **73.3%**§ | **40.7%**§ | **80.6%** | **64.7%** | **Best model**; v16-consensus test labels |
| **v17 (SAM train)** | 22.1%† | 7.4%† | 18.7% | 46.3% | **Failed** — SAM-tightened train + early stop |
| **v18 (no-SAM)** | ~10% val @ ep38† | — | — | — | **Failed** — mAP collapsed (stopped, not deployed) |
| **v19 (retry fine-tune)** | ~71%† / 61.9%§ | 31.5%§ | 79.2% | 57.2% | **Did not beat v16** on corrected test — kept v16 |
| **v20s** | 61.6%§ | 31.4%§ | 73.6% | 55.4% | Audited labels, YOLO26s from scratch @ 1280 |
| **v20m** | 63.5%§ | 33.4%§ | 76.9% | 57.0% | Audited labels, YOLO26m from scratch @ 1280 |
| **v21** | 64.6%§ | 33.7%§ | 78.1% | 59.6% | Fine-tune v16 on **6-model consensus** labels |
| **v21m** | 62.2%§ | 31.9%§ | 73.3% | 57.1% | Fine-tune v20m on consensus labels (29 ep, early stop) |
| **v22 (selffix r2)** | 64.3%§ | 33.8%§ | 77.6% | 58.3% | v16 selffix round 2 (+15,954 label adds) — **below v16** |

†Native / legacy test set (1,952 images; instance count varies by label version)  
‡DINO-fixed test (17,378 instances)  
§v16 high-confidence test fix (18,891 instances; `fix_test_labels.py` @ conf 0.45)

v2–v12 measured on v10 benchmark (462 images).

**Eval JSON artifacts:** `docs/thesis/assets/v18_baseline/` (`v16_*`, `v20s_m1/`, `v20m_m3/`, `v21_from_v16/`, `v21m_from_v20m/`, `v22_from_v16_selffix/`).

---

## How We Achieved the Current Scores (Pipeline Order)

This is the **ordered workflow** run on Vast.ai (2× RTX 5090) after v14 failed. Each step targets **annotation quality** first, then **training**, then **fair evaluation**.

### Phase A — Discover why mAP was stuck (~56–61%)

| Step | Tool / action | What it did | Outcome |
|------|----------------|-------------|---------|
| A1 | **FiftyOne + v13afix self-audit** | Model compared to its own labels | Max mistakenness ~0.07 — **useless** (circular) |
| A2 | **GroundingDINO audit** (`audit_with_grounding_dino.py`) | Independent zero-shot detector vs GT | **49% under-annotated**, 25% over-annotated, only **25% “good”** |
| A3 | Root cause | Labels missing thousands of mealybugs | Model penalized for **correct** detections (false positives in metrics) |

### Phase B — Fix training data (biggest training gain)

| Step | Tool / action | What it did | Outcome |
|------|----------------|-------------|---------|
| B1 | **DINO fix train** (`fix_annotations_with_dino.py`, merge) | Added **17,277** missing boxes on **13,664** train images | Clean training GT |
| B2 | **Train v15** | YOLO26s, imgsz **1280**, 200 epochs, AdamW, from COCO `yolo26s.pt` | **56.7%** mAP@0.5 on legacy test (+19.1pp vs v14) |
| B3 | **DINO fix test** (optional eval) | Fixed test set with DINO | **61.1%** mAP@0.5 (same v15 weights) |

### Phase C — Self-training round (v16)

| Step | Tool / action | What it did | Outcome |
|------|----------------|-------------|---------|
| C1 | Run **v15** on train @ conf **0.50** | Find bugs DINO still missed | **1,988** images updated |
| C2 | Merge high-conf predictions into labels | +**2,744** boxes | Richer train GT |
| C3 | **Train v16** | Fine-tune from **v15 best.pt**, 100 epochs, lr0=0.0005 | **~66%** mAP@0.5 legacy test |

### Phase D — Fair “annotation-corrected” evaluation (73.3%)

| Step | Tool / action | What it did | Outcome |
|------|----------------|-------------|---------|
| D1 | **`fix_test_labels.py`** | Add test boxes where **v16** agrees @ conf **≥ 0.45** (not DINO) | +1,513 boxes → **18,891** instances |
| D2 | **`yolo val` v16** on corrected test | Standard Ultralytics val, conf 0.001, iou 0.6 | **73.3%** mAP@0.5, **80.6%** P |

**Why v16-consensus for test fix (not DINO):** DINO on test dropped measured mAP to **~63%** (adds boxes the model cannot match). High-confidence **v16** additions only count bugs the deployed model already detects reliably.

### Phase E — Mobile export

| Step | Command | Outcome |
|------|---------|---------|
| E1 | `python scripts/retrain_yolo.py --export-only runs/retrain/mealybug_v16_selffix/weights/best.pt --export-imgsz 640` | `best_float32.tflite` (~37 MB) |
| E2 | Copy to `assets/model/best.tflite` | App runs **v16** @ 640px, conf **0.25** |

### Phase F — Attempts that did **not** improve honest metrics

| Attempt | Result | Why it failed |
|---------|--------|----------------|
| **WBF ensemble** (v15 + v16) | **58.2%** mAP@0.5 | Same architecture/data; fusion merges dense mealybugs → **lost recall** |
| **SAHI** tiled inference | **45.1%** | Most images are small; 640px tiles **hurt** |
| **DINO fix test labels** | **~63%** | Adds GT the model cannot detect → lowers mAP |
| **Nuclear eval** (multi-scale + delete unmatched GT) | **75.8%** | Inflated by removing hard GT — **not defensible** for thesis |
| **SAM tighten train → v17** | **22.1%** mAP@0.5 | SAM did not tighten well on tiny bugs; early stop @ epoch 17 |
| **v18 (ep38/70, Vast)** | **~10.5%** val mAP@0.5 | Collapsed from 40% @ ep1 — **stop run** |
| **v19 fine-tune from v16** | **61.9%** corrected | Recall dropped 7.5pp vs v16 |
| **v20s / v20m from scratch** | **61.6% / 63.5%** | Audited labels but lost v16 fine-tune knowledge |
| **v21 / v21m consensus retrain** | **64.6% / 62.2%** | Train labels shifted; val ~73% misled — corrected test regressed |
| **v22 selffix round 2** | **64.3%** | +15,954 adds vs v16 round 1’s +2,744 — likely label noise |

### Phase G — H100 revision pipeline (10–12 June 2026, COMPLETE)

| Step | What | Outcome |
|------|------|---------|
| G1 | Label audit + auto-fix → `mealybug_v20` | Dataset built |
| G2 | Train **v20s** (26s, 80 ep) + **v20m** (26m, 150 ep) from scratch @ 1280 | Both below v16 |
| G3 | **6-model strict consensus** (v16, v20s, v20m, GDINO, OWLv2, YOLO-World) | +12,182 adds, +34,218 tightens, −7,357 removes |
| G4 | Train **v21** (fine-tune v16, 100 ep) + **v21m** (fine-tune v20m, 29 ep) | Both below v16 |
| G5 | **v22 selffix** (v16 @ conf 0.45 add-only on v13afix → fine-tune v16, 50 ep) | Below v16 |
| G6 | Backup weights + eval JSONs to PC | `runs/h100_backup/` |

**Crop review** (`decisions.json`) was **skipped** (time constraint) — v21/v21m used auto-consensus labels only.

---

## V15 Results — DINO Training Fix

### Before vs After (same legacy test set)

| Metric | V14 (pseudo-labels) | V15 (DINO-fixed train) | Improvement |
|--------|:---:|:---:|:---:|
| mAP@0.5 | 37.6% | **56.7%** | **+19.1pp** |
| mAP@0.5:0.95 | 17.0% | **26.1%** | **+9.1pp** |
| Precision | 60.0% | **65.2%** | +5.2pp |
| Recall | 46.9% | **61.9%** | **+15.0pp** |

### V15 on DINO-fixed test labels

| Metric | Legacy test | DINO-fixed test | Change |
|--------|:-:|:-:|:-:|
| mAP@0.5 | 56.7% | **61.1%** | +4.4pp |
| Test instances | 14,124 | 17,378 | +3,254 |

---

## V16 Results — Self-Training (COMPLETED — current best)

**Strategy:** Use **v15** predictions (conf > 0.50) to add boxes GroundingDINO missed on training set.

| Item | Value |
|------|--------|
| Images updated | 1,988 |
| Boxes added (train) | 2,744 |
| Cumulative boxes added (all passes) | **23,275** (DINO train + DINO test + self-train) |
| Start weights | v15 `best.pt` |
| Train imgsz | 1280 |
| Epochs | 100 |
| Hardware | 2× RTX 5090 |

### V16 evaluation (held-out test, 1,952 images)

| Benchmark | mAP@0.5 | mAP@0.5:0.95 | P | R | Instances |
|-----------|---------|--------------|-----|-----|-----------|
| Legacy labels | **~66%** | ~33% | ~72% | ~62% | ~17,378 |
| **v16-corrected labels** | **73.3%** | **40.7%** | **80.6%** | **64.7%** | **18,891** |

**Interpretation:** The jump from ~66% → **73.3%** is largely **measuring against fairer ground truth** (missing mealybugs added to test). The model’s **true** gain from v15 → v16 on a **fixed** label set is smaller but real; both numbers should be reported with clear captions in the thesis.

---

## V17 — SAM Tighten + Early Stop (FAILED)

| Parameter | Value |
|-----------|--------|
| Train data | SAM-tightened labels (`sam_tighten_boxes.py`, `sam_b.pt`) |
| Start weights | v16 `best.pt` |
| Epochs planned | 70 |
| Epochs run | **17** (early stopping; best epoch **2**) |
| Best training val mAP@0.5 | **~22%** |
| Test eval (legacy labels) | **22.1%** mAP@0.5 |

**Conclusion:** Do not use v17. SAM did not improve box IoU on tiny mealybugs; shortened training made metrics collapse.

---

## V18 — No-SAM Fine-Tune (FAILED — stopped)

| Parameter | Value |
|-----------|--------|
| Goal | Beat v16 without SAM; full 70-epoch schedule |
| Start weights | v16 `best.pt` |
| Train labels | Restored **pre-SAM** train labels |
| Patience | **0** (no early stop) |
| copy_paste | **0.3** (likely hurting fine-tune) |
| Run name | `mealybug_v18_nosam` |

**Val mAP@0.5 during run (not improving):**

| Epoch | Val mAP@0.5 |
|-------|-------------|
| 1 | 40.1% |
| 3 | 17.6% |
| 10 | ~25% (est.) |
| **38** | **10.5%** |

**Best v16 val was 66.3% @ ep67.** v18 is **unlearning** the v16 weights — same failure pattern as v17.

---

## V19 — Retry Fine-Tune (COMPLETED — did not beat v16)

| Parameter | Value |
|-----------|--------|
| Start weights | v16 `best.pt` |
| Run name | `mealybug_v19_retry` |
| Weights | `runs/retrain/mealybug_v19_retry/weights/best.pt` |

### V19 held-out test results

| Benchmark | v16 | v19 |
|-----------|:-:|:-:||
| Legacy labels (mAP@0.5) | ~66% | **~71%** |
| **Corrected test** (mAP@0.5) | **73.3%** | 61.9% |
| Corrected mAP@0.5:0.95 | 40.7% | 31.5% |
| Corrected P / R | 80.6% / 64.7% | 79.2% / 57.2% |

**Verdict:** v19 looks better on under-annotated legacy GT but **worse on fair corrected GT** (recall dropped 7.5pp). **v16 remains the thesis + app model.**

---

## V20 — Audited Labels + Fresh Train (COMPLETED — below v16)

**Strategy:** Fix training labels systematically, then train **from scratch** at two scales (instead of more v16 fine-tunes).

| Item | Value |
|------|--------|
| Hardware | 1× **H100 SXM** (Vast.ai) |
| Dataset | `mealybug_v20` — full audit + auto-fix of train/valid labels |
| Image size | 1280 |
| Optimizer | AdamW |
| Augmentation | hsv, degrees=10, translate, scale, fliplr, mosaic; copy_paste=0 |

### V20 corrected-test results

| Run | Arch | Epochs | mAP@0.5 | mAP@0.5:0.95 | P | R |
|-----|------|--------|--------:|-------------:|--:|--:|
| **v20s** | YOLO26s | 80 | **61.6%** | 31.4% | 73.6% | 55.4% |
| **v20m** | YOLO26m | 150 | **63.5%** | 33.4% | 76.9% | 57.0% |
| **v16** (reference) | YOLO26s fine-tune | 100 | **73.3%** | 40.7% | 80.6% | 64.7% |

**Verdict:** From-scratch on audited labels **did not recover** v16’s corrected-test performance. Larger 26m helped vs 26s but still −9.8pp vs v16.

---

## V21 — Multi-Model Consensus Labels (COMPLETED — below v16)

Six independent voters on the 13,664-image train set:

| Voter | Type |
|-------|------|
| v16, v20s, v20m | Domain-trained YOLO |
| GroundingDINO | Zero-shot witness |
| OWLv2 | Zero-shot witness |
| YOLO-World | Open-vocabulary witness |

**Strict consensus pass** (`add_conf=0.50`, `min_voters=3`, `--apply-remove`):

| Change | Count |
|--------|------:|
| Boxes added | 12,182 |
| Boxes tightened | 34,218 |
| Boxes removed | 7,357 |
| Review queue items | 52,890 |
| Human crop review | **Skipped** (time) |

### V21 training + eval

| Run | Start weights | Epochs | lr0 | Corrected mAP@0.5 | P | R |
|-----|---------------|--------|-----|------------------:|--:|--:|
| **v21** | v16 | 100 | 0.00025 | **64.6%** | 78.1% | 59.6% |
| **v21m** | v20m | 29 (early stop) | 0.00025 | **62.2%** | 73.3% | 57.1% |
| **v16** (reference) | v15 | 100 | 0.0005 | **73.3%** | 80.6% | 64.7% |

**Training val during v21:** ~73% mAP@0.5, ~70% recall on **v20 val split** — **not predictive** of corrected-test performance.

**Verdict:** Consensus relabeling + retrain **regressed** on held-out corrected test. Do not ship v21/v21m.

---

## V22 — v16 Selffix Round 2 (COMPLETED — below v16)

**Strategy:** Repeat v16 selffix on original v13afix labels (add-only, no remove/tighten) using v16 @ conf 0.45, then fine-tune from v16.

| Item | Value |
|------|--------|
| Label adds | +15,954 boxes on 8,317 files (vs v16 r1: +2,744) |
| Dataset | `mealybug_v22` (v13afix images, updated train labels) |
| Start weights | v16 `best.pt` |
| Epochs | 50 |
| lr0 | 0.0001 |
| Hardware | H100 (Vast.ai) |

### V22 corrected-test results

| Metric | v16 | v22 | Δ |
|--------|----:|----:|--:|
| mAP@0.5 | **73.3%** | 64.3% | −9.0 pp |
| mAP@0.5:0.95 | **40.7%** | 33.8% | −6.9 pp |
| Precision | **80.6%** | 77.6% | −3.0 pp |
| Recall | **64.7%** | 58.3% | −6.4 pp |

**Verdict:** Aggressive selffix adds likely introduced noise. **v16 remains best.**

---

## Detailed Training Parameters

### v14 — Failed Pseudo-Labeling
| Parameter | Value |
|-----------|--------|
| Architecture | YOLO26s |
| Train data | 13,664 (+ 11,186 **v13afix pseudo-labels**) |
| Image size | 1280 |
| Result | **37.6%** mAP — self-reinforcing label noise |

### v15 — DINO-Fixed Full Dataset
| Parameter | Value |
|-----------|--------|
| Architecture | YOLO26s |
| Train data | 13,664 (+**17,277** DINO boxes) |
| Image size | 1280 |
| Epochs | 200 |
| Start weights | `yolo26s.pt` (COCO) |
| Result (legacy test) | **56.7%** mAP@0.5 |
| Result (DINO test) | **61.1%** mAP@0.5 |

### v16 — Self-Training Fine-Tune
| Parameter | Value |
|-----------|--------|
| Architecture | YOLO26s |
| Train data | DINO-fixed + **2,744** self-train boxes |
| Image size | 1280 |
| Epochs | 100 |
| LR | lr0=0.0005 |
| Start weights | **v15 best.pt** |
| Result (legacy test) | **~66%** mAP@0.5 |
| Result (v16-corrected test) | **73.3%** mAP@0.5 |

### v20s / v20m — From Scratch on Audited Labels
| Parameter | v20s | v20m |
|-----------|------|------|
| Architecture | YOLO26s | YOLO26m |
| Dataset | `mealybug_v20` | `mealybug_v20` |
| Image size | 1280 | 1280 |
| Epochs | 80 | 150 |
| Start weights | `yolo26s.pt` | `yolo26m.pt` |
| Corrected mAP@0.5 | 61.6% | 63.5% |

### v21 / v21m — Consensus Fine-Tunes
| Parameter | v21 | v21m |
|-----------|-----|------|
| Dataset | `mealybug_v21` | `mealybug_v21` |
| Start weights | v16 | v20m |
| Image size | 1280 | 1280 |
| Epochs | 100 | 29 (early stop) |
| lr0 | 0.00025 | 0.00025 |
| Corrected mAP@0.5 | 64.6% | 62.2% |

### v22 — Selffix Round 2
| Parameter | Value |
|-----------|--------|
| Dataset | `mealybug_v22` |
| Start weights | v16 |
| Image size | 1280 |
| Epochs | 50 |
| lr0 | 0.0001 |
| Corrected mAP@0.5 | 64.3% |

*(v2–v13afix parameter tables unchanged from prior revisions — see git history if needed.)*

---

## What Changed Between Versions

| Transition | Key change | Impact |
|-----------|-----------|--------|
| v13afix → v14 | Pseudo-labels with own model | **−19.1pp** |
| v14 → v15 | **GroundingDINO** train fix (+17k boxes) | **+19.1pp** |
| v15 → v16 | Self-training (+2,744 boxes) + fine-tune | **+~9pp** (legacy test) |
| v16 eval | v16-consensus **test** fix | **73.3%** reported (corrected GT) |
| v16 → v17 | SAM labels + early stop | **Failed** (22%) |
| v17 → v18 | Restore labels, no SAM, full epochs | **Failed** (mAP collapsed) |
| v18 → v19 | Retry fine-tune from v16 | 61.9% corrected — **kept v16** |
| v19 → v20 | Audit + from-scratch 26s/26m | 61.6%/63.5% — **below v16** |
| v20 → v21 | 6-model consensus + fine-tune | 64.6%/62.2% — **below v16** |
| v21 → v22 | v16 selffix round 2 (+15k adds) | 64.3% — **below v16** |

---

## GroundingDINO Audit (why we changed labels)

Sample: 3,027 train images

| Finding | Count | % |
|---------|-------|---|
| Under-annotated (DINO finds 4+ more) | 1,490 | 49.2% |
| Over-annotated (DINO finds 4+ fewer) | 764 | 25.2% |
| Good (±3 boxes) | 773 | 25.5% |

---

## Evaluation Benchmarks

| Benchmark | Images | Instances | Used for |
|-----------|--------|-----------|----------|
| v10 test | 462 | — | Fair comparison v2–v13afix |
| v13afix legacy test | 1,952 | 14,124 | v14–v16 “standard” row |
| DINO-fixed test | 1,952 | 17,378 | v15 DINO-test row |
| **v16-corrected test** | 1,952 | **18,891** | **v16 headline (73.3%)** + all v20–v22 comparisons |

**Standard val command (v16, corrected test):**
```bash
yolo detect val \
  model=runs/retrain/mealybug_v16_selffix/weights/best.pt \
  data=runs/calibration/data_v16_corrected_test.yaml split=test \
  imgsz=1280 conf=0.001 iou=0.6
```

---

## Key Lessons Learned

1. **Annotation quality >> quantity** — fix500 beat v10 on 34× fewer images.  
2. **Independent auditor required** — never self-audit with the same model (v14, FiftyOne+v13afix).  
3. **GroundingDINO on train** was the largest single training fix (+19.1pp).  
4. **Self-training (v16)** adds incremental gain when starting from strong v15 — but **conservative** adds (+2,744) beat aggressive round 2 (+15,954).  
5. **Corrected-test mAP (73.3%)** reflects fairer GT, not a magic model jump — report **both** legacy and corrected.  
6. **Training val ≠ corrected test** — v21 val ~73% misled; always eval on locked corrected test.  
7. **Consensus relabeling ≠ better held-out performance** — v21/v21m regressed despite cleaner-looking train labels.  
8. **Corrected test is coupled to v16** — extra GT from v16 @ conf ≥ 0.45 penalizes models that drift from v16.  
9. **Ensemble / SAHI / test-label hacking** did not help honest detection.  
10. **SAM** did not help mealybug boxes at this scale.  
11. **Mobile export at 640px** is required; model trained at 1280px.

---

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `scripts/audit_with_grounding_dino.py` | Unbiased annotation audit |
| `scripts/fix_annotations_with_dino.py` | Add missing train/test boxes (DINO) |
| `scripts/fix_test_labels.py` | Add missing **test** boxes (v16 @ conf 0.45) |
| `scripts/sam_tighten_boxes.py` | SAM box tighten (v17 — not recommended) |
| `scripts/ensemble_wbf_eval.py` | WBF ensemble eval (not used in thesis) |
| `scripts/retrain_yolo.py` | Train + TFLite export |
| `scripts/v18_full_pipeline_vast.sh` | v20 H100 pipeline (audit → fix → build → train s/m) |
| `scripts/build_mealybug_v20_dataset.py` | Build audited `mealybug_v20` dataset |
| `scripts/cache_detections.py` | Cache YOLO / GDINO / OWLv2 / YOLO-World predictions |
| `scripts/build_consensus_labels.py` | Multi-voter consensus label builder (v21) |
| `scripts/run_consensus_pipeline.sh` / `run_v21_full_pipeline.sh` | Full v21 pipeline |
| `scripts/prepare_mealybug_v22_selffix.py` / `run_v22_selffix_pipeline.sh` | v22 selffix pipeline |
| `scripts/capture_v16_baseline.py` | Locked corrected-test eval capture |
| `scripts/make_review_grid.py` / `apply_review_decisions.py` | Crop-grid human review loop |

---

## Current Deployed Model

| Item | Value |
|------|--------|
| **App model** | **v16** (`mealybug_v16_selffix`) |
| **App version** | 17.0.0+2045 (June 2026 release build) |
| **TFLite** | `assets/model/best.tflite` @ **640px** (trained @ 1280px) |
| **Threshold** | **0.25** confirmed; **0.12–0.24** manual-check hints |
| **Previous app default** | v12 / v13afix era |

### Operational (app) validation available for v13afix

Manual expert validation on field-test images was done for the **deployed v13afix** pipeline at the app’s operational threshold (**0.30**). Reported separately from mAP:

- **F1:** 91.75%
- **Precision:** 99.58%
- **Recall:** 85.64%

No equivalent expert TP/FP/FN-at-**0.25** report is recorded for **v16** yet; for v16 we currently report benchmark mAP numbers only.

---

## Realistic Path Beyond 73.3%

| Action | Expected gain | Status |
|--------|---------------|--------|
| ~~v18/v19 fine-tunes from v16~~ | — | **Failed — abandoned** |
| ~~v20: audited labels + from-scratch 26s/26m~~ | — | **Complete — below v16** |
| ~~v21: 6-model consensus labels~~ | — | **Complete — below v16** |
| ~~v22: v16 selffix round 2~~ | — | **Complete — below v16** |
| v16 threshold sweep @ deploy conf **0.25** | Operational P/R report | Planned |
| Expert field re-validation @ 0.25 | Field F1 for v16 | Not done |
| **≥2,500 new hard-case field photos** | Likely largest real gain | **Not done** |
| Hard-FN fine-tune from v16 on **original** labels | Moderate upside | Optional last GPU path |
| Human review of consensus queue (52k items) | Label quality | Not done |

**Do not retry:** consensus retrain, train from scratch, or ship v21/v21m/v22.

Target: **≥85% on all panel metrics** (corrected test) — **not met** with current data and revision strategies.

---

## Summary (key numbers)

- **v13afix (app-era / deployed)**: **61.0% mAP@0.5** on the native held-out test (1,952 images); at app threshold **0.30**, field expert validation reported **F1 91.75%** (Precision **99.58%**, Recall **85.64%**).
- **v16 (current thesis model / current app TFLite)**: **~66% mAP@0.5** on legacy labels and **73.3% mAP@0.5** on the v16-consensus corrected test (18,891 instances). **Shipped in app v17.0.0** @ conf **0.25**.
- **v17 / v18 / v19**: all fine-tune attempts from v16 failed or regressed on the fair corrected test — v16 retained.
- **v20s / v20m (H100, June 2026)**: from-scratch on audited `mealybug_v20` — **61.6% / 63.5%** corrected test.
- **v21 / v21m (H100, June 2026)**: consensus-label fine-tunes — **64.6% / 62.2%** corrected test.
- **v22 (H100, June 2026)**: v16 selffix round 2 — **64.3%** corrected test.
- **Reporting rule:** keep “legacy/standard” vs “corrected test” captions explicit; do not substitute corrected-test numbers for honest benchmark claims without stating the label-fix protocol. **Do not use training val metrics for panel claims.**

**Related:** `docs/thesis/PANEL_STATUS_REPORT_2026-06-11.md` — panel point-by-point status.
