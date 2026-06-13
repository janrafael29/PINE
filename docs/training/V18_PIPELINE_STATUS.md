# V18 Pipeline Status

**Updated:** 2026-06-10 (evening)  
**H100:** `root@219.86.90.208` port `40050`  
**Work log:** `docs/work_logs/June 10 work log.md`

---

## Current state

| Step | Status |
|------|--------|
| wave1 bundle upload (`v18_wave1_bundle.zip`, ~768 MB) | ✅ |
| Phase 0 (`v18_wave1_day1_vast.sh`) | ✅ Mostly — see notes below |
| Full pipeline (`v18_full_pipeline_vast.sh`, `SKIP_PHASE0=1`) | 🔄 |
| Wave 1 — audit + auto-fix → `mealybug_v20_audit` | ✅ |
| Wave 2 — build `mealybug_v20` | ✅ |
| Wave 3a — **train v20s** (YOLO26s @ 1280) | 🔄 Started 2026-06-10 ~14:34 UTC |
| Wave 3b — train v20m (YOLO26m) | ⬜ After v20s |
| M1/M3 eval on corrected test | ⬜ After training |

**Shipped app model:** still `mealybug_v16_selffix` until v20 passes promotion gates.

---

## Phase 0 notes

| Output | Status |
|--------|--------|
| Confusion export (1,952 images) | ✅ `docs/thesis/assets/confusion_cases_v16/` |
| CVAT queues (full test) | ✅ `runs/audit/cvat_queues/` |
| CVAT import packages Q1–Q3 top-50 | ✅ `datasets/cvat_import/` |
| Baseline JSON @ 1280 | ⚠️ First capture **0% mAP** (`no labels found` on instance) — re-run with fixed label paths before trusting JSON |
| Threshold sweep @ 1280 | ⬜ Confirm on instance / download when complete |

---

## Monitor (SSH)

```bash
ssh -i ~/.ssh/vast_ed25519 -p 40050 root@219.86.90.208
tail -f /workspace/pine/runs/v18_pipeline/pipeline.log
# or v20s train log:
tail -f /workspace/pine/runs/retrain/mealybug_v20s/train.log
```

---

## Download results to PC

```powershell
$key = "$env:USERPROFILE\.ssh\vast_ed25519"
$ip = "219.86.90.208"
$port = 40050

scp -i $key -P $port -r root@${ip}:/workspace/pine/docs/thesis/assets/v18_baseline D:\old_PINE\docs\thesis\assets\
scp -i $key -P $port -r root@${ip}:/workspace/pine/docs/thesis/assets/confusion_cases_v16 D:\old_PINE\docs\thesis\assets\
scp -i $key -P $port -r root@${ip}:/workspace/pine/runs/audit/cvat_queues D:\old_PINE\runs\audit\
scp -i $key -P $port -r root@${ip}:/workspace/pine/datasets/cvat_import D:\old_PINE\datasets\
scp -i $key -P $port -r root@${ip}:/workspace/pine/runs/retrain/mealybug_v20s D:\old_PINE\runs\retrain\
```

---

## PC housekeeping (2026-06-10)

| Item | Status |
|------|--------|
| Project disk **124 GB → ~39 GB** | ✅ `scripts/slim_project_retention.ps1` |
| Superseded datasets archived | ✅ `D:\PINE_ML_ARCHIVE\` |
| Comparison `best.pt` + calibration JSON kept | ✅ |
| Thesis stack doc | ✅ `docs/thesis/SYSTEM_ARCHITECTURE.md` |

---

## Key scripts

| Script | Role |
|--------|------|
| `v18_wave1_day1_vast.sh` | Phase 0: baseline, confusion, CVAT queues, threshold sweep |
| `v18_full_pipeline_vast.sh` | Wave 1–3: audit → v20 dataset → v20s + v20m train |
| `slim_project_retention.ps1` | Disk cleanup without losing comparison weights |
| `package_train_for_vast.ps1` | Zip train set for upload (if instance lacks train data) |

**Training log (v20):** `docs/V20_TRAINING_LOG.md`
