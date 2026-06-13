# Train on full ~17.5k dataset (Roboflow v10)

## What you have

| Folder | Train | Val | Test | Notes |
|--------|-------|-----|------|--------|
| `datasets/` | 3,621 | 914 | 460 | Used for **mealybug_fix500** (smaller) |
| `mealybug.v10-8th-yolo26n.yolo26/` | **16,175** | 923 | 462 | **5× aug** Roboflow v10 (~17.5k total) |

Same ~3k **source** images in Roboflow; v10 is the **augmented** export.

## Why try 17k

- More variety (flip, rotate, brightness, noise) → often **better val mAP** than 3.6k-only train.
- **Does not replace field photos** — crown close-ups still need labeling + merge for real-world scans.

## Quick compare (your field test photo)

| Model | Trained on | Best conf on white cluster |
|-------|------------|----------------------------|
| fix500 | ~3.6k | ~19% |
| v2 | ~2.3k (older split) | ~38% |

v10 train may beat fix500 on **validation**; test again on the **same phone photo** after export.

---

## Option A — Vast.ai (recommended for 17k)

### 1. Package (~2 GB zip)

```powershell
cd D:\old_PINE
.\scripts\package_v10_for_vast.ps1
```

Output: `vast_upload\pine_v10_train_bundle.zip` (~1.5–2 GB).

### 2. Upload & train

Same as before: upload zip, unzip into `pine/`, run:

```bash
cd /workspace/pine
bash scripts/vast_train_v10.sh
```

- Run name: **`mealybug_v10`**
- Weights start: **`mealybug_v2/best.pt`** (better than fix500 on your field shot)
- Epochs: **100** (early stop patience 20)
- **~2–5 hours** on RTX 5090 (vs ~37 min for 3.6k)

### 3. Download & ship app

```powershell
scp ... root@HOST:/workspace/pine/runs/retrain/mealybug_v10/weights/best.pt D:\old_PINE\runs\retrain\mealybug_v10\weights\

python scripts\retrain_yolo.py --export-only runs\retrain\mealybug_v10\weights\best.pt
copy runs\retrain\mealybug_v10\weights\best_saved_model\best_float32.tflite assets\model\best.tflite
flutter clean
.\scripts\run_debug.ps1 -Device ...
```

---

## Option B — Local (if no Vast credits)

```powershell
cd D:\old_PINE
pip install -r scripts\requirements-train.txt
python scripts\retrain_yolo.py --data mealybug.v10-8th-yolo26n.yolo26\data.yaml --weights runs\retrain\mealybug_v2\weights\best.pt --name mealybug_v10 --epochs 100 --batch 8 --device 0
```

Use smaller `--batch` if GPU OOM. Expect **many hours** on a laptop GPU.

---

## After v10 train

1. Rescan the **same** field photo.
2. If still weak on white clusters → **field_day** labels (Drive folders) + **v11** train merging field + v10.
3. Keep **`datasets/`** 3.6k copy as backup; do not delete v10 folder.
