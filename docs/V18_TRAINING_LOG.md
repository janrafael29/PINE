# MEALYBUG V18 Training Log

**Config:** YOLO26s | **1280px** | AdamW (optimizer: auto) | batch=24 | 2× RTX 5090  
**Dataset:** 13,664 train (restored pre-SAM labels) | val/test: 1,952 images  
**Run name:** `mealybug_v18_nosam`  
**Start weights:** `mealybug_v16_selffix/weights/best.pt`  
**Started:** 2026-05-27 ~13:14 UTC+8  
**Stopped:** aborted around 2026-05-27 ~13:27 UTC+8 (epochs run: **39/70**)

---

## What changed vs V16
- Used **pre-SAM** train labels (no SAM label tightening during training).
- Aggressive fine-tune settings that were suspected to destabilize learning:
  - `patience=0` (no early stop, but we aborted after collapse)
  - `lr0=0.01` (higher than v16 fine-tune)
  - `cos_lr=False`
  - kept `copy_paste=0.3` with `copy_paste_mode=flip`

---

## Training command (Vast)
```bash
yolo detect train \
  model=/workspace/runs/train/mealybug_v16_selffix/weights/best.pt \
  data=/workspace/data_v15.yaml \
  epochs=70 imgsz=1280 batch=24 \
  optimizer=auto lr0=0.01 lrf=0.01 cos_lr=False \
  patience=0 close_mosaic=10 \
  overlap_mask=True mask_ratio=4 \
  copy_paste=0.3 copy_paste_mode=flip \
  project=/workspace/runs/train name=mealybug_v18_nosam \
  device=0,1
```

---

## Validation metrics during training (val split)

Val mAP collapsed quickly after the first couple epochs.

**Best val mAP@0.5:** **40.1%** (epoch 1)  
**By epoch 38:** **10.5%**  
**Final captured epoch 39:** **10.1%**

| Epoch | Time (s) | Box Loss | Cls Loss | P (%) | R (%) | mAP@50 (%) | mAP@50-95 (%) |
|-------|-----------|-----------|----------|--------|-------|-------------|-----------------|
| 1 | 180.6 | 1.592 | 2.389 | 23.4 | 62.0 | **40.1** | 14.9 |
| 2 | 315.4 | 1.333 | 1.777 | 19.2 | 54.1 | 28.0 | 9.6 |
| 3 | 446.7 | 1.343 | 1.790 | 15.8 | 39.4 | 17.6 | 5.8 |
| 4 | 570.8 | 1.366 | 1.777 | 17.7 | 50.4 | 24.6 | 8.5 |
| 5 | 694.5 | 1.316 | 1.671 | 19.5 | 46.7 | 22.8 | 8.1 |
| 10 | 1312.9 | 1.266 | 1.422 | 14.5 | 36.0 | 16.3 | 5.5 |
| 20 | 2547.8 | 1.178 | 1.137 | 17.4 | 26.1 | 12.2 | 4.0 |
| 30 | 3782.8 | 1.111 | 0.961 | 17.0 | 20.8 | 10.8 | 3.7 |
| 38 | 4769.4 | 1.064 | 0.890 | 23.0 | 18.0 | **10.5** | 3.6 |
| 39 | 4893.3 | 1.052 | 0.869 | 20.3 | 18.1 | 10.1 | 3.4 |

---

## Held-out test evaluation (after training)

No held-out `split=test` evaluation was captured for v18 in the local artifacts we downloaded.

---

## Conclusion
V18 (no-SAM fine-tune) failed to preserve v16’s improvements and instead **unlearned** toward low mAP.

Recommendation: do not use v18 as a thesis/app model. If retrying, prefer v16 labels and stabilize LR:
- start from `v16` best weights
- use lower LR (e.g. `lr0=0.0001`), re-enable `cos_lr=True`
- keep `copy_paste=0` and set `patience` back to a non-zero value (e.g. 25)

