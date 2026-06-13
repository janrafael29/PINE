# Train on Vast.ai (YOLO26n, fix500 merged)

After CVAT merge, use this to fine-tune on a cloud GPU and bring **`best.pt`** back to your PC for TFLite export.

## What gets trained

| Item | Path |
|------|------|
| Dataset | `datasets/` — **3621** train (+ your **500** reviewed), **914** valid, **460** test |
| Fine-tune from | `runs/retrain/mealybug_v2/weights/best.pt` |
| New run name | `runs/retrain/mealybug_fix500/` |
| Backbone | **YOLO26n** (Ultralytics) |

## Step 1 — Build upload zip (Windows)

```powershell
cd D:\old_PINE
.\scripts\package_for_vast.ps1
```

Creates **`vast_upload\pine_train_bundle.zip`** (datasets + scripts + `best.pt`).

> Zip can be **several GB**. Upload over good internet or use Vast’s cloud sync if you host the zip on Drive and `wget` on the instance.

## Step 2 — Rent a Vast instance

1. [cloud.vast.ai](https://cloud.vast.ai) → **Search**
2. Filters: **CUDA**, **≥ 12 GB VRAM** (RTX 3090 / 4090 / A5000 class)
3. **Docker image:** `pytorch/pytorch` or Ultralytics-friendly CUDA image
4. **Disk:** ≥ **30 GB** free
5. Rent → note **SSH** command (IP, port, user)

## Step 3 — Upload and unzip

**SCP (PowerShell, adjust IP/port/path):**

```powershell
scp -P PORT vast_upload\pine_train_bundle.zip root@IP:/workspace/
ssh -p PORT root@IP
cd /workspace
unzip -q pine_train_bundle.zip -d pine
cd pine
```

If your instance uses `/root` instead of `/workspace`, use that path consistently.

## Step 4 — Train on the instance

```bash
chmod +x scripts/vast_train.sh
bash scripts/vast_train.sh
```

Or manually:

```bash
pip install -r scripts/requirements-train.txt
python3 -u scripts/retrain_yolo.py \
  --weights runs/retrain/mealybug_v2/weights/best.pt \
  --name mealybug_fix500 \
  --epochs 100 \
  --batch 16 \
  --device 0
```

**Out of memory?** Use `--batch 8` or `--batch 4`.

**Session died?** Resume:

```bash
python3 -u scripts/retrain_yolo.py --name mealybug_fix500 --resume --epochs 100 --batch 16
```

## Step 5 — Download `best.pt` to your PC

```powershell
scp -P PORT root@IP:/workspace/pine/runs/retrain/mealybug_fix500/weights/best.pt D:\old_PINE\runs\retrain\mealybug_fix500\weights\
```

Create the local folder first if needed.

## Step 6 — Export TFLite on Windows (recommended)

TFLite export is easier on your dev PC:

```powershell
cd D:\old_PINE
.\.venv\Scripts\pip install -r scripts\requirements-export.txt
.\.venv\Scripts\python.exe scripts\retrain_yolo.py --export-only runs\retrain\mealybug_fix500\weights\best.pt
copy runs\retrain\mealybug_fix500\weights\best_float32.tflite assets\model\best.tflite
```

## Step 7 — Calibrate thresholds

```powershell
.\.venv\Scripts\python.exe scripts\sweep_detection_threshold.py --quick --model runs\retrain\mealybug_fix500\weights\best.pt
```

Update `lib/core/constants.dart` from `runs/calibration/threshold_sweep.json`.

## Step 8 — Test the app

```powershell
.\scripts\run_debug.ps1 -SupabaseUrl '...' -SupabaseAnonKey '...'
```

Try close-up and **wide** field photos with **Accuracy mode** when available.

---

## Cost / time (rough)

| GPUs | ~100 epochs on ~5k images |
|------|---------------------------|
| RTX 3090 | ~2–6 hours train |
| RTX 4090 | Often faster |

Stop the instance when download finishes so you are not charged for idle GPU time.

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| CUDA not found | Pick a CUDA template; `nvidia-smi` on instance |
| OOM | `--batch 8` |
| `data.yaml` paths | Train from project root where `datasets/` lives |
| TFLite fails on Vast | `--no-export` on cloud; export on Windows only |

See also **`RUN.md` §6**.
