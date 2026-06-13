# Plan to Reach Panel Targets (≥85% mAP@0.5, ≥80% P/R, ≥55% mAP@0.5:0.95)

*PINYA-PIC — mealybug_v16_selffix → v20+ pipeline*  
**Created:** 2026-05-29  
**Parent plan:** `V18_PANEL_REVISION_PLAN.md`  
**Status:** Approved target — execute in order; do not skip data gates

---

## 1. Target definition

The panel requires **all** of the following on the **v16-corrected held-out test** (1,952 images, 18,891 instances):

| Metric | v16 now | **Target** | Gap |
|--------|--------:|-----------:|----:|
| **mAP@0.5** | 73.3% | **≥ 85.0%** | −11.7 pp |
| **Precision** | 80.6% | **≥ 80.0%** | ✅ met at benchmark conf |
| **Recall** | 64.7% | **≥ 80.0%** | −15.3 pp |
| **mAP@0.5:0.95** | 40.7% | **≥ 55.0%** | −14.3 pp |

**Locked eval protocol (never change mid-run):**

```bash
yolo detect val \
  model=<best.pt> \
  data=runs/calibration/data_v16_corrected_test.yaml \
  split=test imgsz=1280 conf=0.001 iou=0.6
```

Use `scripts/label_eval_utils.py` / `capture_v16_baseline.py` for junction-safe corrected labels.

**Note:** Operational deploy uses **conf 0.25** — that affects field UX, not the headline mAP above.

---

## 2. Reality check

### What history proves

| Lesson | Evidence |
|--------|----------|
| **Labels beat bigger models** | fix500 (45.3% mAP) beat v10 with 34× fewer images |
| **DINO + self-train worked** | v15→v16: +17k then +2.7k boxes → **73.3%** corrected test |
| **Blind auto-label hurts** | v14 pseudo-labels → **37.6%** collapse |
| **SAM tighten failed** | v17 → **22.1%** |
| **More epochs without clean data fails** | v19 corrected test **61.9%** — worse than v16 |

### Honest forecast

| Outcome | Probability (if plan executed fully) |
|---------|--------------------------------------|
| Hit **≥80% recall** | **Moderate** (60–70%) |
| Hit **≥85% mAP@0.5** | **Moderate** (50–60%) — needs clean labels + hard data + YOLO26m |
| Hit **≥55% mAP@0.5:0.95** | **Hard** (40–50%) — needs tight box audit |
| Hit **all four targets** | **Hard** — treat as stretch; report trajectory if missed |

**Do not** expect threshold tuning alone to add 12 pp mAP. **Data + labels + architecture** are required.

---

## 3. Strategy overview (four waves)

```text
Wave 1 — LABEL TRUTH (weeks 1–4)     → expect 73% → 78–82% mAP@0.5
Wave 2 — HARD DATA (weeks 3–6)       → expect +4–8 pp mAP@0.5, +8–12 pp recall
Wave 3 — TRAIN STACK (weeks 6–9)     → expect +3–6 pp mAP@0.5, +5–8 pp mAP@0.5:0.95
Wave 4 — ENSEMBLE + GATE (weeks 9–10)→ expect +2–5 pp mAP@0.5 (if still short)
```

**Promotion rule:** A new checkpoint ships only if it beats v16 on **all** of: mAP@0.5, recall, mAP@0.5:0.95 (precision must stay ≥ 78%).

---

## Wave 1 — Label truth (weeks 1–4)

*Biggest lever for mAP@0.5:0.95 and recall. Panel guidance #3.*

### 1.1 Build audit queues (GPU, day 1–2)

```powershell
python scripts/export_confusion_cases.py --max-images 1952 --samples-per-class 50 --conf 0.25
python scripts/audit_annotations.py --model runs/retrain/mealybug_v16_selffix/weights/best.pt
python scripts/find_bad_annotations.py
```

### 1.2 CVAT manual review (weeks 1–3)

| Queue | Images | Goal |
|-------|-------:|------|
| Q1 False negatives | 400 | Add missed small/occluded mealybugs |
| Q2 Poor localization | 300 | Tighten boxes (IoU 0.5–0.75 band) |
| Q3 False positives | 200 | Remove white residue / glare labels |
| Q4 Pseudo-label spot-check | 300 | Audit v16 self-train +2,744 additions |
| Q5 Cluster policy | all reviewed | **One rule:** cluster box vs per-insect — document in `BOXING_GUIDELINES.md` |

