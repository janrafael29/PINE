# V18 Wave 1 — Day 1 Status

**Updated:** 2026-06-10  
**Plan:** `PLAN_TO_85_ALL_METRICS.md`  
**Pipeline:** `V18_PIPELINE_STATUS.md`

---

## Completed

| Task | Status | Output |
|------|--------|--------|
| Advisory messaging (#8) | ✅ | `lib/data/detection_advisory_messages.dart` |
| Deploy threshold 0.25 + two-tier UI | ✅ | `constants.dart`, `detection_tiers.dart`, `detection_markers_painter.dart` |
| Save only confirmed tier | ✅ | `permission_screens.dart` |
| CVAT queue script | ✅ | `scripts/build_cvat_audit_queues.py` |
| CVAT packages Q1 + Q2 + Q3 top-50 | ✅ | `datasets/cvat_import/` |
| Flutter unit tests | ✅ | `config_test.dart`, `detection_tiers_test.dart` |
| Confusion export (full 1,952 @ 1280) | ✅ | `docs/thesis/assets/confusion_cases_v16/` (Vast, 2026-06-10) |
| Full CVAT queues | ✅ | `runs/audit/cvat_queues/` (Vast) |
| Phase 0 GPU run | ✅ | `v18_wave1_day1_vast.sh` on H100 |
| v20 dataset + v20s train started | ✅ | `v18_full_pipeline_vast.sh` (2026-06-10) |

### Queue scan summary (150-image local sample, imgsz 640)

| Metric | Count |
|--------|------:|
| Images with FN | 148 |
| Images with FP | 86 |
| Images with poor IoU | 63 |

**Top FN image:** `test_000116.jpg` — 86 missed boxes

---

## Your action now (human)

1. **CVAT** — project `PINYA-PIC v18_audit`
2. Import **Q1** → **Q2** → **Q3** from `datasets/cvat_import/` (download from Vast if needed)
3. Guide: `docs/training/V18_CVAT_AUDIT_SETUP.md`

---

## GPU (Vast H100)

**Running:** `mealybug_v20s` training — monitor:

```bash
ssh -i ~/.ssh/vast_ed25519 -p 40050 root@219.86.90.208
tail -f /workspace/pine/runs/v18_pipeline/pipeline.log
```

**Pending verify:** baseline JSON @ 73.3%, threshold sweep @ 1280.

---

## Next gates

| Gate | Requirement |
|------|-------------|
| M1 | v20s: mAP@0.5 ≥78%, R ≥70%, mAP@0.5:0.95 ≥45% |
| M3 | v20m: panel targets in `PLAN_TO_85_ALL_METRICS.md` |
