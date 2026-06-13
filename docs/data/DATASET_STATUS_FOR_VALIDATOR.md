# PINYA-PIC dataset status (validator brief)

*Generated 2026-05-23 from automated counts on `D:\old_PINE`.*

## Summary

Single-class **YOLO bounding-box** detection (`mealybug`, class 0). **Not** segmentation in the shipped app. Boxing rules: `docs/data/BOXING_GUIDELINES.md`.

**Benchmark for model comparison:** `mealybug.v10-8th-yolo26n.yolo26` — fixed **462** test images. Do **not** use `mealybug_v13afix` test (1,952) for published metrics.

---

## Dataset inventory

| Dataset | Train | Valid | Test | Box instances (train) | Notes |
|---------|------:|------:|-----:|----------------------:|-------|
| **v10 (Roboflow benchmark)** | 16,175 | 923 | 462 | 122,508 | Cleaned 2026-05-19; 1,573 train empties |
| **v10_plus** | 17,052 | 923 | 462 | 126,994 | +877 train images; val/test unchanged |
| **v13afix (current train)** | 13,664 | 3,904 | 1,952 | 105,345 | 70/20/10 resplit, seed 42; all detect labels |
| **datasets/ (legacy)** | 3,621 | 914 | 460 | 33,191 | Roboflow v7 metadata |
| **va_field** | 613 | 131 | 133 | — | Field-only subset |

### v13afix label breakdown

| Split | Images | Empty labels | With boxes | Instances |
|-------|-------:|-------------:|-----------:|----------:|
| Train | 13,664 | 2,034 | 11,630 | 105,345 |
| Valid | 3,904 | 561 | 3,343 | 30,781 |
| Test | 1,952 | 296 | 1,656 | 14,124 |

All label lines are **5-field detection** format (no polygon lines remaining). Built via `scripts/build_v13afix_dataset.py`; report: `datasets/mealybug_v13afix/build_v13afix_report.json`.

---

## Human review status

| Set | Images | Status |
|-----|-------:|--------|
| **fix500** (`fix_sets/fix500_20260520/`) | 500 (+501 reviewed labels) | CVAT review **done**; in v13afix pipeline |
| **Field May 2025** (`field_batches/2026-05-21_...`) | 510 (113 with boxes, 397 empty pre-labels) | CVAT review **in progress**; **not** merged to v10/v13 |
| **Validation holdout** (`field_staging/..._for_validation/`) | 139 | Held out of auto-label |
| **Re-annotate 4k** (`labeling_system/`) | 50 in queue | Pilot only |

**Not in `datasets/train` by filename:** no `fix_*` or field-batch stems — fix500/field content enters via `build_v13afix` / `v10_plus`, not the legacy `datasets/train` folder.

---

## v10 cleanup (2026-05-19)

On full v10 export: 8,681 polygon→box, 3,925 tiny dropped, 1,894 huge dropped. See `docs/data/LABEL_CLEANUP_V10.md`.

---

## Model benchmark (v10 test, conf=0.12)

Best mAP@0.5: **fix500 45.3%**; app ships **v11** (43.0%). See `docs/training/MODEL_COMPARISON_ALL_RETRAINS.md`.

---

## Validator priorities

1. Tight **one pest per box** on v10 test sample + fix500 reviewed set  
2. **Empty labels** = true negatives (especially field batch)  
3. **Small pests** not lost in cleanup drops  
4. Use **v10 test (462)** only for comparable metrics  
