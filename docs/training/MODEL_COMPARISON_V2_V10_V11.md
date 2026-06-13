# Model comparison: v2 vs v10 vs v11

> **Updated:** See **`docs/training/MODEL_COMPARISON_V2_V10_V11_V12.md`** for v12 and the full four-model table.

Generated: 2026-05-22 05:19 UTC

## Fair benchmark (same dataset, same settings)

- **Data:** `D:\old_PINE\mealybug.v10-8th-yolo26n.yolo26\data.yaml` (Roboflow v10 export, ~17k aug train / 923 val / 462 test)
- **Inference:** conf=0.12, IoU=0.45, imgsz=640
- **Source:** `runs/calibration/model_comparison_eval.json`

### Test split (primary for thesis / app claims)

| Model | Role | P | R | F1 | mAP@0.5 | mAP@0.5:0.95 |
|-------|------|---:|---:|---:|--------:|-------------:|
| **v2** | Legacy baseline | 41.1% | 38.6% | 39.8% | **21.1%** | 7.8% |
| **v10** | Full 17k Roboflow train | 55.7% | 49.4% | 52.4% | **42.1%** | 16.7% |
| **v11** **shipped** | Fine-tune from v10 + label clean | 56.2% | 49.2% | 52.5% | **43.0%** | 16.8% |

### Val split

| Model | P | R | F1 | mAP@0.5 | mAP@0.5:0.95 |
|-------|---:|---:|---:|--------:|-------------:|
| **v2** | 34.6% | 29.0% | 31.6% | 15.0% | 4.9% |
| **v10** | 62.1% | 49.7% | 55.2% | 45.7% | 19.7% |
| **v11** | 62.3% | 50.4% | 55.8% | 47.4% | 20.2% |

### Takeaways

- **v11 beats v2 on the same test set by +21.9 pp mAP@0.5** (43.0% vs 21.1%).
- **v11 slightly beats v10** (+0.9 pp test mAP@0.5; +1.7 pp val) after label-clean fine-tune.
- Do **not** compare v2’s ~65% training val mAP to v11 — v2 was trained/evaluated on a different, easier `datasets/` split.

## Training-curve peaks (during train — not the fair benchmark above)

| Model | Epochs | Best val mAP@0.5 (epoch) | Last val mAP@0.5 | Notes |
|-------|-------:|-------------------------:|-----------------:|-------|
| v2 | 50 | 65.1% (ep 49) | 64.7% | Legacy baseline (trained on `datasets/`) |
| v10 | — | — | — | No local `results.csv` |
| v11 | 16 | 53.4% (ep 1) | 51.5% | Fine-tune from v10 + label clean (shipped) |

## Figures

- Bar chart (val + test mAP@0.5, P, R): `runs/calibration/model_comparison_bars.png`
- Training val mAP@0.5 overlay (v2 vs v11 only): `runs/calibration/model_comparison_overlay_training.png` — **different val sets**

## Regenerate

```bash
python scripts/evaluate_model_accuracy.py \
  --model runs/retrain/mealybug_v2/weights/best.pt \
  --model runs/retrain/mealybug_v10/weights/best.pt \
  --model runs/retrain/mealybug_v11/weights/best.pt \
  --data mealybug.v10-8th-yolo26n.yolo26/data.yaml --conf 0.12 \
  --out runs/calibration/model_comparison_eval.json
python scripts/generate_model_comparison.py
```
