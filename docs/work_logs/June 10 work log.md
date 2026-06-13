# Work log — 10 June 2026

Covers **V18 Phase 0 on Vast H100**, **v20s training start**, **project disk cleanup**, **thesis system architecture doc**, and **panel/training planning notes**.

**Stack reminder:** Flutter (Android), **YOLO26s** → **TFLite** (`mealybug_v16_selffix`), Supabase, Ultralytics on **Vast.ai H100**. Shipped app model remains **v16** until v20 passes promotion gates.

---

## 1) V18 GPU pipeline — H100 instance live

**Instance:** `root@219.86.90.208` port `40050` (Vast.ai, H100 SXM)

| Step | Status | Notes |
|------|--------|-------|
| Upload `v18_wave1_bundle.zip` (~768 MB) | ✅ | Test images + v16 weights + scripts |
| Fix missing weights/scripts on instance (scp) | ✅ | Baseline could run after upload |
| Run `v18_wave1_day1_vast.sh` (Phase 0) | ✅ / ⚠️ | See §2 |
| Upload + start `v18_full_pipeline_vast.sh` | ✅ | `SKIP_PHASE0=1` — Phase 0 already done |
| Wave 1 — audit + auto-fix → `mealybug_v20_audit` | ✅ | ~13:56–14:34 UTC |
| Wave 2 — build `mealybug_v20` dataset | ✅ | ~14:34 UTC |
| Wave 3a — **train v20s** (YOLO26s @ 1280) | 🔄 | Started ~14:34 UTC; healthy val curve by ep ~12 (~50% mAP@0.5) |
| Wave 3b — train v20m | ⬜ | Queued after v20s |
| M1/M3 eval on corrected test | ⬜ | After training |

**Monitor:** `tail -f /workspace/pine/runs/v18_pipeline/pipeline.log` or `runs/v18_pipeline/nohup.log`

**Status doc:** `docs/training/V18_PIPELINE_STATUS.md`

---

## 2) Phase 0 results (baseline + audit prep)

Ran via `scripts/v18_wave1_day1_vast.sh`:

| Output | Status | Notes |
|--------|--------|-------|
| `docs/thesis/assets/v18_baseline/v16_corrected_test_metrics.json` | ⚠️ | First run **0% mAP** — `no labels found in detect set` (label path on instance); re-run with fixed paths planned (`TONIGHT_RUNBOOK.md`) |
| `docs/thesis/assets/confusion_cases_v16/` | ✅ | Full export; 8 samples/class; `CONFUSION_CASES_V16.md` regenerated |
| `runs/audit/cvat_queues/` | ✅ | Full 1,952-image scan @ conf 0.25 |
| `datasets/cvat_import/Q1–Q3_*_top50/` | ✅ | Ready for CVAT import |
| `runs/calibration/threshold_sweep_v16_1280.json` | ⬜ / 🔄 | Per runbook — next in queue or completed overnight |

**Top FN from earlier sample:** `test_000116.jpg` (86 missed boxes).

---

## 3) v20 training strategy (today’s direction)

**Change from v17/v18/v19:** Stop fine-tuning v16 with more epochs. Instead:

1. **Audit + auto-fix** training labels → `mealybug_v20_audit`
2. **Build** `mealybug_v20` dataset
3. **Train from scratch:** YOLO26s (`mealybug_v20s`) then YOLO26m (`mealybug_v20m`) @ **1280px**
4. Eval on **same corrected test** (1,952 images, conf 0.001, IoU 0.6) vs v16 **73.3%**

**v21 queued:** multi-model consensus labels (v16 + v20 + GroundingDINO + OWLv2 + YOLO-World) — documented in `MODEL_PERFORMANCE_ALL_VERSIONS.md`.

---

## 4) Project disk cleanup (~124 GB → ~39 GB)

Analyzed project folder size; removed regenerable bulk while **keeping all comparison `best.pt` weights** and paper artifacts.

| Action | ~Freed | Details |
|--------|-------:|---------|
| Prune epoch checkpoints | **7.7 GB** | `scripts/slim_project_retention.ps1 -Phase Checkpoints`; v19 had 102 `.pt` files |
| Remove staging / backups / root zips | **~58 GB** | `vast_upload/` (mostly), `roboflow_upload/`, `build/`, `datasets.bak.*`, `*.zip` |
| Archive superseded datasets | **16.2 GB** | Moved to `D:\PINE_ML_ARCHIVE\` (`mealybug_v10_plus_annotations`, `mealybug_merged_*`) |
| `flutter clean` | small | Android intermediates |

**Kept for training + comparison:**

- `datasets/mealybug_v13afix/` (canonical train + corrected test)
- `datasets/mealybug_va_field/`, `mealybug.v10-8th-yolo26n.yolo26/`
- `runs/retrain/*/weights/best.pt`, `runs/calibration/*.json`
- `docs/thesis/assets/`

**Leftover:** `vast_upload/v18_wave1_bundle.zip` was locked during active `scp` — delete folder after upload completes.

**New script:** `scripts/slim_project_retention.ps1` (Checkpoints / Staging / Datasets archive phases).

---

## 5) Documentation added / updated

| Doc | Purpose |
|-----|---------|
| `docs/thesis/SYSTEM_ARCHITECTURE.md` | **New** — thesis-ready stack tables + Mermaid diagrams (mobile + Supabase + ML pipeline; **no admin panel**) |
| `docs/training/V18_PIPELINE_STATUS.md` | H100 run status |
| `docs/training/TONIGHT_RUNBOOK.md` | Short overnight checklist |
| `docs/training/MODEL_PERFORMANCE_ALL_VERSIONS.md` | Updated v20 in-progress + v21 plan |
| `docs/thesis/CONFUSION_CASES_V16.md` | Regenerated on Vast (2026-06-10) |

**Planning notes (chat):** Simplified English summary of v18 plan — Phase 0 now, no new train until label audit; M1/M2/M3 gates; panel one-liner.

---

## 6) Scripts touched

| Script | Change |
|--------|--------|
| `scripts/slim_project_retention.ps1` | **New** — disk retention without losing comparison weights |
| `scripts/v18_wave1_day1_vast.sh` | Used on H100 (unchanged) |
| `scripts/v18_full_pipeline_vast.sh` | Used with `SKIP_PHASE0=1` |

---

## 7) Open items (carry forward)

- [ ] **Re-run v16 baseline** on H100 with corrected label paths → confirm **73.3%** in `v18_baseline/v16_corrected_test_metrics.json`
- [ ] **Download** Phase 0 outputs from Vast to PC (`scp` paths in `V18_VAST_CONNECT.md`)
- [ ] **CVAT import** — `datasets/cvat_import/Q1_false_negatives_top50/` → start FN review
- [ ] **Monitor v20s** training; run M1 eval when `best.pt` ready
- [ ] **v20m** train + M3 gate (≥85% mAP@0.5 stretch / ≥78% realistic M1)
- [ ] **Delete** leftover `vast_upload/` after bundles uploaded
- [ ] **Package** `pine_v13afix_train_bundle.zip` if full train set needed on instance (may already be on Vast from prior runs)

---

## 8) Time / resource summary

| Resource | Today |
|----------|-------|
| **GPU (Vast H100)** | Phase 0 + Wave 1–2 + v20s train started (~afternoon UTC) |
| **Disk reclaimed (PC)** | ~85 GB (124 → 39 GB project folder) |
| **Human** | Vast upload/monitor; disk cleanup; doc review |

---

*End of work log — 10 June 2026.*