**Rules:** `docs/data/BOXING_GUIDELINES.md`  
**Setup:** `docs/training/V18_CVAT_AUDIT_SETUP.md`  
**Output:** `datasets/mealybug_v20_audit/` (corrected YOLO labels)

### 1.3 Clean train set (week 3–4)

- Remove confirmed FP pseudo-labels from v14/v16 auto-adds  
- Re-split at **source-image** level (no aug leakage)  
- Target: **≥2,000** net box corrections on train + test audit subset  

### 1.4 Milestone gate M1

Retrain **v20s** (YOLO26s, v16 weights, lr0=0.0005, 80 epochs) on cleaned train only:

| Metric | Minimum to proceed |
|--------|-------------------|
| mAP@0.5 | **≥ 78%** |
| Recall | **≥ 70%** |
| mAP@0.5:0.95 | **≥ 45%** |

If **below 76%** mAP@0.5 → stop and extend audit (do not train v20m yet).

---

## Wave 2 — Hard-case data (weeks 3–6, parallel)

*Panel guidance #2. Recall and generalization.*

### 2.1 Merge existing field work

| Source | Images | Action |
|--------|-------:|--------|
| Field batch May 2025 | 510 | Finish CVAT → merge |
| fix500 reviewed | 500 | Already in pipeline — verify in v20 split |
| FOR VALIDATION | 139 | **Hold out** for expert eval only |

### 2.2 New collection minimum

**≥2,500 new base photos** (not aug copies):

| Category | Min | Why |
|----------|----:|-----|
| Early / light infestation | 400 | FN driver |
| Small clusters, under leaf, crown | 500 | FN + localization |
| Blur, low light, flash | 300 | Field phones |
| Wet / dusty / diseased leaf | 300 | FP driver if mislabeled |
| True negatives (no mealybug) | 500 | Precision + recall balance |
| Varieties / growth stages | 500 | Generalization |

**Workflow:** `docs/data/FIELD_DAY_INGEST.md` → pre-label v20 @ conf 0.12 → CVAT → merge.

### 2.3 Build `mealybug_v20` dataset

```powershell
python scripts/build_v13afix_dataset.py --augment-field --fix-corrupt
# → output datasets/mealybug_v20/ with build_report.json
```

| Split | Target images | Target instances |
|-------|--------------:|-----------------:|
| Train | 16,000–18,000 | 120k–140k |
| Val | 3,900 | ~31k |
| Test | **1,952 (fixed list)** | corrected GT updated only via documented audit |

### 2.4 Milestone gate M2

After v20s train on **v20 data** (120 epochs):

| Metric | Minimum to proceed |
|--------|-------------------|
| mAP@0.5 | **≥ 82%** |
| Recall | **≥ 75%** |
| mAP@0.5:0.95 | **≥ 48%** |
| Precision | **≥ 78%** |

---

## Wave 3 — Training stack (weeks 6–9)

*Panel guidance #4, #5, #6.*

### 3.1 Architecture comparison (same v20 data, imgsz 1280)

| Run | Weights | Batch | Epochs | Role |
|-----|---------|------:|-------:|------|
| `mealybug_v20n` | yolo26n.pt | 24 | 120 | Mobile floor |
| `mealybug_v20s` | yolo26s.pt | 16 | 120 | Primary candidate |
| `mealybug_v20m` | yolo26m.pt | 8 | 100 | **Best shot at 85%** |
| `mealybug_v20l` | yolo26l.pt | 4 | 80 | Optional if v20m < 83% |

**Train recipe (v20s/m — field-realistic aug):**

```bash
yolo detect train \
  model=yolo26m.pt \
  data=/workspace/datasets/mealybug_v20/data.yaml \
  epochs=120 imgsz=1280 batch=8 \
  optimizer=AdamW lr0=0.001 lrf=0.01 cos_lr=True \
  warmup_epochs=3 patience=30 \
  iou=0.45 box=7.5 close_mosaic=10 dropout=0.1 \
  hsv_h=0.015 hsv_s=0.5 hsv_v=0.4 \
  degrees=10 translate=0.1 scale=0.5 fliplr=0.5 blur=0.01 \
  mosaic=1.0 copy_paste=0 \
  project=/workspace/runs/train name=mealybug_v20m
```

**Avoid:** `copy_paste`, SAM tighten, lr0 > 0.001 fine-tuning from v16 (v18/v19 lesson).

### 3.2 Hard-example mining (mid-training)

After epoch 60 on v20m:

1. Run val on train subset; export worst 1,500 images  
2. Second fine-tune phase: 40 epochs, lr0=0.0003, oversample hard set 2×  

