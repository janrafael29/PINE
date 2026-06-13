# MEALYBUG V20 Training Log

**Strategy:** Fix training labels (audit + auto-fix), then train **from scratch** — not another v16 fine-tune (v17/v18/v19 lesson).

**Hardware:** 1× H100 SXM (Vast.ai `219.86.90.208:40050`)  
**Dataset:** `mealybug_v20` (built from `mealybug_v20_audit` after Wave 1 auto-fix)  
**Eval protocol (locked):** corrected test, 1,952 images, conf=0.001, IoU=0.6, imgsz=1280 — compare to v16 **73.3%** mAP@0.5

---

## Runs

| Run | Model | Status | Notes |
|-----|-------|--------|-------|
| `mealybug_v20s` | YOLO26s | 🔄 In progress | Started 2026-06-10 ~14:34 UTC; ~50% val mAP@0.5 by ep ~12 |
| `mealybug_v20m` | YOLO26m | ⬜ Queued | After v20s completes |

### v20s command (from `v18_full_pipeline_vast.sh`)

```bash
yolo detect train \
  model=yolo26s.pt \
  data=/workspace/pine/datasets/mealybug_v20/data.yaml \
  epochs=80 imgsz=1280 batch=16 \
  optimizer=AdamW lr0=0.0005 lrf=0.01 cos_lr=True \
  warmup_epochs=3 patience=25 close_mosaic=15 \
  iou=0.45 box=7.5 dropout=0.1 \
  hsv_h=0.015 hsv_s=0.5 hsv_v=0.4 degrees=10 translate=0.1 scale=0.5 fliplr=0.5 \
  mosaic=1.0 copy_paste=0 \
  project=runs/retrain name=mealybug_v20s
```

### v20m command (queued)

```bash
yolo detect train \
  model=yolo26m.pt \
  data=/workspace/pine/datasets/mealybug_v20/data.yaml \
  epochs=120 imgsz=1280 batch=8 \
  optimizer=AdamW lr0=0.001 lrf=0.01 cos_lr=True \
  warmup_epochs=3 patience=30 close_mosaic=10 \
  project=runs/retrain name=mealybug_v20m
```

---

## Promotion gates

| Gate | mAP@0.5 | Recall | mAP@0.5:0.95 |
|------|--------:|-------:|-------------:|
| M1 (v20s) | ≥ 78% | ≥ 70% | ≥ 45% |
| M3 (v20m) | ≥ 85% | ≥ 80% | ≥ 55% |

Ship only if model beats v16 on mAP@0.5, recall, and mAP@0.5:0.95 (precision ≥ 78%).

---

## v21 (queued)

Multi-model consensus labels on train set — see `docs/training/MODEL_PERFORMANCE_ALL_VERSIONS.md` § V21.

---

*Updated: 2026-06-10*
