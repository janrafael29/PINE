# Model metrics: v13afix only vs cross-model comparison

**Read this first:** These are **two different evaluation protocols**. The percentages are **not interchangeable** unless you label which table you used.

| Question | Use which table |
|----------|-----------------|
| “How good is **v13afix** on the data it was trained on?” | **Table 1 — v13afix native** |
| “How does v13afix compare to **v11 / v12** (and older runs)?” | **Table 2 — v10 benchmark** |
| “What headline for the **thesis final model** (v13afix)?” | Table 1 **test** row → **61.0% mAP@0.5** |
| “What headline for **model evolution** (v10 → v12 → v13afix)?” | Table 2 **test** row (same 462 images for every model) |

**Shared inference settings (both tables):** conf **0.12**, IoU **0.45**, imgsz **640**.

---

## Table 1 — v13afix only (native dataset)

**What this measures:** Performance on **mealybug_v13afix** splits — the same corpus v13afix was trained on (field + fix500 + Roboflow pool), after a **new** 70/20/10 resplit (seed 42).

**Do not** put Table 1 numbers in the same sentence as v11/v12 Table 2 numbers without saying they are different splits.

### Dataset (training & splits)

| Split | Share | Images | With boxes | Empty | Box instances |
|-------|------:|-------:|-----------:|------:|--------------:|
| **Train** | 70% | **13,664** | 11,630 | 2,034 | 105,345 |
| Val | 20% | 3,904 | 3,343 | 561 | 30,781 |
| **Test** | 10% | **1,952** | 1,656 | 296 | 14,124 |
| **Total** | 100% | 19,520 | — | — | — |

**Training:** YOLO26n, from v12, 75 epochs, batch 16, imgsz 640 on `datasets/mealybug_v13afix/`.

### Metrics (native val / test only)

Source: `runs/calibration/mealybug_v13afix_native_eval.json`

| Split | Images | Precision | Recall | **F1** | **mAP@0.5** | mAP@0.5:0.95 |
|-------|-------:|----------:|-------:|-------:|------------:|-------------:|
| Val | 3,904 | 71.2% | 57.7% | 63.8% | **59.6%** | 28.4% |
| **Test** | **1,952** | **72.8%** | **58.9%** | **65.1%** | **61.0%** | **29.2%** |

**Suggested thesis wording (Table 1):**  
*“On the held-out native test set (1,952 images, 10% of the v13afix corpus), v13afix achieved 61.0% mAP@0.5 at confidence 0.12.”*

---

## Table 2 — Cross-model comparison (fixed v10 benchmark)

**What this measures:** Every model scored on the **same** Roboflow v10 export holdout — **923 val** / **462 test** — so rows are directly comparable.

**Caveat for v13afix:** v13afix was trained on a **reshuffled** pool (`mealybug_v13afix`). Some v10 test images may appear in v13afix **train**. Use Table 2 for **relative** ranking vs v11/v12, not as a strict “unseen forever” holdout for v13afix.

Source: `runs/calibration/model_comparison_eval.json` (v2–v12) + `runs/calibration/accuracy_report.json` (v13afix).

### Test split (462 images) — primary comparison

| Model | Trained on | Precision | Recall | **F1** | **mAP@0.5** | mAP@0.5:0.95 |
|-------|------------|----------:|-------:|-------:|------------:|-------------:|
| v2 | Legacy ~2.3k (`datasets/`) | 41.1% | 38.6% | 39.8% | 21.1% | 7.8% |
| v10 | v10 (~16k aug train) | 55.7% | 49.4% | 52.4% | 42.1% | 16.7% |
| v11 | v10 (cleaned labels) | 56.2% | 49.2% | 52.5% | 43.0% | 16.8% |
| v12 | v10 @ 1024 train | **58.6%** | **51.3%** | **54.7%** | **43.8%** | 16.9% |
| **v13afix** | **v13afix (13,664 train)** | **64.3%** | **59.7%** | **61.9%** | **56.7%** | 24.6% |

### Val split (923 images)

| Model | Precision | Recall | **F1** | **mAP@0.5** | mAP@0.5:0.95 |
|-------|----------:|-------:|-------:|------------:|-------------:|
| v2 | 34.6% | 29.0% | 31.6% | 15.0% | 4.9% |
| v10 | 62.1% | 49.7% | 55.2% | 45.7% | 19.7% |
| v11 | 62.3% | 50.4% | 55.8% | 47.4% | 20.2% |
| v12 | 62.3% | 49.0% | 54.9% | 45.8% | 19.7% |
| **v13afix** | **62.3%** | **55.0%** | **58.4%** | **50.9%** | 23.3% |

**Suggested thesis wording (Table 2):**  
*“On the fixed 462-image Roboflow v10 test set (conf 0.12), v13afix reached 56.7% mAP@0.5 versus 43.8% for v12 and 43.0% for v11.”*

---

## Side-by-side: v13afix on both protocols

Same model, **different test sets** — higher native % does **not** mean Table 2 is wrong; different images and split rules.

| Protocol | Test images | Test mAP@0.5 | Test F1 | Use when |
|----------|------------:|-------------:|--------:|----------|
| **Native (Table 1)** | 1,952 | **61.0%** | 65.1% | Final model / v13afix-only chapter |
| **v10 benchmark (Table 2)** | 462 | **56.7%** | 61.9% | Compare to v10, v11, v12 |

---

## One-page cheat sheet

```
TABLE 1 (v13afix only)          TABLE 2 (all models)
──────────────────────          ──────────────────────
Dataset: mealybug_v13afix       Dataset: Roboflow v10 export
Test: 1,952 images              Test: 462 images (fixed)
v13afix test mAP@0.5: 61.0%     v13afix test mAP@0.5: 56.7%
                                v12 test mAP@0.5:     43.8%
                                v11 test mAP@0.5:     43.0%
```

---

## Regenerate

```powershell
# Table 1 — v13afix native
python scripts/evaluate_model_accuracy.py `
  --model runs/retrain/mealybug_v13afix/weights/best.pt `
  --data datasets/mealybug_v13afix/data.yaml --conf 0.12 `
  --out runs/calibration/mealybug_v13afix_native_eval.json

# Table 2 — v13afix on v10 benchmark (add other --model lines for full table)
python scripts/evaluate_model_accuracy.py `
  --model runs/retrain/mealybug_v13afix/weights/best.pt `
  --data mealybug.v10-8th-yolo26n.yolo26/data.yaml --conf 0.12 `
  --out runs/calibration/accuracy_report.json
```
