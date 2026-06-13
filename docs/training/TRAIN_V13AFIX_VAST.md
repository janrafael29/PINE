# Train mealybug_v13afix on Vast

**Data (70/20/10 split, seed 42):**

| Split | Count | % |
|-------|------:|--:|
| Train | **13,664** | 70% |
| Val | **3,904** | 20% |
| Test | **1,952** | 10% |
| **Total** | **19,520** | |

Includes v10 + Va field + fix500 unique + field hflip aug.

**Note:** Test is **not** the original 462-image v10 set. To compare vs v11/v12, also eval on `mealybug.v10-8th-yolo26n.yolo26/data.yaml`.  
**Starts from:** `mealybug_v12/weights/best.pt`  
**Output:** `runs/retrain/mealybug_v13afix/weights/best.pt`

## 1. Upload

Upload `vast_upload/pine_v13afix_train_bundle.zip` (~4.5 GB) to `/workspace/`.

## 2. Train (paste in Vast terminal)

```bash
cd /workspace
unzip -q pine_v13afix_train_bundle.zip -d pine
cd pine
bash scripts/vast_train_v13afix.sh
```

If GPU runs out of memory:

```bash
BATCH=8 bash scripts/vast_train_v13afix.sh
```

Two GPUs (e.g. 2× RTX 5090):

```bash
nvidia-smi
DEVICE=0,1 WORKERS=16 bash scripts/vast_train_v13afix.sh
```

`DEVICE` defaults to `0`. With multiple GPUs, Ultralytics splits `BATCH` across devices (~8 per GPU when `BATCH=16`).

## 3. Download

From Vast file browser:

```
/workspace/pine/runs/retrain/mealybug_v13afix/weights/best.pt
```

Save on PC to:

```
D:\old_PINE\runs\retrain\mealybug_v13afix\weights\best.pt
```

(Folder already created locally.)

## 4. Compare vs v12 / fix500

```powershell
cd D:\old_PINE
python scripts/evaluate_model_accuracy.py --model runs/retrain/mealybug_v13afix/weights/best.pt --data mealybug.v10-8th-yolo26n.yolo26/data.yaml --conf 0.12
```

Target to beat: **fix500 45.3%** or **v12 43.8%** test mAP@0.5.
