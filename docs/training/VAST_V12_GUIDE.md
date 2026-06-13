# Vast.ai guide — mealybug_v12 (1024, batch 8, 200 epochs)

Use this when renting a GPU on [cloud.vast.ai](https://cloud.vast.ai) for the high-res v12 train.

---

## Before you open Vast (on your PC)

1. Confirm files exist:
   - `mealybug.v10-8th-yolo26n.yolo26/` (full Roboflow export)
   - `runs/retrain/mealybug_v11/weights/best.pt` (starting checkpoint)

2. Build the upload zip:

   ```powershell
   cd D:\old_PINE
   .\scripts\package_v12_for_vast.ps1
   ```

   Output: **`vast_upload\pine_v12_train_bundle.zip`** (~1.5–2.5 GB).

3. Optional sanity check:

   ```powershell
   python scripts/retrain_yolo.py --preset v12-highres --dry-run
   ```

   Expect `batch=8`, `imgsz=1024`, `epochs=200`.

---

## What to pick on Vast (search filters)

| Setting | What to choose | Why |
|---------|----------------|-----|
| **GPU RAM** | **≥ 24 GB** (RTX 3090, 4090, A5000, L40, RTX 5090, etc.) | 1024 px + batch 8 |
| **Disk space** | **≥ 50 GB** (80 GB safer) | Dataset + checkpoints + cache |
| **CUDA** | Enabled / CUDA 12.x template | PyTorch + Ultralytics |
| **Docker image** | `pytorch/pytorch:2.1.0-cuda12.1-cudnn8-runtime` or any **PyTorch + CUDA** image | Training stack |
| **Internet** | Good upload speed | Large zip |
| **Price** | Your budget | 200 epochs may run **12–24+ hours** |

**Avoid:** GPUs with &lt; 16 GB VRAM for this job (you will OOM even at batch 8).

**On-start command:** leave **empty** — you will SSH in and run the train script manually (easier to debug).

---

## Rent the instance

1. **Search** → apply filters above → sort by **$/hr** or **reliability**.
2. Click **Rent** on an offer you trust.
3. Wait until status is **running**.
4. Copy the **SSH** line (example shape):

   ```text
   ssh -p 12345 root@1.2.3.4 -L 8080:localhost:8080
   ```

   Note: **port**, **IP**, and whether the path is `/workspace` or `/root`.

---

## Upload the zip

### Option A — SCP from PowerShell (common)

Replace `PORT` and `IP` from the Vast SSH card:

```powershell
scp -P PORT D:\old_PINE\vast_upload\pine_v12_train_bundle.zip root@IP:/workspace/
```

If Vast says home is `/root`:

```powershell
scp -P PORT D:\old_PINE\vast_upload\pine_v12_train_bundle.zip root@IP:/root/
```

### Option B — Jupyter / file UI on the template

Some templates have a file browser — upload the zip there, then move it in SSH.

---

## SSH in and unzip

```bash
ssh -p PORT root@IP
cd /workspace    # or cd /root — match where you uploaded
ls -lh pine_v12_train_bundle.zip
unzip -q pine_v12_train_bundle.zip -d pine
cd pine
ls -la
```

You should see:

- `mealybug.v10-8th-yolo26n.yolo26/`
- `runs/retrain/mealybug_v11/weights/best.pt`
- `scripts/vast_train_v12.sh`
- `configs/train_v12_highres.yaml`

Quick GPU check:

```bash
nvidia-smi
python3 --version
```

---

## Start training

```bash
cd /workspace/pine   # adjust if you used /root/pine
chmod +x scripts/vast_train_v12.sh
bash scripts/vast_train_v12.sh
```

Default: **batch 8**, **1024**, **200 epochs**, fine-tune from **v11**.

### Keep training if SSH disconnects

```bash
apt-get update && apt-get install -y tmux   # once per instance
tmux new -s v12
cd /workspace/pine && bash scripts/vast_train_v12.sh
# Detach: Ctrl+B then D
# Reattach: tmux attach -t v12
```

### Resume after a crash

```bash
cd /workspace/pine
python3 -u scripts/retrain_yolo.py --preset v12-highres --resume --no-export
```

### Out of memory

```bash
BATCH=4 bash scripts/vast_train_v12.sh
```

---

## While it runs

- Watch `runs/retrain/mealybug_v12/results.csv` and console mAP.
- **Do not destroy the instance** until `runs/retrain/mealybug_v12/weights/best.pt` exists.
- **Stop the instance** on Vast when download is done (stops billing).

---

## Download weights to your PC

```powershell
mkdir D:\old_PINE\runs\retrain\mealybug_v12\weights -Force
scp -P PORT root@IP:/workspace/pine/runs/retrain/mealybug_v12/weights/best.pt D:\old_PINE\runs\retrain\mealybug_v12\weights\
```

Optional: copy whole run folder for curves:

```powershell
scp -P PORT -r root@IP:/workspace/pine/runs/retrain/mealybug_v12 D:\old_PINE\runs\retrain\
```

---

## After download (on Windows)

```powershell
cd D:\old_PINE
python scripts/retrain_yolo.py --export-only runs/retrain/mealybug_v12/weights/best.pt --export-imgsz 640
python scripts/evaluate_model_accuracy.py --model runs/retrain/mealybug_v12/weights/best.pt --data mealybug.v10-8th-yolo26n.yolo26/data.yaml --conf 0.12 --out runs/calibration/mealybug_v12_eval.json
python scripts/sweep_detection_threshold.py --model runs/retrain/mealybug_v12/weights/best.pt
```

Ship to app only if metrics beat v11:

```powershell
copy runs\retrain\mealybug_v12\weights\best_float32.tflite assets\model\best.tflite
```

Update `lib/core/constants.dart` from the new sweep if thresholds shift.

---

## Checklist

- [ ] `package_v12_for_vast.ps1` zip created
- [ ] GPU ≥ 24 GB, disk ≥ 50 GB
- [ ] Zip uploaded and unzipped to `pine/`
- [ ] `nvidia-smi` shows GPU
- [ ] `bash scripts/vast_train_v12.sh` started (tmux recommended)
- [ ] `best.pt` downloaded
- [ ] Instance **stopped** on Vast
- [ ] TFLite export + eval on PC

---

## Rough cost / time

| GPU class | Batch 8 @ 1024, 200 epochs (estimate) |
|-----------|----------------------------------------|
| RTX 4090 / 5090 | ~12–18 h |
| RTX 3090 / A5000 | ~18–30 h |

At **$0.30–0.60/hr**, budget roughly **$5–20** depending on GPU and early convergence.

---

See also: `docs/training/VAST_TRAINING.md`, `docs/training/TRAIN_V12_HIGHRES.md`.
