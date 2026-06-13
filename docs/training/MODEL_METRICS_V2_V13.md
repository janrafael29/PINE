# Model metrics: v2 → v13afix

**Eval settings (all tables below unless noted):** conf **0.12**, IoU **0.45**, imgsz **640**, YOLO26n.

**Note:** There are **no v3–v9** checkpoints in this repo. The lineage is **v2 → v10 → v11 → v12 → v13afix** (plus side runs **fix500**, **v10a**, **va**).

---

## A. Fair comparison — fixed v10 benchmark (use for v2–v13 ranking)

**Dataset:** `mealybug.v10-8th-yolo26n.yolo26` — **923 val** / **462 test** (same images for every row).

| Model | Trained on | Val P | Val R | Val F1 | Val mAP@0.5 | Test P | Test R | Test F1 | **Test mAP@0.5** |
|-------|------------|------:|------:|-------:|--------------:|-------:|-------:|--------:|-----------------:|
| **v2** | Legacy `datasets/` (~2.3k) | 34.6% | 29.0% | 31.6% | 15.0% | 41.1% | 38.6% | 39.8% | **21.1%** |
| **fix500** | fix500 subset (side run) | 52.7% | 46.6% | 49.5% | 37.8% | 57.9% | 51.5% | 54.5% | **45.3%** |
| **v10** | v10 (~16k aug train) | 62.1% | 49.7% | 55.2% | 45.7% | 55.7% | 49.4% | 52.4% | **42.1%** |
| **v10a** | v10 + Va field (side run) | 62.5% | 50.9% | 56.1% | 48.0% | 57.9% | 50.9% | 54.2% | **43.9%** |
| **v11** | v10 cleaned labels | 62.3% | 50.4% | 55.8% | 47.4% | 56.2% | 49.2% | 52.5% | **43.0%** |
| **v12** | v10 @ 1024 train (**shipped TFLite**) | 62.3% | 49.0% | 54.9% | 45.8% | 58.6% | 51.3% | 54.7% | **43.8%** |
| **v13afix** | v13afix pool (13,664 train) | 62.3% | 55.0% | 58.4% | 50.9% | 64.3% | 59.7% | 61.9% | **56.7%** |

**Test mAP@0.5 progression (headline):** 21.1% → 42.1% → 43.0% → 43.8% → **56.7%** (v2 → v10 → v11 → v12 → v13afix).

Sources: `runs/calibration/model_comparison_eval.json`, `all_retrains_eval.json`, `mealybug_v12_eval.json`, `accuracy_report.json`.

**v13afix caveat:** Training used a **reshuffled** 19.5k pool; some v10 test images may be in v13afix train. Use this table for **relative** improvement vs v12, not as a strict unseen holdout for v13afix.

---

## B. v13afix only — native benchmark (final model chapter)

**Dataset:** `datasets/mealybug_v13afix` — **3,904 val** / **1,952 test** (70/20/10 resplit, 19,520 total).

| Split | Images | P | R | F1 | **mAP@0.5** |
|-------|-------:|--:|--:|---:|------------:|
| Val | 3,904 | 71.2% | 57.7% | 63.8% | **59.6%** |
| **Test** | **1,952** | **72.8%** | **58.9%** | **65.1%** | **61.0%** |

Source: `runs/calibration/mealybug_v13afix_native_eval.json`.

**Do not** compare 61.0% (native test) to 43.8% (v12 on 462 images) without explaining different splits.

---

## C. Training summary

| Model | Start from | Train data | Epochs (cfg) | Batch | Train imgsz | Role |
|-------|------------|------------|-------------:|------:|--------------:|------|
| v2 | YOLO11n→26n | `datasets/` | 50 | 1 | 640 | Legacy baseline |
| fix500 | v11 | fix500 merge | — | — | 640 | Side experiment |
| v10 | v2 | v10 YAML | 100 | 16 | 640 | First 17k-scale |
| v10a | v10 | v10 + field | — | — | 640 | Field aug trial |
| v11 | v10 | v10 cleaned | 50 → 16 ran | 16 | 640 | Prior app ship |
| v12 | v11 | v10 YAML | 200 | 8 | **1024** | Current shipped TFLite |
| **v13afix** | v12 | v13afix YAML | 80 → 75 ran | 16 | 640 | Latest / thesis candidate |

---

## D. mAP@0.5:0.95 (test, v10 benchmark)

| Model | Test mAP@0.5:0.95 |
|-------|------------------:|
| v2 | 7.8% |
| v10 | 16.7% |
| v11 | 16.8% |
| v12 | 16.9% |
| v13afix | **24.6%** |

---

## E. Which number to cite

| Audience | Metric |
|----------|--------|
| Model evolution (v2→v13) | **Test mAP@0.5** on **462-image v10 test** (Table A) |
| Final v13afix model only | **Test mAP@0.5 = 61.0%** on **1,952-image native test** (Table B) |
| Mobile app after scan | **Confidence %** (not mAP) |

See also: `docs/training/MODEL_METRICS_V13AFIX_AND_COMPARISON.md`, `docs/training/MODEL_COMPARISON_V2_V10_V11_V12.md`.
