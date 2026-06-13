# Panel Concerns vs. Current Work — Status Report

**Project:** PINYA-PIC Mealybug Detection  
**Report date:** 12 June 2026 (updated after v22 selffix pipeline completion)  
**Context:** Response to Morga et al. major-revision feedback + H100 pipeline (10–12 June)

---

## Executive summary

The panel’s core diagnosis is **correct and accepted**: v16 is promising as a prototype but **not deployment-ready** because recall (64.7%) and strict localization (mAP@0.5:0.95 = 40.7%) are too low for a pest-scouting tool.

Since that feedback, substantial **engineering and data work** has been completed — especially on **label quality**, **model comparison**, **threshold tuning**, and **safe app messaging**. The full H100 revision pipeline (v20 → strict consensus → v21 → v21m → **v22 selffix**) **finished 12 June 2026**. **None of the revision models beat v16** on the locked corrected test. **v16 remains the deployment and thesis model** (shipped in app **v17.0.0+2045**).

**Honest bottom line:** Major revision **response is documented**; **numeric panel targets are not met**. You can show strong *effort and transparency*; you **cannot** claim *minimum deployability* at ≥85% mAP@0.5 / ≥80% recall.

---

## Current model numbers (locked protocol, corrected test)

| Model | mAP@0.5 | Precision | Recall | mAP@0.5:0.95 | Status |
|-------|--------:|----------:|-------:|-------------:|--------|
| **v16** (thesis baseline) | **73.3%** | **80.6%** | **64.7%** | **40.7%** | **Best — keep for app + thesis** |
| v20s (audited labels, YOLO26s) | 61.6% | 73.6% | 55.4% | 31.4% | Below v16 |
| v20m (audited labels, YOLO26m) | 63.5% | 76.9% | 57.0% | 33.4% | Below v16 |
| v21 (consensus labels, fine-tune from v16) | 64.6% | 78.1% | 59.6% | 33.7% | Below v16 |
| v21m (consensus labels, fine-tune from v20m) | 62.2% | 73.3% | 57.1% | 31.9% | Below v16 |
| v22 (v16 selffix round 2, fine-tune from v16) | 64.3% | 77.6% | 58.3% | 33.8% | Below v16 |
| **Panel target** | **≥85%** | **≥80%** | **≥80%** | **≥55%** | **Not met** |

**Eval protocol (locked):** 1,952 images, 18,891 instances, `imgsz=1280`, `conf=0.001`, `iou=0.6`, v16-corrected test labels.

**Eval artifacts:**

| Model | Metrics JSON |
|-------|----------------|
| v16 | `docs/thesis/assets/v18_baseline/v16_baseline_capture/` |
| v20s | `docs/thesis/assets/v18_baseline/v20s_m1/v20s_m1_corrected_test_metrics.json` |
| v20m | `docs/thesis/assets/v18_baseline/v20m_m3/v20m_m3_corrected_test_metrics.json` |
| v21 | `docs/thesis/assets/v18_baseline/v21_from_v16/v21_from_v16_corrected_test_metrics.json` |
| v21m | `docs/thesis/assets/v18_baseline/v21m_from_v20m/v21m_from_v20m_corrected_test_metrics.json` |
| v22 | `docs/thesis/assets/v18_baseline/v22_from_v16_selffix/v22_from_v16_selffix_corrected_test_metrics.json` |

**Why training val looked better than corrected test:** During training, Ultralytics reports metrics on the **validation split** (3,904 images, original val labels). Thesis/panel numbers use the **v16-corrected held-out test** (1,952 images, richer GT built from v16 high-confidence boxes). Val metrics during v21 training (~73% mAP@0.5, ~70% recall) and v22 training (~57% val mAP@0.5 flat after ep 6) were **not** predictive of corrected-test performance.

---

## What we did (10–12 June 2026)

### Night 1 — H100 setup & automation

- Rented H100 on Vast.ai; uploaded 14 GB dataset (parallel chunk upload, ~9× faster)
- Phase 0: v16 baseline, confusion matrix, CVAT audit queues, threshold sweep
- Full label audit → auto-fix → built `mealybug_v20` dataset (13,664 train images)

### Training runs (revision cycle)

