# V18 — Today’s Completion Checklist

**Date:** 2026-05-29  
**Goal:** Ship everything we can finish locally today; queue GPU/human work clearly.

---

## Done today (local / code)

| # | Deliverable | Status | Location |
|---|-------------|--------|----------|
| 1 | Advisory messaging (#8) | ✅ | `lib/data/detection_advisory_messages.dart` |
| 2 | Deploy threshold 0.25 | ✅ | `lib/core/constants.dart` |
| 3 | Two-tier UI (confirmed + manual-check overlay) | ✅ | `lib/utils/detection_tiers.dart`, `lib/widgets/detection_markers_painter.dart`, `lib/screens/permission_screens.dart` |
| 4 | Inference floor 0.12 (balanced/accuracy presets) | ✅ | `lib/core/config.dart` |
| 5 | Save only confirmed tier (≥0.25) | ✅ | `PhotoResultScreen._saveDetection` |
| 6 | Confusion export script + thesis draft (#7) | ✅ | `scripts/export_confusion_cases.py`, `docs/thesis/CONFUSION_CASES_V16.md` |
| 7 | CVAT queue builder + Q1–Q3 top-50 packages | ✅ | `datasets/cvat_import/Q1_*`, `Q2_*`, `Q3_*` |
| 8 | `--package-only` repackage from CSVs | ✅ | `scripts/build_cvat_audit_queues.py` |
| 9 | Flutter tests pass | ✅ | `test/core/`, `test/utils/detection_tiers_test.dart` |
| 10 | Release APK | 🔄 | `build/app/outputs/flutter-apk/app-release.apk` |
| 11 | Quick threshold sweep @ 640 | 🔄 | `runs/calibration/threshold_sweep_v16_640_quick.json` |
| 12 | Confusion export (full 1,952 imgs) | ✅ | `docs/thesis/assets/confusion_cases_v16/` (Vast 2026-06-10) |
| 9 | Phase 0 / Day 1 runbooks | ✅ | `scripts/v18_wave1_day1_vast.sh`, `V18_PHASE0_RUN_ON_VAST.md` |
| 10 | Path to 85% plan | ✅ | `docs/training/PLAN_TO_85_ALL_METRICS.md` |

---

## Your action now (human, ~30 min)

1. **CVAT** — create project `PINYA-PIC v18_audit`, task `Q1_FN_top50`
2. Upload `datasets/cvat_import/Q1_false_negatives_top50/images/`
3. Optional pre-labels: `.../labels/`
4. Guide: `docs/training/V18_CVAT_AUDIT_SETUP.md`

Also import:

- `datasets/cvat_import/Q2_poor_localization_top50/`
- `datasets/cvat_import/Q3_false_positives_top50/`

---

## GPU on Vast (one command)

```bash
cd /workspace && bash scripts/v18_wave1_day1_vast.sh
```

Downloads back to PC:

- `docs/thesis/assets/v18_baseline/v16_corrected_test_metrics.json`
- `docs/thesis/assets/confusion_cases_v16/` (full 1,952-image export)
- `runs/audit/cvat_queues/` (full queues)
- `datasets/cvat_import/Q1–Q3_*_top50/`

---

## Rebuild APK (demo)

```powershell
cd D:\old_PINE
flutter test test/core/config_test.dart test/utils/detection_tiers_test.dart
flutter build apk --release
```

---

## Cannot finish in one day (honest scope)

| Item | Why | Next gate |
|------|-----|-----------|
| mAP@0.5 ≥ 85% | Needs v20 data + retrain (weeks) | M1 after CVAT audit |
| R ≥ 80% | Same | Wave 2–3 training |
| mAP@0.5:0.95 ≥ 55% | Needs larger model + tight boxes | v20m + localization pass |
| Expert re-validation ≥50 images | Human panel task | After CVAT Q1 |

**Today’s win:** deployment-safe messaging, two-tier recall UI, audit packages, and a locked GPU runbook for baseline + full confusion + threshold sweep.
