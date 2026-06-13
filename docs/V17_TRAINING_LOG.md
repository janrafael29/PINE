# MEALYBUG V17 Training Log

**Config:** YOLO26s | **1280px** | AdamW | batch=24 | 2× RTX 5090  
**Dataset:** 13,664 train (SAM-tightened labels) | val/test: 1,952 images  
**Run name:** `mealybug_v17_sam-2`  
**Start weights:** `mealybug_v16_selffix/weights/best.pt`  
**Started:** 2026-05-27 ~13:14 UTC+8  
**Stopped:** early stop / abort around 2026-05-27 ~13:26 UTC+8 (epochs run: **17/70**)

---

## What changed vs V16
- Replaced train labels with **SAM-tightened** boxes (generated via `scripts/sam_tighten_boxes.py`, SAM weights `sam_b.pt`).
- Kept the same training data YAML (`data_v15.yaml`) for object class setup / splits.

---

## Training command (Vast)
```bash
yolo detect train \
  model=/workspace/runs/train/mealybug_v16_selffix/weights/best.pt \
  data=/workspace/data_v15.yaml \
  epochs=70 imgsz=1280 batch=24 \
  optimizer=AdamW lr0=0.001 lrf=0.01 cos_lr=False \
  patience=15 close_mosaic=10 \
  overlap_mask=True mask_ratio=4 \
  copy_paste=0.3 copy_paste_mode=flip \
  project=/workspace/runs/train name=mealybug_v17_sam-2 \
  device=0,1
```

---

## Validation metrics during training (val split)

Best validation **mAP@0.5** observed: **22.0%** at **epoch 2**.

| Epoch | Time (s) | Box Loss | Cls Loss | P (%) | R (%) | mAP@50 (%) | mAP@50-95 (%) |
|-------|-----------|-----------|----------|--------|-------|-------------|-----------------|
| 1 | 122.2 | 1.582 | 2.343 | 46.5 | 17.5 | 19.5 | 6.6 |
| 2 | 228.3 | 1.417 | 1.998 | 18.6 | 46.1 | **22.0** | 7.4 |
| 3 | 333.3 | 1.358 | 1.831 | 13.8 | 50.7 | 21.2 | 7.3 |
| 4 | 436.5 | 1.309 | 1.694 | 14.9 | 44.8 | 18.4 | 6.0 |
| 5 | 539.7 | 1.268 | 1.593 | 13.0 | 46.9 | 18.8 | 6.1 |
| 6 | 643.6 | 1.241 | 1.524 | 12.2 | 42.3 | 15.5 | 5.0 |
| 7 | 746.7 | 1.234 | 1.480 | 18.2 | 36.4 | 16.3 | 5.5 |
| 8 | 849.5 | 1.252 | 1.464 | 12.8 | 41.1 | 15.9 | 5.1 |
| 9 | 952.9 | 1.230 | 1.430 | 14.3 | 38.9 | 15.5 | 5.1 |
| 10 | 1057.2 | 1.210 | 1.363 | 11.5 | 38.9 | 15.0 | 5.1 |
| 11 | 1160.5 | 1.205 | 1.350 | 12.5 | 36.6 | 14.8 | 5.0 |
| 12 | 1263.4 | 1.220 | 1.317 | 26.9 | 26.1 | 16.0 | 5.2 |
| 13 | 1366.6 | 1.194 | 1.278 | 16.6 | 29.1 | 13.8 | 4.6 |
| 14 | 1470.5 | 1.158 | 1.237 | 15.0 | 34.7 | 15.0 | 4.9 |
| 15 | 1573.8 | 1.170 | 1.227 | 12.1 | 27.9 | 11.8 | 4.0 |
| 16 | 1677.0 | 1.154 | 1.194 | 13.0 | 29.8 | 12.5 | 4.3 |
| 17 | 1780.6 | 1.157 | 1.184 | 13.9 | 30.1 | 12.7 | 4.1 |

---

## Held-out test evaluation (after training)

Reported final test (legacy labels) score:
- **mAP@0.5:** **22.1%**
- **Precision / Recall:** **18.7% / 46.3%**

---

## Conclusion
V17 (SAM-tighten) failed to improve mealybug localization at this scale; metrics collapse after the short early training window.

Recommendation: do not deploy v17. Use v16 labels and avoid SAM-tightening for this dataset resolution.

