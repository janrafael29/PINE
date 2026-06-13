# Field-day photos → 17k dataset

Use this when the team returns from the field with **many folders** (era, ghaz, jan, …) on Drive or a shared drive.

## Before you start

1. **Download/sync** the parent folder to your PC (Google Drive “Available offline” or copy to `D:\...`). The scripts cannot read Drive URLs directly.
   - **Zip from Drive:** unzip under `field_import\`, then use the inner folder (e.g. `field_import\Mealybug Pics`) as `-Source`.
   - Example in this repo: `Mealybug Pics-20260521T002313Z-3-003.zip` → `field_import\Mealybug Pics\`.
2. **Do not** mix in the old `datasets/` export folder from Drive — it is skipped automatically.
3. **`FOR VALIDATION`** is copied aside for expert QA; it is **not** auto-labeled until you decide to include it.

## Quick path (recommended)

```powershell
cd D:\old_PINE

# Step 1 — collect + pre-label (uses local YOLO, free)
.\scripts\field_day_from_drive.ps1 -Source "D:\path\to\field_day_parent" -MarkEmpty

# Step 2 — review in CVAT (fix boxes, empty negatives)
#         Import: field_batches\<latest>\images + labels
#         Rules: docs/data/BOXING_GUIDELINES.md

# Step 3 — augment (~4×) and merge into datasets/train
.\scripts\field_day_from_drive.ps1 -Source "D:\path\to\field_day_parent" `
  -AugmentAndMerge -SkipCollect -SkipLabel `
  -Batch "field_batches\2026-05-19_collected"
```

## What each step does

| Step | Script | Result |
|------|--------|--------|
| Collect | `collect_field_photos.py` | `field_staging/<date>_collected/` — all team JPGs, unique names |
| Validation copy | (same script) | `field_staging/<date>_for_validation/` — optional expert set |
| Pre-label | `auto_label_yolo.py` | `field_batches/<date>_*/images` + `labels` |
| Review | CVAT / Label Studio | Human fixes (required for quality) |
| Augment | `augment_yolo_subset.py` | ~3 extra copies per image (flip, rotate, brightness, noise) |
| Merge | `merge_field_batch.py` | Adds to `datasets/train/images` + `labels` |

## Adding to the full ~17k

Your repo **`datasets/`** train split is what Vast/local training uses today (~3.6k images after the 500-label merge; full v10 export is ~16k train in `mealybug.v10-8th-yolo26n.yolo26`).

| Goal | Action |
|------|--------|
| **Next train on PC/Vast** | Merge reviewed batch into `datasets/train` (above). Re-run `vast_train.sh` or `retrain_yolo.py` when the current GPU job finishes. |
| **Roboflow “official” 17k+** | Upload **reviewed** images only to `pine3/mealybug-y4fsp`, tag `field_2026`, **Generate 4× on train only**, export new version → replace or merge into `datasets/`. |
| **Augment field-only** | Prefer Roboflow Generate **or** local `augment_yolo_subset.py` — do **not** duplicate aug on val/test. |

## Negatives

Photos of healthy pineapple with **no** mealybugs must have an **empty** `.txt` label. Use `-MarkEmpty` on pre-label so the model learns “no box = no pest.”

## After Vast training finishes

1. Download `best.pt` from the current run.
2. Use that (or `mealybug_v2`) as `--model` for the **next** field batch pre-label if boxes look better.
3. Optional second train: `mealybug_field_v11` with merged `datasets/`.

## Install (one-time, for augment)

```powershell
.\.venv\Scripts\pip install albumentations opencv-python-headless
```
