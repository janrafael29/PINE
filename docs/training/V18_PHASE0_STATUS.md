# V18 Phase 0 — Status

**Started:** 2026-05-29  
**Phase 0 GPU run:** 2026-06-10 (Vast H100)  
**Track:** Full plan (Track A)

---

## Completed

| Task | Status | Artifact |
|------|--------|----------|
| **0.1** Archive v16 weights | ✅ | `runs/retrain/mealybug_v16_selffix/weights/best.pt` (archive copy removed during disk cleanup; weights retained) |
| **0.2** Corrected test labels | ✅ | `datasets/mealybug_v13afix/test/labels_v16_corrected/` (1,952 files) |
| **0.2** Eval staging | ✅ | `runs/calibration/data_v16_corrected_test.yaml` |
| **0.2** Baseline capture script | ✅ | `scripts/capture_v16_baseline.py`, `scripts/label_eval_utils.py` |
| **0.3** Confusion export @ 1952 | ✅ | `docs/thesis/assets/confusion_cases_v16/`, `CONFUSION_CASES_V16.md` |
| **Day 1** CVAT queues (full test) | ✅ | `runs/audit/cvat_queues/` (Vast, 2026-06-10) |
| **Day 1** CVAT import packages | ✅ | `datasets/cvat_import/Q1_*`, `Q2_*`, `Q3_*` |
| **0.4** CVAT setup guide | ✅ | `docs/training/V18_CVAT_AUDIT_SETUP.md` |
| **0.5** Panel response draft | ✅ | `docs/thesis/PANEL_REVISION_RESPONSE_DRAFT.md` |
| **0.6** GPU runbook | ✅ | `docs/training/V18_VAST_CONNECT.md` |
| **Thesis architecture doc** | ✅ | `docs/thesis/SYSTEM_ARCHITECTURE.md` (2026-06-10) |

---

## Remaining / verify

| Task | Status | Notes |
|------|--------|-------|
| **0.2** Baseline repro @ 1280 → **73.3%** | ⚠️ | JSON written but first Vast run reported **0%** (label path); re-run before thesis cite |
| **0.2** Threshold sweep @ 1280 | ⬜ | Queued in Phase 0 script — confirm + download |
| **Human** CVAT Q1 import + FN review | ⬜ | Start with `Q1_false_negatives_top50/` |

---

## Headline baseline (authoritative until GPU repro confirms)

| Metric | Value |
|--------|------:|
| mAP@0.5 | 73.3% |
| Precision | 80.6% |
| Recall | 64.7% |
| mAP@0.5:0.95 | 40.7% |

**Protocol:** corrected test labels, conf=0.001, IoU=0.6, imgsz=1280

---

## Phase 0 exit checklist

- [x] Weights archived / retained
- [x] Corrected labels exist
- [x] Confusion export @ full test set
- [x] CVAT queues + top-50 packages
- [ ] Baseline JSON matches 73.3% ± 0.5 pp
- [ ] Threshold sweep @ 1280 saved locally

**Next:** Wave 1–3 already started on H100 (`v20s` training). Human CVAT review runs in parallel. See `V18_PIPELINE_STATUS.md`.
