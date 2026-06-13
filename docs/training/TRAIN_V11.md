# Train mealybug_v11 (cleaned labels, fine-tune from v10)

v11 = same **17k** Roboflow v10 images, **cleaned boxes** (polygons → tight rects, noise removed), starting from your **v10 `best.pt`**.

---

## Before you start (on your PC)

| Check | Path |
|-------|------|
| Cleaned dataset | `mealybug.v10-8th-yolo26n.yolo26/` (labels already fixed) |
| v10 weights | `runs/retrain/mealybug_v10/weights/best.pt` |
| Optional: preview boxes | `runs/label_clean/previews/` |

Let the **threshold sweep** finish if it is still running (`terminals` / `runs/calibration/`). You will compare v11 against that best `conf` later.

---

## Step 1 — Build the upload zip (~2 GB)

PowerShell:

```powershell
cd D:\old_PINE
.\scripts\package_v11_for_vast.ps1
```

Output: `vast_upload\pine_v11_train_bundle.zip`

This includes:

- Cleaned dataset (no `*.txt.bak`, no `labels.cache`)
- `mealybug_v10/weights/best.pt` as the starting checkpoint
- `scripts/vast_train_v11.sh`

---

## Step 2 — Rent a Vast GPU

Same as v10:

1. [vast.ai](https://vast.ai) → **RTX 5090 / 4090**, CUDA image, **≥ 30 GB** disk.
2. Start instance, note **SSH port** and **IP**.
3. Open **Jupyter** or **SSH** terminal on the instance.

---

## Step 3 — Upload and unzip

**Jupyter (easiest on Windows):** upload `pine_v11_train_bundle.zip` to `/workspace/`, then in a terminal:

```bash
cd /workspace
mkdir -p pine
unzip -q pine_v11_train_bundle.zip -d pine
cd pine
ls mealybug.v10-8th-yolo26n.yolo26/data.yaml
ls runs/retrain/mealybug_v10/weights/best.pt
```

**SCP from PC (if SSH works):**

```powershell
scp -P PORT "D:\old_PINE\vast_upload\pine_v11_train_bundle.zip" root@IP:/workspace/
```

Then on Vast: same `unzip` commands as above.

---

## Step 4 — Train on Vast

```bash
cd /workspace/pine
bash scripts/vast_train_v11.sh
```

| Setting | Value |
|---------|--------|
| Run name | `mealybug_v11` |
| Starts from | `mealybug_v10/best.pt` |
| Epochs | **50** (early stop patience **15**) |
| Batch | **16** (use `--batch 8` in script if OOM) |
| Time | ~**1–3 h** on 5090 |

Watch for **best epoch** in the log; training stops early if val mAP plateaus.

---

## Step 5 — Download `best.pt` to your PC

**Jupyter:** download  
`/workspace/pine/runs/retrain/mealybug_v11/weights/best.pt`

**SCP:**

```powershell
mkdir D:\old_PINE\runs\retrain\mealybug_v11\weights -Force
scp -P PORT root@IP:/workspace/pine/runs/retrain/mealybug_v11/weights/best.pt D:\old_PINE\runs\retrain\mealybug_v11\weights\
```

**Destroy the Vast instance** when the file is on your PC (saves money).

---

## Step 6 — Measure accuracy on PC

```powershell
cd D:\old_PINE
python scripts/evaluate_model_accuracy.py `
  --model runs/retrain/mealybug_v11/weights/best.pt `
  --data mealybug.v10-8th-yolo26n.yolo26/data_fixed.yaml `
  --conf 0.12
```

Compare to v10 (same cleaned val labels):

| Model | Typical val mAP@0.5 (conf 0.12) |
|-------|----------------------------------|
| v10 (old labels) | ~47% |
| v10 (same weights, cleaned val only) | ~46% |
| **v11 (goal)** | **50–55%+** if cleanup + fine-tune helped |

Optional: re-run threshold sweep on v11:

```powershell
python scripts/sweep_detection_threshold.py `
  --model runs/retrain/mealybug_v11/weights/best.pt `
  --data mealybug.v10-8th-yolo26n.yolo26/data_fixed.yaml
```

Use the `conf` that maximizes **F1** on val for the app (often **0.10–0.15**, not 0.30+).

---

## Step 7 — Export TFLite and put in the app

```powershell
python scripts/retrain_yolo.py --export-only runs/retrain/mealybug_v11/weights/best.pt
Copy-Item runs\retrain\mealybug_v11\weights\best_saved_model\best_float32.tflite assets\model\best.tflite -Force
flutter clean
.\scripts\run_debug.ps1 -Device <your-phone-id>
```

Test the **same field photo** you used before; compare box count and confidence to v10/fix500.

---

## Optional later: field batch (v11b)

When your ~409 CVAT field images are ready:

1. `scripts/merge_field_batch.py` (see `docs/data/FIELD_DAY_INGEST.md`)
2. Second short fine-tune: `--name mealybug_field_v11 --epochs 30` from v11 `best.pt`

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `Missing best.pt` on Vast | Re-run `package_v11_for_vast.ps1`; confirm zip contains `runs/retrain/mealybug_v10/weights/best.pt` |
| CUDA OOM | Edit `vast_train_v11.sh`: `--batch 8` |
| Val mAP not improving | Labels are cleaner but harder; try 30 more epochs or review `runs/label_clean/worst_for_cvat.csv` in CVAT |
| Upload 0 bytes | Use Jupyter upload, not PowerShell `scp` with wrong `$env:USERPROFILE` syntax |
| Roll back labels | See `docs/data/LABEL_CLEANUP_V10.md` rollback section |

---

## Quick checklist

- [ ] `package_v11_for_vast.ps1` → zip created  
- [ ] Uploaded + unzipped on Vast  
- [ ] `bash scripts/vast_train_v11.sh` finished  
- [ ] `best.pt` on `D:\old_PINE\runs\retrain\mealybug_v11\weights\`  
- [ ] `evaluate_model_accuracy.py` run  
- [ ] TFLite → `assets/model/best.tflite`  
- [ ] Phone test on field photo  
