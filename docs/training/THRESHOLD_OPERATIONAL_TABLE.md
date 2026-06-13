# PINYA-PIC — comparison of YOLO confidence thresholds (mealybug_v11)

Data: `mealybug_v11` `best.pt`, Roboflow v10 **val** (923 images, 7,170 instances), 
Ultralytics val @ IoU 0.45, imgsz 640. Regenerate: 
`python scripts/generate_threshold_operational_table.py`.

## Table X — Comparison of confidence thresholds (operational)

| Confidence | Val P / R | System behavior | Operational impact (PINYA-PIC) |
|------------|-----------|-----------------|--------------------------------|
| **0.08 (accuracy mode)** | 62.3% / 50.4% | Highest recall band (~62% P, ~50% R); more false boxes; used with tiling in accuracy mode. | Field scouts see more candidate boxes on crown photos; higher workload verifying false positives on white/yellow fruit. Recommended when infestation is suspected but balanced mode misses clusters. |
| **0.12** | 62.3% / 50.4% | Highest recall band (~62% P, ~50% R); more false boxes; used with tiling in accuracy mode. | Used only for reporting mAP@0.5 (thesis: 47.4% val / 43.0% test at conf 0.12). Not the same as deployed UI thresholds. |
| **0.22** | 61.7% / 51.0% | Near F1-optimal (~62% P, ~51% R, F1≈56% on val); balanced default for on-screen possible detections. | Default scan: possible mealybug overlays without flooding the UI. Pairs with NMS 0.45 (Dart, on-device). |
| **0.28** | 68.8% / 45.8% | Elevated precision (~69% P), reduced recall (~46% R); fits confirmed count / severity tier. | Bug count, severity score, and saved records use this stricter tier — reduces over-counting vs possible tier while accepting missed low-score pests. |
| **0.25** | 65.3% / 48.4% | Near F1-optimal (~65% P, ~48% R, F1≈56% on val); balanced default for on-screen possible detections. | Pre-labeling field batches for CVAT; similar operating point to shipped possible. |
| **0.35** | 74.7% / 39.2% | Elevated precision (~75% P), reduced recall (~39% R); fits confirmed count / severity tier. | Would under-report infestation extent; not used in PINYA-PIC. |
| **0.50** | **84.3% / 26.9%** | High precision (~84% P), low recall (~27% R); minimizes false boxes, misses most instances. | Collision literature often cites ~0.50 for mAP evaluation; **not suitable** for mealybug scouting — growers would see less than one-third of pests. |
| **0.85** (SMS-style) | **98.9% / 1.2%** | Extreme precision; recall ~1% — almost no pests shown. | Same role as collision SMS at 0.90+. **Rejected** for PINYA-PIC: missed infestation is the primary risk. |

## Deployed vs collision-style systems

| Aspect | Collision SMS (friend's Ch. 4.2.5) | PINYA-PIC (mealybugs) |
|--------|----------------------------------|------------------------|
| Primary risk | False alert → wasted dispatch | **Missed pest** → no treatment |
| Typical deploy conf | **0.90+** | **0.22 possible / 0.28 confirmed** |
| Accuracy mode | N/A | **0.08** + tiled inference |
| mAP reporting conf | Often ~0.50 in papers | **0.12** (holdout benchmark) |

## Source files

- Raw metrics: `runs/calibration/threshold_operational_table.json`
- Sweep: `runs/calibration/threshold_sweep.json`
- Curves: `runs/calibration/mealybug_v11_ultralytics_curves/Box*.png`
- App: `lib/core/constants.dart`
