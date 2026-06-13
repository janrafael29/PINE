# Confusion Cases — mealybug_v16_selffix (Panel Guidance #7)

*Generated: 2026-06-10 07:15 UTC*

Qualitative error analysis on the held-out test split. Green = true positive (pred); white = ground truth; red = false positive; yellow = false negative (missed GT); blue = poor localization.

- Model: `runs\retrain\mealybug_v16_selffix\weights\best.pt`
- Labels: `datasets\mealybug_v13afix\test\labels_v16_corrected`
- Confidence threshold: **0.25** (deploy-aligned)
- IoU match threshold: **0.5**
- Images scanned: **400**

## Paste into Chapter IV (Discussion)

> To complement aggregate metrics (73.3% mAP@0.5, 64.7% recall), Figure X presents representative detection outcomes on held-out test images. True positives show that the model detects visible mealybug clusters under reasonable field-like conditions. False positives often involve white leaf residue, glare, or textured patches that resemble mealybug wax. False negatives occur on small, partially occluded, or low-contrast pests — consistent with the recall limitation noted by the panel. Poor-localization cases (loose boxes or IoU below strict thresholds) contribute to the lower mAP@0.5:0.95 (40.7%) and indicate that bounding boxes are not yet consistently tight enough for strict localization evaluation.

## Tp

![tp](docs/thesis/assets/confusion_cases_v16/tp/01_tp_test_000718.jpg)

*True positive — model correctly localizes a mealybug instance.* Source: `test_000718.jpg` — Matched at IoU >= 0.50

![tp](docs/thesis/assets/confusion_cases_v16/tp/02_tp_test_001333.jpg)

*True positive — model correctly localizes a mealybug instance.* Source: `test_001333.jpg` — Matched at IoU >= 0.50

![tp](docs/thesis/assets/confusion_cases_v16/tp/03_tp_test_001234.jpg)

*True positive — model correctly localizes a mealybug instance.* Source: `test_001234.jpg` — Matched at IoU >= 0.50

![tp](docs/thesis/assets/confusion_cases_v16/tp/04_tp_test_000636.jpg)

*True positive — model correctly localizes a mealybug instance.* Source: `test_000636.jpg` — Matched at IoU >= 0.50

![tp](docs/thesis/assets/confusion_cases_v16/tp/05_tp_test_001147.jpg)

*True positive — model correctly localizes a mealybug instance.* Source: `test_001147.jpg` — Matched at IoU >= 0.50

![tp](docs/thesis/assets/confusion_cases_v16/tp/06_tp_test_001913.jpg)

*True positive — model correctly localizes a mealybug instance.* Source: `test_001913.jpg` — Matched at IoU >= 0.50

## Fp

![fp](docs/thesis/assets/confusion_cases_v16/fp/01_fp_test_001275.jpg)

*False positive — model flags a non-pest region (e.g., white residue/glare).* Source: `test_001275.jpg` — No overlapping ground-truth box

![fp](docs/thesis/assets/confusion_cases_v16/fp/02_fp_test_000884.jpg)

*False positive — model flags a non-pest region (e.g., white residue/glare).* Source: `test_000884.jpg` — No overlapping ground-truth box

![fp](docs/thesis/assets/confusion_cases_v16/fp/03_fp_test_001528.jpg)

*False positive — model flags a non-pest region (e.g., white residue/glare).* Source: `test_001528.jpg` — No overlapping ground-truth box

![fp](docs/thesis/assets/confusion_cases_v16/fp/04_fp_test_001630.jpg)

*False positive — model flags a non-pest region (e.g., white residue/glare).* Source: `test_001630.jpg` — No overlapping ground-truth box

![fp](docs/thesis/assets/confusion_cases_v16/fp/05_fp_test_001108.jpg)

*False positive — model flags a non-pest region (e.g., white residue/glare).* Source: `test_001108.jpg` — No overlapping ground-truth box

![fp](docs/thesis/assets/confusion_cases_v16/fp/06_fp_test_000748.jpg)

*False positive — model flags a non-pest region (e.g., white residue/glare).* Source: `test_000748.jpg` — No overlapping ground-truth box

## Fn

![fn](docs/thesis/assets/confusion_cases_v16/fn/01_fn_test_000045.jpg)

*False negative — ground-truth mealybug missed at deploy threshold.* Source: `test_000045.jpg` — Ground truth not detected at deploy threshold

![fn](docs/thesis/assets/confusion_cases_v16/fn/02_fn_test_000894.jpg)

*False negative — ground-truth mealybug missed at deploy threshold.* Source: `test_000894.jpg` — Ground truth not detected at deploy threshold

![fn](docs/thesis/assets/confusion_cases_v16/fn/03_fn_test_000274.jpg)

*False negative — ground-truth mealybug missed at deploy threshold.* Source: `test_000274.jpg` — Ground truth not detected at deploy threshold

![fn](docs/thesis/assets/confusion_cases_v16/fn/04_fn_test_001069.jpg)

*False negative — ground-truth mealybug missed at deploy threshold.* Source: `test_001069.jpg` — Ground truth not detected at deploy threshold

![fn](docs/thesis/assets/confusion_cases_v16/fn/05_fn_test_001528.jpg)

*False negative — ground-truth mealybug missed at deploy threshold.* Source: `test_001528.jpg` — Ground truth not detected at deploy threshold

![fn](docs/thesis/assets/confusion_cases_v16/fn/06_fn_test_000067.jpg)

*False negative — ground-truth mealybug missed at deploy threshold.* Source: `test_000067.jpg` — Ground truth not detected at deploy threshold

## Poor Localization

![poor_localization](docs/thesis/assets/confusion_cases_v16/poor_localization/01_poor_localization_test_000355.jpg)

*Poor localization — loose box (IoU 0.50–0.75) or overlap below match threshold.* Source: `test_000355.jpg` — Overlap with GT but below IoU 0.50 match

![poor_localization](docs/thesis/assets/confusion_cases_v16/poor_localization/02_poor_localization_test_000426.jpg)

*Poor localization — loose box (IoU 0.50–0.75) or overlap below match threshold.* Source: `test_000426.jpg` — Overlap with GT but below IoU 0.50 match

![poor_localization](docs/thesis/assets/confusion_cases_v16/poor_localization/03_poor_localization_test_001014.jpg)

*Poor localization — loose box (IoU 0.50–0.75) or overlap below match threshold.* Source: `test_001014.jpg` — Detected but box not tight (IoU 0.50–0.75)

![poor_localization](docs/thesis/assets/confusion_cases_v16/poor_localization/04_poor_localization_test_000486.jpg)

*Poor localization — loose box (IoU 0.50–0.75) or overlap below match threshold.* Source: `test_000486.jpg` — Detected but box not tight (IoU 0.50–0.75)

![poor_localization](docs/thesis/assets/confusion_cases_v16/poor_localization/05_poor_localization_test_001468.jpg)

*Poor localization — loose box (IoU 0.50–0.75) or overlap below match threshold.* Source: `test_001468.jpg` — Detected but box not tight (IoU 0.50–0.75)

![poor_localization](docs/thesis/assets/confusion_cases_v16/poor_localization/06_poor_localization_test_001786.jpg)

*Poor localization — loose box (IoU 0.50–0.75) or overlap below match threshold.* Source: `test_001786.jpg` — Overlap with GT but below IoU 0.50 match

## Regenerate

```powershell
cd D:\old_PINE
python scripts/export_confusion_cases.py
```

Output folder: `docs/thesis/assets/confusion_cases_v16/`