### 3.3 Multi-scale training (if mAP@0.5:0.95 still < 50%)

Train two extra specialists:

| Model | imgsz | Focus |
|-------|------:|-------|
| v20m_1024 | 1024 | Medium pests |
| v20m_1280 | 1280 | Small pests |

Fuse with WBF at eval (reporting); pick single best for mobile.

### 3.4 Self-train v21 (controlled)

**Only if** v20m ≥ 82% mAP@0.5:

```bash
# Predict train @ conf 0.50, merge IoU dedup 0.30
# Human-review 300 random additions
# Fine-tune v20m → v21, lr0=0.0003, 60 epochs
```

Cap: **+3,000** boxes max without full re-audit.

### 3.5 Milestone gate M3 (primary target)

| Metric | **Ship gate** |
|--------|---------------|
| mAP@0.5 | **≥ 85.0%** |
| Recall | **≥ 80.0%** |
| mAP@0.5:0.95 | **≥ 55.0%** |
| Precision | **≥ 80.0%** |

If mAP@0.5 is **83–84.9%** → proceed to Wave 4 before declaring success.

---

## Wave 4 — Ensemble & eval boost (weeks 9–10)

*Only if M3 not met. Reporting-grade boost.*

### 4.1 WBF ensemble (offline eval)

Combine best 2–3 of: v20m @ 1280, v20s @ 1280, v20m @ 1024.

```powershell
python scripts/ensemble_eval.py --model-a runs/retrain/mealybug_v20m/weights/best.pt --model-b runs/retrain/mealybug_v20s/weights/best.pt
```

**Thesis:** Report ensemble mAP as **upper bound**; ship **single** TFLite model that meets gate alone.

### 4.2 TTA at eval

```powershell
python scripts/eval_v14_tta.py  # adapt for v20 weights
```

Expected: **+1–3 pp** mAP@0.5 (does not change mobile deploy unless TTA shipped).

### 4.3 Test-time tiling (mobile Accuracy mode)

Train export @ **960** or **1280** TFLite; enable tiled inference for field recall.

---

## 4. Mobile deploy path (after model gate)

| Step | Action |
|------|--------|
| 1 | Pick smallest model that passes M3 alone (likely **v20m** or **v20s**) |
| 2 | Export TFLite @ **640** and **960** — benchmark latency on target phone |
| 3 | Set `detectionThreshold = 0.25`; add manual-check tier @ **0.12** |
| 4 | Update `shippedModelId = mealybug_v20m` (or v21) |
| 5 | Expert re-validation **≥50** images @ 0.25 deploy conf |

---

## 5. Week-by-week calendar

**Start:** 2026-05-29 | **Target completion:** 2026-08-15 (11 weeks, focused team)

| Week | Dates | Focus | Gate |
|------|-------|-------|------|
| 0 | May 29 – Jun 4 | Phase 0 finish (baseline, CVAT setup) | Archive + labels_v16_corrected |
| 1 | Jun 3 – 11 | Q1 FN audit + threshold sweep | 200 images reviewed |
| 2 | Jun 10 – 18 | Q2/Q3 audit + field batch merge | 500 images reviewed |
| 3 | Jun 17 – 25 | Q4 pseudo-check + v20 audit dataset | M1 retrain v20s |
| 4 | Jun 24 – Jul 2 | Field collection sprint 1 | +800 new photos |
| 5 | Jul 1 – 9 | Field collection sprint 2 + CVAT | +1,700 cumulative new |
| 6 | Jul 8 – 16 | Build mealybug_v20 + train v20n/s | Compare n/s |
| 7 | Jul 15 – 23 | Train v20m + hard mining | M2 check |
| 8 | Jul 22 – 30 | v21 self-train (if gated) + v20m fine-tune | M3 check |
| 9 | Jul 29 – Aug 6 | Ensemble/TTA if short of 85% | Final eval |
| 10 | Aug 5 – 15 | TFLite export, expert re-val, thesis | Resubmission package |

---

## 6. GPU & labor budget

| Resource | Estimate |
|----------|----------|
| **GPU hours (Vast)** | 80–120 hr (v20n + v20s + v20m + v21 + ensembles) |
| **Annotation hours** | 120–200 hr (4 reviewers × 3 weeks) |
| **Field collection** | 3–4 days × 2–3 collectors |
| **Expert re-validation** | 50+ images, 2–3 validators |

---

## 7. Commands cheat sheet

