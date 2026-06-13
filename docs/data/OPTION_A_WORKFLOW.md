# Option A workflow (PINYA-PIC)

**Roboflow** = cloud backup + augment/export only (no Label Assist credits).  
**Local YOLO** = auto-annotate new photos.  
**CVAT / Label Studio** = human review (free tier or self-host).  
**Vast / local train** = YOLO26 + TFLite for the app.

Your ~17k images are already on Roboflow (`pine3` / Mealybug Detection batches).

---

## Field day (200+ new photos)

**Team folders on Drive (era, ghaz, jan, …):** see **`docs/data/FIELD_DAY_INGEST.md`** and:

```powershell
.\scripts\field_day_from_drive.ps1 -Source "D:\path\to\parent" -MarkEmpty
```

### 1. Copy photos from phone

Put all new images in one folder, e.g. `D:\field_photos\2026-05-21\`, or sync the shared Drive parent folder to PC.

### 2. Auto-label (free)

```powershell
cd D:\old_PINE
.\scripts\field_day_option_a.ps1 -Source "D:\field_photos\2026-05-21" -MarkEmpty
```

Or (strict boxes — detect then shrink to pest pixels):

```powershell
.\.venv\Scripts\python.exe scripts\auto_label_yolo.py --source "D:\field_photos\2026-05-21" --mark-empty --tighten
```

Output: `field_batches\<date>_<name>\images\`, `labels\`, `manifest.json`.

**Re-annotate original ~4k:** `labeling_system/REANNOTATE_4K.md` (separate folder, not the 17k aug export).  
**Tighten / click-label:** `labeling_system/README.md`.

Default model: `runs/retrain/mealybug_v2/weights/best.pt`  
Default conf: **0.25** (tune down to **0.20** if many misses; up to **0.35** if too many false boxes).

### 3. Review labels (pick one)

| Tool | Cost | Notes |
|------|------|--------|
| [CVAT](https://app.cvat.ai) | Free tier | Import dataset + YOLO 1.1 labels; best Roboflow-like review UI |
| [Label Studio](https://labelstud.io) | Free self-host | Good if you already use it |
| LabelImg / AnyLabeling | Free | Offline, simpler |

Fix: missed bugs, wrong boxes, empty negatives.

**Boxing rules (one pest per box):** see **`docs/data/BOXING_GUIDELINES.md`**.

**500-image quality pass (val/test worst labels):**

```powershell
cd D:\old_PINE
.\scripts\build_fix_set.ps1
# optional new field photos first:
.\scripts\build_fix_set.ps1 -FieldDir "D:\field_photos\2026-05-21" -FieldMax 100
```

Upload `fix_sets\fix500_*\cvat_import.zip` to CVAT (YOLO 1.1). After export, put labels in `labels_reviewed/` and run `scripts\merge_fix_set_review.py`.

### 4. Merge into training folder

```powershell
.\.venv\Scripts\python.exe scripts\merge_field_batch.py --batch field_batches\2026-05-21_field_photos
```

Adds images + labels to `datasets/train/`.

### 5. Optional — Roboflow backup (small batch only)

- Browser upload **~200 images** + labels (not 16k at once).
- Or zip API: `scripts/roboflow_upload_zip.ps1` (see script header).
- **Do not** use Label Assist (credits).

### 6. Augment + export (when ready to train)

On Roboflow: **Versions → Generate (4×)** → **Export → YOLO**.

Or keep training from local `datasets/` + `mealybug.v10-8th-yolo26n.yolo26`.

### 7. Train + ship app model

See **RUN.md §6**:

- Audit/dedup scripts (when restored)
- Train: `yolo26n`, 100 epochs on Vast or `scripts/train_gpu_100.ps1`
- Export TFLite `nms=False`, float32 if needed
- Copy to `assets/model/best.tflite`

---

## Quick reference

| Step | Tool |
|------|------|
| Store 17k backup | Roboflow (done) |
| Pre-label new images | `scripts/auto_label_yolo.py` |
| Review | CVAT / Label Studio |
| Merge to train set | `scripts/merge_field_batch.py` |
| Augment | Roboflow Generate (optional) |
| Train | Local / Vast + Ultralytics |
| App | `assets/model/best.tflite` |

---

## Requirements checklist (Option A)

- [x] A1–A6 dataset + YOLO — Roboflow + local `datasets/`
- [x] B1 auto-annotate — local YOLO
- [x] B2 no credits — local predict
- [x] B3 review — CVAT
- [ ] C1 augment — Roboflow when training
- [ ] D1–D4 train + TFLite — after field merge