| Run | Config | Corrected-test mAP@0.5 | Result |
|-----|--------|------------------------:|--------|
| v20s | YOLO26s @ 1280, 80 ep, from scratch | 61.6% | Below v16 |
| v20m | YOLO26m @ 1280, 150 ep, from scratch | 63.5% | Below v16 |
| v21 | Fine-tune v16 @ 1280, 100 ep, consensus labels | 64.6% | Below v16 |
| v21m | Fine-tune v20m @ 1280, 29 ep (early stop), consensus labels | 62.2% | Below v16 |
| v22 | v16 selffix r2 (+15,954 adds), fine-tune v16, 50 ep | 64.3% | Below v16 |

### 6-model consensus labeling

| # | Model | Role | Status |
|---|-------|------|--------|
| 1 | v16 | Domain YOLO | Cached |
| 2 | v20s | Domain YOLO | Cached |
| 3 | v20m | Domain YOLO | Cached |
| 4 | GroundingDINO | Independent witness | Cached |
| 5 | OWLv2 | Independent witness | Cached |
| 6 | YOLO-World | Independent witness | Cached |

**Strict consensus pass (used for v21/v21m):**

- `add_conf=0.50`, `min_voters=3`, `--apply-remove`
- **12,182** boxes auto-added
- **34,218** boxes tightened
- **7,357** boxes removed
- **52,890** items in review queue
- Crop review (`decisions.json`) **skipped** (time constraint) — pipeline used auto-consensus labels only

### v22 selffix round 2 (11–12 June)

- Strategy: repeat v16 selffix on **original v13afix labels** (add-only, no remove/tighten) using v16 @ conf 0.45
- **+15,954** label adds on 8,317 train files (vs v16 round 1: +2,744 on 1,988 files)
- Built `mealybug_v22` dataset; fine-tuned from v16, 50 ep, lr0=0.0001
- **Result:** 64.3% mAP@0.5 — below v16; aggressive adds likely added noise

### Infrastructure & deliverables

- tmux persistence, path fixes, auto eval, full pipeline scripts (`run_v21_full_pipeline.sh`, `run_v22_selffix_pipeline.sh`)
- Backup of weights, caches, review grid, and plots to PC (`runs/h100_backup/`)
- Training graphs → `docs/thesis/assets/training_graphs/` (v20s/v20m/v21/v21m)
- **`MODEL_PERFORMANCE_ALL_VERSIONS.md`** updated through v22
- Dataset share archive for developer outreach: `datasets/mealybug_v13afix_for_training.tar.gz` (~14 GB)

### App release

- **v17.0.0+2045** release APK built (split-per-ABI); still ships **`mealybug_v16_selffix`** @ conf **0.25**
- Advisory messaging + two-tier UI included

### Pipeline status

**H100 full revision pipeline: COMPLETE** (v22 eval finished 12 June 2026, ~00:57 UTC). GPU idle.

---

## Panel guidance — point-by-point

### 1. Improve recall (priority: reduce missed detections)

| Panel ask | Addressed? | What we did |
|-----------|------------|-------------|
| Raise recall toward 78–85% | **No — target not met** | Full revision cycle completed (v21/v21m/v22); **corrected-test recall regressed** (v21 59.6%, v21m 57.1%, v22 58.3% vs v16 64.7%). |
| Accept lower precision for higher recall | **Partial** | Threshold lowered; two-tier UI (confirmed + manual-check hints). Operational P/R at deploy conf **not yet re-reported** for v16. |
| Tune threshold (0.35, 0.30, 0.25) | **Yes** | Sweep at 1280px done for v16; app uses **0.25** confirmed, **0.12** manual-check band. |

**Verdict:** Strategy aligned in UX; **benchmark recall unchanged at v16 64.7%**. All revision retraining paths tried and failed to beat v16.

---

### 2. Add more difficult-case images

| Panel ask | Addressed? |
|-----------|------------|
| Early infestation, blur, wet/dusty leaves, negatives, varieties, etc. | **Partial** |
| ≥2,500 new base photos | **Not done** |
| 510 field batch merge | **In plan** (`PLAN_TO_85_ALL_METRICS.md` Wave 2) |

**Verdict:** v20/v21/v22 used audited **existing** data; **new field collection still needed** for full panel compliance. Likely the main ceiling on further metric gains.

---

### 3. Check annotation quality

| Panel ask | Addressed? |
|-----------|------------|
| Inconsistent / loose / missed boxes | **Yes — major effort** |
| Independent audit (not self-audit) | **Yes** |

