# Model comparison: v2 vs v10 vs v11 vs v12

**Generated:** 2026-05-22  
**Fair benchmark source:** `runs/calibration/model_comparison_eval.json` (v2, v10, v11) + `runs/calibration/mealybug_v12_eval.json` (v12)

---

## Fair benchmark (same dataset, same inference settings)

All models evaluated on **`mealybug.v10-8th-yolo26n.yolo26/data.yaml`** (Roboflow v10: ~16k aug train / **923 val** / **462 test**).

| Setting | Value |
|---------|--------|
| **conf** | 0.12 |
| **IoU** | 0.45 |
| **imgsz (eval)** | 640 |

> **Note on v2:** v2 was **trained** on legacy `datasets/` (~2.3k). Numbers below are **v2 weights tested on the v10 split** — they are fair for “how old weights generalize to 17k,” not for v2’s historical ~65% training val mAP.

### Test split (primary holdout)

| Model | Role | Precision | Recall | **F1** | **mAP@0.5** | mAP@0.5:0.95 |
|-------|------|----------:|-------:|-------:|------------:|-------------:|
| **v2** | Legacy baseline (`datasets/` train) | 41.1% | 38.6% | 39.8% | 21.1% | 7.8% |
| **v10** | Full 17k Roboflow train (Vast) | 55.7% | 49.4% | 52.4% | 42.1% | 16.7% |
| **v11** | Fine-tune v10 + cleaned labels (prior app ship) | 56.2% | 49.2% | 52.5% | 43.0% | 16.8% |
| **v12** | Fine-tune v11 @ **1024** train, 200 epochs (**shipped app**) | **58.6%** | **51.3%** | **54.7%** | **43.8%** | 16.9% |

### Val split

| Model | Precision | Recall | **F1** | **mAP@0.5** | mAP@0.5:0.95 |
|-------|----------:|-------:|-------:|------------:|-------------:|
| **v2** | 34.6% | 29.0% | 31.6% | 15.0% | 4.9% |
| **v10** | 62.1% | 49.7% | 55.2% | 45.7% | 19.7% |
| **v11** | **62.3%** | **50.4%** | **55.8%** | **47.4%** | **20.2%** |
| **v12** | 62.3% | 49.0% | 54.9% | 45.8% | 19.7% |

### Quick takeaways (fair benchmark @ conf 0.12)

| Comparison | Test mAP@0.5 | Test F1 |
|------------|-------------:|--------:|
| v10 → v11 | 42.1% → 43.0% (**+0.9 pp**) | 52.4% → 52.5% |
| v11 → v12 | 43.0% → 43.8% (**+0.8 pp**) | 52.5% → 54.7% |
| v2 → v11 | 21.1% → 43.0% (**+21.9 pp**) | 39.8% → 52.5% |

- **v12** improves **test precision / recall / F1** vs v11 at the same eval conf, with a small **test mAP@0.5** gain (+0.8 pp).
- **v12 val mAP@0.5** is slightly **below** v11 (45.8% vs 47.4%) — treat **test** as the headline for v12 vs v11 unless you re-run a unified 4-model eval in one script.

---

## Training configuration (how each checkpoint was produced)

| Model | Start weights | Train data | Epochs (configured → ran) | Batch | Train **imgsz** | Optimizer / notes |
|-------|---------------|------------|---------------------------|------:|----------------:|-------------------|
| **v2** | YOLO11n → YOLO26n | `datasets/` (~2.3k train) | 50 + resume (~99 total) | **1** | **640** | 4 GB laptop; AMP; val OOM patches |
| **v10** | `mealybug_v2/best.pt` | v10 YAML (~16k train aug) | **100** (patience 20) | **16** | **640** | Vast GPU |
| **v11** | `mealybug_v10/best.pt` | v10 YAML (cleaned labels) | **50** → **16** (patience **15**) | **16** | **640** | Vast fine-tune |
| **v12** | `mealybug_v11/best.pt` | v10 YAML | **200** → **200** (patience **0**) | **8** | **1024** | AdamW, cos LR, dropout 0.15; val conf **0.30** / IoU **0.70** during train only |

---

## Training-curve peaks (Ultralytics `results.csv` — not the fair table above)

| Model | Epochs logged | Best **val mAP@0.5** (epoch) | Val set used in training |
|-------|--------------:|-----------------------------:|--------------------------|
| **v2** | 50 | **65.1%** (ep 49) | `datasets/` val (~665 img) |
| **v10** | — | — | No local `results.csv` in repo |
| **v11** | 16 | **53.4%** (ep 1) | v10 val (fine-tune from v10) |
| **v12** | 200 | **41.4%** (ep 57) | v10 val @ train settings (1024, conf 0.30) |

Do **not** compare 65.1% (v2 on old val) directly to 47.4% (v11 on v10 val) or 41.4% (v12 training log).

---

## App deployment status

| Model | In `assets/model/best.tflite`? |
|-------|--------------------------------|
| v11 | Previous ship (May 2026) |
| **v12** | **Yes** (current shipped; TFLite @ 640 from `mealybug_v12/best.pt`) |

---

## Regenerate fair metrics

```powershell
cd D:\old_PINE
python scripts/evaluate_model_accuracy.py `
  --model runs/retrain/mealybug_v2/weights/best.pt `
  --model runs/retrain/mealybug_v10/weights/best.pt `
  --model runs/retrain/mealybug_v11/weights/best.pt `
  --model runs/retrain/mealybug_v12/weights/best.pt `
  --data mealybug.v10-8th-yolo26n.yolo26/data.yaml --conf 0.12 `
  --out runs/calibration/model_comparison_eval.json
```

v12-only eval already at `runs/calibration/mealybug_v12_eval.json`.
