# PINYA-PIC accuracy metrics

Generated from `scripts/evaluate_model_accuracy.py`, `scripts/sweep_detection_threshold.py`, and training logs.

## Shipped app model (current: `mealybug_v12` → `assets/model/best.tflite`)

**Exported 2026-05-23** from `runs/retrain/mealybug_v12/weights/best.pt` (1024 train fine-tune from v11, 200 epochs). TFLite infer @ **640**.

Evaluated at **conf = 0.12** on `mealybug.v10-8th-yolo26n.yolo26/data.yaml`:

| Split | mAP@0.5 | Precision | Recall |
|-------|---------|-----------|--------|
| Val | **45.8%** | 62.3% | 49.0% |
| **Test** | **43.8%** | 58.6% | 51.3% |

**Report in thesis:** **43.8% mAP@0.5 (test)** (v12) or note v11 **43.0%** if comparing to prior shipped build.

Fair comparison table: **`docs/training/MODEL_COMPARISON_V2_V10_V11_V12.md`**.

| Model | Val mAP@0.5 | Test mAP@0.5 |
|-------|-------------|--------------|
| v11 (previous ship) | 47.4% | 43.0% |
| **v12 (shipped)** | 45.8% | **43.8%** |

Regenerate: `python scripts/evaluate_model_accuracy.py` (three `--model` paths) then `python scripts/generate_model_comparison.py`.

## Threshold sweep (v11, val — quick grid)

`runs/calibration/threshold_sweep.json` — model `mealybug_v11/weights/best.pt`, data `data.yaml`:

| Setting | conf | F1 | Precision | Recall |
|---------|------|-----|-----------|--------|
| Balanced (possible) | **0.22** | 0.558 | 61.7% | 51.0% |
| Confirmed (two-tier) | **0.28** | 0.550 | 68.8% | 45.8% |
| Accuracy preset (script) | **0.20** | 0.556 | 58.8% | 52.7% |

**Shipped app (balanced):** `detectionThreshold = 0.22`, `confirmedDetectionThreshold = 0.28`, NMS **0.45**.

**Accuracy mode** (Settings): still **0.08** + tiling for field recall — not the 0.20 val-only preset above.

v10 sweep (reference): F1 peak ~**0.26**; v11 quick grid peaks at **0.22** (F1 flat ~0.558 from 0.08–0.22).

## Legacy headline (different dataset — do not compare to v10)

| Metric | Value | Model | Split |
|--------|-------|-------|-------|
| mAP@0.5 | 65.1% | `mealybug_v2` | Old val (~914 images, `datasets/`) |

That 65% is **not** the same images as the 17k Roboflow export.

## Previous shipped model (`mealybug_fix500`)

At conf = 0.12 on old `datasets/` (~914 val / 460 test):

| Split | mAP@0.5 | Precision | Recall |
|-------|---------|-----------|--------|
| Test | 46.5% | 58.5% | 50.4% |

## Re-run

```powershell
python scripts/evaluate_model_accuracy.py --model runs/retrain/mealybug_v10/weights/best.pt --data mealybug.v10-8th-yolo26n.yolo26/data_fixed.yaml --conf 0.12
python scripts/sweep_detection_threshold.py --model runs/retrain/mealybug_v10/weights/best.pt --data mealybug.v10-8th-yolo26n.yolo26/data_fixed.yaml
```

JSON: `runs/calibration/accuracy_report.json`, `runs/calibration/threshold_sweep.json`

## Figure 26 — training curves (2×2)

Regenerate:

```powershell
python scripts/plot_model_metrics.py
```

| Figure | File | Source |
|--------|------|--------|
| **v11 (current, thesis)** | `runs/calibration/figure_26_training_curves_v11.png` | `runs/retrain/mealybug_v11/results.csv` (16 epochs, fine-tune) |
| **v16 (deployed, thesis Figure 26)** | `runs/calibration/figure_26_training_curves_v16_selffix.png` | `runs/retrain/mealybug_v16_selffix/results.csv` (92 epochs) |
| v2 (legacy comparison) | `runs/calibration/figure_26_training_curves_v2.png` | `runs/retrain/mealybug_v2/results.csv` (50 epochs) |

**Caption draft (v11):** Figure 26 shows validation precision, recall, mAP@0.5, and mAP@0.5:0.95 for **mealybug_v11** (YOLO26n fine-tune from v10, 16 epochs with early stopping). Metrics start high because weights were initialized from v10; best validation mAP@0.5 occurred at **epoch 1 (53.4%)**, with later epochs stable near 50–51% mAP@0.5.

## Not accuracy

- **UI box %** = single-detection confidence, not mAP.
- **Infestation / severity %** = derived heuristic, not benchmark accuracy.

## v11 training note

Vast end-of-train validate reported **53.4%** mAP@0.5 (confidence swept for mAP). PC fair eval at **conf 0.12** above is the deployment-aligned number.
