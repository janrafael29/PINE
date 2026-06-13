# All retrain comparison (fair 17k benchmark)

Generated: 2026-05-23T11:58:57.848002+00:00

## Settings

- **Benchmark:** `D:\old_PINE\mealybug.v10-8th-yolo26n.yolo26\data.yaml` (923 val / 462 test)
- **conf=0.12, IoU=0.45, imgsz=640**
- **JSON:** `runs/calibration/all_retrains_eval.json`

### Test split (primary — thesis / app)

| Model | Description | P | R | F1 | mAP@0.5 | mAP@0.5:0.95 |
|-------|-------------|--:|--:|---:|--------:|-------------:|
| **v2** | Legacy baseline (`datasets/`) | 41.1% | 38.6% | 39.8% | **21.1%** | 7.8% |
| **fix500** | v2 fine-tune (500-step fix) | 57.9% | 51.5% | 54.5% | **45.3%** | 18.3% |
| **v10** | Full 17k Roboflow train | 55.7% | 49.4% | 52.4% | **42.1%** | 16.7% |
| **v11** ✓ app | Fine-tune v10 + label clean — **shipped in app** | 56.2% | 49.2% | 52.5% | **43.0%** | 16.8% |
| **v12** | v11 init, 1024 train, v10 data only | 58.6% | 51.3% | 54.7% | **43.8%** | 16.9% |
| **v10a** | v10 + 877 field images (combined) | 57.9% | 50.9% | 54.2% | **43.9%** | 17.3% |
| **Va** | Field-only ~877 images | 23.9% | 7.2% | 11.1% | **3.7%** | 1.0% |

**Best on benchmark test:** **fix500** (45.3% mAP@0.5)

### Val split

| Model | P | R | F1 | mAP@0.5 | mAP@0.5:0.95 |
|-------|--:|--:|---:|--------:|-------------:|
| **v2** | 34.6% | 29.0% | 31.6% | 15.0% | 4.9% |
| **fix500** | 52.7% | 46.6% | 49.5% | 37.8% | 15.6% |
| **v10** | 62.1% | 49.7% | 55.2% | 45.7% | 19.7% |
| **v11** | 62.3% | 50.4% | 55.8% | 47.4% | 20.2% |
| **v12** | 62.3% | 49.0% | 54.9% | 45.8% | 19.7% |
| **v10a** | 62.5% | 50.9% | 56.1% | 48.0% | 20.5% |
| **Va** | 25.7% | 8.8% | 13.2% | 4.2% | 1.0% |

### Field-only test (133 images — Va only)

| Model | mAP@0.5 | P | R |
|-------|--------:|--:|--:|
| **Va** | 28.5% | 46.8% | 36.5% |

## Training peaks (during train — not fair benchmark)

| Model | Epochs | Best train-val mAP@0.5 |
|-------|-------:|---------------------:|
| v2 | 50 | 65.1% (ep 49) |
| fix500 | — | (no results.csv) |
| v10 | — | (no results.csv) |
| v11 | 16 | 53.4% (ep 1) |
| v12 | 200 | 41.4% (ep 57) |
| v10a | — | (no results.csv) |
| Va | 100 | 26.1% (ep 79) |

## Figure

![Test mAP comparison](runs/calibration/all_retrains_comparison_bars.png)

## Regenerate

```bash
python scripts/compare_all_retrains.py
```