**What we did:**

- GroundingDINO audit (historical): ~49% under-annotated
- DINO fix on train (+17k boxes) → v15/v16 lineage
- v20 automated audit + auto-fix
- **6-model strict consensus** (12k adds, 34k tightens, 7k removes)
- **v22 selffix** (+15,954 adds on original labels)
- CVAT queues for human review of failure cases
- **4,000-crop review grid** prepared; human review **not completed**

**Verdict:** **Best-addressed item by effort**, but **retraining on revised labels did not improve held-out metrics**. Label revision and eval GT (v16-corrected test) were misaligned; human review of uncertain adds may still be needed.

---

### 4. Field-realistic data augmentation

| Panel ask | Addressed? |
|-----------|------------|
| Brightness, blur, rotation, etc. | **Partial** |
| Avoid unrealistic aug | **Yes** |

**Recipe (v20/v21/v21m/v22):** `hsv_h/s/v`, `degrees=10`, `translate`, `scale`, `fliplr`, `mosaic`; **`copy_paste=0`**.

**Gaps:** Explicit `blur` augmentation planned but **removed** (invalid YOLO arg / crash). Shipped **v16** predates full rotation recipe (`degrees=0` on v16). Offline field-batch aug scripts exist but not merged at scale.

**Verdict:** **Partially addressed** on revision trains; **not fully** on deployed v16.

---

### 5. Higher training image size

| Panel ask | Addressed? |
|-----------|------------|
| Test 800–1280px | **Yes** |

**Verdict:** **Done** — v16 and all revision models trained @ **1280px**. TFLite export @ 640px for mobile.

---

### 6. Compare YOLO26 model sizes

| Panel ask | Addressed? |
|-----------|------------|
| Compare n / s / m | **Partial** |

- **Done:** v20s (26s), v20m (26m), v21 (26s fine-tune), v21m (26m fine-tune), v22 (26s fine-tune) — all evaluated on corrected test
- **Not done:** YOLO26n standalone train
- **Winner:** **v16 (26s fine-tune)** — no revision model beats it

**Verdict:** Comparison **completed for s and m**; **deployment winner unchanged: v16**.

---

### 7. Report confusion cases (TP / FP / FN / poor localization)

| Panel ask | Addressed? |
|-----------|------------|
| Examples in thesis | **Yes** |

**Done:** Phase 0 confusion export; PR/P/R/F1 curves; val batch pred vs label images; `CONFUSION_CASES_V16.md`; backed up to PC.

**Verdict:** **Addressed for v16** (thesis model). Revision models documented as negative results in performance tables; no separate confusion export required unless panel requests.

---

### 8. Advisory safeguards in the app

| Panel ask | Addressed? |
|-----------|------------|
| No “plant is healthy” on negative scan | **Yes** |
| Safer negative / positive wording | **Yes** |

**Implemented in** `lib/data/detection_advisory_messages.dart`:

- **Negative:** *“No mealybug detected in this image”* + rescan / manual inspect / not final diagnosis
- **Positive:** *“Possible mealybug detected — verify visually before control measures”*
- Manual-check tier legend for low-confidence hints (0.12–0.24)

**Verdict:** **Fully addressed** in code and docs. Shipped in **app v17.0.0**.

---

## Panel metric targets vs. current state

| Metric | Panel target | v16 | Best revision (v21) | Gap (v16 vs target) |
|--------|-------------:|----:|--------------------:|--------------------:|
| mAP@0.5 | ≥85% | 73.3% | 64.6% | −11.7 pp |
| Precision | ≥80% | 80.6% ✅ | 78.1% | met (v16) |
| Recall | ≥80% | 64.7% | 59.6% | −15.3 pp |
| mAP@0.5:0.95 | ≥55% | 40.7% | 33.7% | −14.3 pp |

**Field validation at deploy threshold:** v13afix had expert F1 **91.75%** at 0.30; **no equivalent study for v16 @ 0.25 yet**.

---

## Lessons from the revision cycle

1. **Training val ≠ corrected test** — do not use epoch val metrics for panel claims.
2. **Consensus relabeling ≠ better held-out performance** — v21/v21m regressed despite cleaner-looking train labels.
3. **Corrected test is coupled to v16** — extra GT boxes come from v16 @ conf ≥ 0.45; models that drift from v16 are penalized.
4. **Train from scratch on noisy labels hurts** (v20); **fine-tune on shifted labels also hurt** (v21).
5. **Aggressive selffix adds hurt** (v22: +15,954 vs v16 r1: +2,744) — conservative label updates beat large automated adds.
6. **Best defensible model remains v16** — all GPU revision paths exhausted without beating it.

