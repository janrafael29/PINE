# Merge two annotation zips → test vs 17k benchmark

Use this when you have **two CVAT/Darknet YOLO 1.1 zips** like `Mealybug_annotations2.zip`:

```
obj.data
obj.names
obj_train_data/
  photo.jpg
  photo.txt
```

## Step 1 — Put zips on your PC

Copy both files here:

```
D:\old_PINE\incoming_annotations\
  Mealybug_annotations1.zip   (your first zip)
  Mealybug_annotations2.zip   (your second zip)
```

## Step 2 — Combine the two zips into one folder

```powershell
cd D:\old_PINE
python scripts/merge_darknet_zips.py `
  --zip incoming_annotations\Mealybug_annotations1.zip `
  --zip incoming_annotations\Mealybug_annotations2.zip `
  --out datasets\mealybug_merged_annotations
```

Output:

- `datasets/mealybug_merged_annotations/images/`
- `datasets/mealybug_merged_annotations/labels/`
- `datasets/mealybug_merged_annotations/merge_manifest.json`

## Step 3 — Merge into 17k v10 (keeps same val/test for fair compare)

Adds your new images to **train only**. Val (923) and test (462) stay the **same** as Roboflow v10.

```powershell
python scripts/merge_annotations_into_v10.py --source datasets\mealybug_merged_annotations
```

Output dataset:

```
datasets/mealybug_v10_plus_annotations/
  data.yaml
  train/   ← 17k train + your new images
  valid/   ← unchanged
  test/    ← unchanged (compare to v11 43.0% here)
```

## Step 4 — Baseline: current model on same test (no retrain)

```powershell
python scripts/evaluate_model_accuracy.py `
  --model runs/retrain/mealybug_v11/weights/best.pt `
  --data datasets/mealybug_v10_plus_annotations/data.yaml `
  --conf 0.12 `
  --out runs/calibration/v11_on_v10_plus_ann_eval.json
```

(Same test split → **same ~43%** as before; this step only checks the yaml paths work.)

## Step 5 — Fine-tune v10a on expanded train (v10 + field combined)

```powershell
python scripts/retrain_yolo.py --preset v10a --no-export
```

Or on Vast: `bash scripts/vast_train_v10a.sh` (bundle: `package_v10a_for_vast.ps1`).

**Naming:** `v10a` = v10 train **plus** merged field annotations. Reserve **Va** for a future field-only model if you train one.

## Step 6 — Compare vs v12

```powershell
python scripts/compare_v10a_v12.py
```

| Model | Test mAP@0.5 (same 462-image test) |
|-------|-------------------------------------|
| v11 (17k only) | **43.0%** |
| v12 (1024, v10 only) | 43.8% |
| **v10a (17k + field)** | ? |

**Beat v12** if v10a test mAP@0.5 **> 43.8%**.

## Important notes

1. **Fair comparison** requires the **same test split** — do not create a new random test from only the new zips.
2. **More train data alone** does not always raise test mAP if new labels differ in style from test images.
3. Check `merge_manifest.json` for empty labels before training.
4. For thesis: report v10a as “v10 Roboflow train + DA/CVAT field annotations merged.”