```powershell
# Baseline lock
python scripts/capture_v16_baseline.py --skip-label-fix

# After each train — corrected test eval
python scripts/capture_v16_baseline.py --skip-label-fix  # point MODEL to v20 best.pt

# Compare all runs
python scripts/compare_all_retrains.py

# Threshold sweep (deploy)
python scripts/sweep_detection_threshold.py `
  --model runs/retrain/mealybug_v20m/weights/best.pt `
  --data runs/calibration/data_v16_corrected_test.yaml `
  --deploy-focus --imgsz 1280 `
  --out runs/calibration/threshold_sweep_v20m_1280.json

# Export TFLite
python scripts/retrain_yolo.py --export-only runs/retrain/mealybug_v20m/weights/best.pt --export-imgsz 640
python scripts/retrain_yolo.py --export-only runs/retrain/mealybug_v20m/weights/best.pt --export-imgsz 960
```

---

## 8. What NOT to do

| Action | Why |
|--------|-----|
| SAM auto-tighten (v17) | Collapsed to 22% mAP |
| Aggressive fine-tune lr0=0.001 from v16 (v18/v19) | v19 **61.9%** corrected — worse than v16 |
| Blind pseudo-label merge @ low conf | v14 **37.6%** disaster |
| Train on aug-leaked splits | Inflates val, fails test |
| Claim 85% from ensemble only | Panel wants deployable single model |
| Lower deploy conf to fake recall in thesis | Report mAP at conf 0.001; deploy at 0.25 separately |

---

## 9. Thesis reporting (when targets met or missed)

### If all gates pass

> On the v16-consensus corrected test set (1,952 images; 18,891 instances), mealybug_v20m achieved mAP@0.5 **≥85%**, recall **≥80%**, and mAP@0.5:0.95 **≥55%**, meeting the panel revision targets under a fixed Ultralytics protocol (conf 0.001, IoU 0.6, imgsz 1280).

### If mAP@0.5 reaches 82–84% but not 85%

> Substantial improvement from v16 (73.3%) demonstrates a credible path; remaining gap is attributed to [hard-case data volume / small-object localization]. System remains positioned as decision-support prototype pending expanded field validation.

---

## 10. Tracking

| Doc | Purpose |
|-----|---------|
| `V18_PROGRESS_LOG.md` | Weekly metrics table |
| `V18_PHASE0_STATUS.md` | Phase 0 checklist |
| `V18_PIPELINE_STATUS.md` | Live H100 pipeline status |
| `V20_TRAINING_LOG.md` | v20s / v20m training log |
| `V18_PANEL_REVISION_PLAN.md` | Full panel response (guidance #1–8) |
| `work_logs/June 10 work log.md` | Daily log 2026-06-10 |
| `thesis/SYSTEM_ARCHITECTURE.md` | Thesis stack + diagrams |
| **This file** | **85% all-metrics execution plan** |

### Metric log (fill after each gate)

| Version | mAP@0.5 | P | R | mAP@0.5:0.95 | Date | Pass M1/M2/M3 |
|---------|--------:|--:|--:|-------------:|------|---------------|
| v16 | 73.3 | 80.6 | 64.7 | 40.7 | 2026-05-29 | baseline |
| v20s (clean labels) | *training* | — | — | — | 2026-06-10 | M1 |
| v20m (full data) | | | | | | M2/M3 |
| v21 (self-train) | | | | | | M3 |
| ensemble | | | | | | upper bound only |

---

## 11. First 7 days (start now)

| Day | Task | Owner | Status |
|-----|------|-------|--------|
| 1 | Finish Phase 0 on Vast (baseline JSON + full confusion export) | ML | ✅ 2026-06-10 (baseline JSON needs repro fix) |
| 2 | Create CVAT `v18_audit`; import 50 FN images | Annotation | ⬜ |
| 3 | Start Q1 FN review (target 50 img/day/reviewer) | Annotation | ⬜ |
| 4 | Threshold sweep v16 @ 1280; document deploy tiers | ML | ⬜ verify on Vast |
| 5 | Finish 510 field batch CVAT merge | Field | ⬜ |
| 6 | Remove 100 worst pseudo-label FPs from train list | ML + Annotation | partial (auto-fix in Wave 1) |
| 7 | M1 prep: build `mealybug_v20_audit` subset; schedule v20s train | ML | ✅ v20s **training** 2026-06-10 |

**Day 7 success:** CVAT active, ≥200 images audited, v20s training queued on Vast. **v20s train accelerated to 2026-06-10** via `v18_full_pipeline_vast.sh`; human CVAT still required in parallel.

---

*If any gate fails twice, escalate: add 1,000 more field images before more GPU training.*
