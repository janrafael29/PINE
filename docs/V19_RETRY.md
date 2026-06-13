# V19 Retry (fine-tune from v16)

**Goal:** Train v19 again, **download weights immediately**, then eval on **v16-corrected test** (same GT as 73.3% headline).

**Do not** run `fix_test_labels.py` with v19 for the comparison eval.

---

## 1. Pick instance

| Instance | Disk | Notes |
|----------|------|--------|
| **2× RTX 5090** | ~67 GB | **Preferred** — fits dataset + run |
| 1× RTX 5090 | ~25 GB | Tight; only if zip already there and you delete zip after unzip |

Update IP/port in commands from Vast **SSH** button.

---

## 2. Build small bundle on PC (~20 MB)

```powershell
cd D:\old_PINE
.\scripts\v19_retry_bundle.ps1
```

Upload:

```powershell
$key="$env:USERPROFILE\.ssh\vast_ed25519"
$ip="YOUR_IP"
$port=YOUR_PORT
ssh -i $key -p $port root@$ip "mkdir -p /workspace/pine"
scp -i $key -P $port D:\old_PINE\vast_upload\v19_retry_bundle.zip root@${ip}:/workspace/
```

---

## 3. On Vast — dataset + train

```bash
cd /workspace
# If pine_v13afix_train_bundle.zip not present, upload it first (8.3 GB).

apt-get update -qq && apt-get install -y -qq unzip
mkdir -p /workspace/pine
unzip -q -o v19_retry_bundle.zip -d /workspace/pine
# If dataset zip exists and pine/datasets missing:
unzip -q -o pine_v13afix_train_bundle.zip -d /workspace/pine

cd /workspace/pine
pip install -U pip
pip install -r scripts/requirements-train.txt

# Verify
ls datasets/mealybug_v13afix/train/images | wc -l   # 13664
ls runs/retrain/mealybug_v16_selffix/weights/best.pt

# Train — 1 GPU first (stable). Use 2 GPU only if this works.
yolo detect train \
  model=/workspace/pine/runs/retrain/mealybug_v16_selffix/weights/best.pt \
  data=/workspace/pine/data_v15.yaml \
  imgsz=1280 epochs=100 batch=8 \
  optimizer=AdamW lr0=0.0005 lrf=0.01 cos_lr=True \
  warmup_epochs=3 patience=25 \
  iou=0.45 box=7.5 close_mosaic=15 \
  dropout=0.1 weight_decay=0.0005 copy_paste=0 \
  project=/workspace/pine/runs/train name=mealybug_v19_retry_v1 \
  device=0 exist_ok=True
```

Detach: **Ctrl+B**, **d**

---

## 4. Download weights (do this before stopping instance)

On PC:

```powershell
.\scripts\v19_download_results.ps1 -Ip YOUR_IP -Port YOUR_PORT -RunName mealybug_v19_retry_v1
```

Or manual:

```powershell
scp -i $key -P $port -r root@$ip:/workspace/pine/runs/train/mealybug_v19_retry_v1 `
  D:\old_PINE\runs\retrain\
```

---

## 5. Corrected-test eval (fair vs v16 73.3%)

Use **v16-corrected labels** (18,891 boxes). On PC with junction or on Vast.

```bash
yolo detect val \
  model=/workspace/pine/runs/train/mealybug_v19_retry_v1/weights/best.pt \
  data=/workspace/pine/data_v15.yaml \
  split=test imgsz=1280 conf=0.001 iou=0.6
```

(`data_v15.yaml` uses `test/images`; point `test/labels` to corrected snapshot.)

---

## 6. Compare

| Model | Protocol | mAP@0.5 |
|-------|----------|---------|
| v16 | v16-corrected test | **73.3%** |
| v19 | same corrected test | ? |

If v19 **≤ 73.3%**, keep v16 for thesis + app.