---

## What you can tell the panel now

### Already done (show evidence)

1. Accepted “promising prototype, not deployment-ready”
2. App advisory messaging — no false “healthy plant” claims (**#8**) — shipped **v17.0.0**
3. Threshold lowered + two-tier UI for recall-friendly UX (**#1 partial**)
4. Systematic annotation audit (DINO → v20 audit → 6-model strict consensus → v22 selffix) (**#3**)
5. Field-realistic augmentation on revision trains; 1280px training (**#4 partial, #5**)
6. YOLO26s and YOLO26m compared; v21/v21m/v22 fine-tunes evaluated (**#6**)
7. Confusion-case documentation and evaluation plots (**#7**)
8. **Full revision pipeline executed and reported honestly** — including negative v21/v21m/v22 results
9. **`MODEL_PERFORMANCE_ALL_VERSIONS.md`** and eval JSONs updated through v22

### Still required before “minimum deployable” claim

1. **Operational metrics at conf 0.25** (not just mAP @ conf 0.001) — threshold sweep table for v16
2. **Expert field re-validation** on v16 at deploy threshold (0.25)
3. **New hard-case field images** (≥2,500 panel ask) — not done
4. **Panel response letter / thesis tables** — incorporate final v20–v22 numbers

---

## Recommended next steps

| Priority | Step | Who | ETA |
|----------|------|-----|-----|
| 1 | Update thesis tables + panel response letter with final v20–v22 numbers | Proponents | 2–4 h |
| 2 | v16 threshold sweep @ deploy conf 0.25 on corrected test | GPU/PC | ~30 min |
| 3 | Expert re-validation @ 0.25 (reuse v13afix protocol on v16) | Field + proponents | 1–2 days |
| 4 | New hard-case field collection (≥2,500 images) | Field team | weeks |
| 5 | Share dataset archive with collaborating developers (optional) | Proponents | ready |

**Do not:** another consensus retrain, train from scratch, selffix round 3, or ship v21/v21m/v22.

**GPU revision cycle is closed** — v16 is the final model unless new field data arrives.

---

## Suggested one-paragraph for panel letter

> We accept the panel’s assessment that PINYA-PIC at v16 (73.3% mAP@0.5, 64.7% recall on the locked corrected test) is technically promising but not deployment-ready. We have implemented safer decision-support messaging (no “healthy plant” claims), lowered the operational threshold to 0.25 with a two-tier manual-check UI, exported confusion-case documentation, and executed a full data-first revision cycle: automated label audit, YOLO26s and YOLO26m training at 1280px, six-model strict consensus labeling (12,182 adds, 34,218 tightens, 7,357 removes), fine-tuned v21 (from v16) and v21m (from v20m) on consensus labels, and a second v16 selffix round (v22, +15,954 label adds). **None of the revision models exceeded v16 on the held-out corrected test** (v21: 64.6% mAP@0.5, 59.6% recall; v21m: 62.2%, 57.1%; v22: 64.3%, 58.3%). We report these results transparently and retain v16 as the deployment candidate (app v17.0.0). Remaining gaps are recall, strict localization mAP, new hard-case field imagery, and expert validation at the deploy threshold — not a lack of revision effort.

---

## Related documents

| Document | Purpose |
|----------|---------|
| `docs/thesis/PANEL_REVISION_RESPONSE_DRAFT.md` | Formal revision letter draft |
| `docs/training/PLAN_TO_85_ALL_METRICS.md` | Locked targets and wave plan |
| `docs/training/MODEL_PERFORMANCE_ALL_VERSIONS.md` | Full model history v2→v22 |
| `docs/thesis/CONFUSION_CASES_V16.md` | TP/FP/FN examples for thesis |
| `docs/thesis/SYSTEM_ARCHITECTURE.md` | App + ML stack reference |
| `datasets/mealybug_v13afix_for_training.tar.gz` | Shareable dataset archive (~14 GB) |
| `lib/data/detection_advisory_messages.dart` | App advisory copy (panel #8) |
| `lib/core/constants.dart` | Deploy threshold 0.25, manual-check 0.12 |
