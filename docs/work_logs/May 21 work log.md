# Work log — 21 May 2026

Supplement to **`docs/RECENT_WORK_LOG.md`**. This entry covers **`mealybug_fix500`** fine-tune + **TFLite ship**, **Supabase detection image export** for analysis, **thesis figure/table errata** notes, and **training roadmap** documentation for the full **~17k** Roboflow v10 run (Vast vs local GPU).

**Stack reminder:** Flutter (Android), **YOLO26n** → **TFLite** (`nms=False`, Dart NMS), Supabase (Auth / Postgres / Storage), Ultralytics training on **`datasets/`** (~3.6k train after fix-set merge).

---

## 1) Model: `mealybug_fix500` fine-tune and app bundle

**Goal:** Fine-tune from **`runs/retrain/mealybug_v2/weights/best.pt`** on the expanded local dataset (**~3,621 train** / **914 val** / **460 test** in `datasets/`, including the reviewed **fix500** labels merged into `datasets/train`).

**Artifacts (this machine):**

| Item | Path / note |
|------|-------------|
| Run folder | `runs/retrain/mealybug_fix500/` |
| Export | `runs/retrain/mealybug_fix500/weights/best_saved_model/` |
| Shipped app model | `assets/model/best.tflite` (~**9.8 MB**, updated **21 May 2026**) |

**Export / install (typical):**

```powershell
.\.venv\Scripts\python.exe scripts\retrain_yolo.py --export-only runs\retrain\mealybug_fix500\weights\best.pt
copy runs\retrain\mealybug_fix500\weights\best_saved_model\best_float32.tflite assets\model\best.tflite
```

**Field-test note (same reference photo):** Per **`docs/training/TRAIN_V10_17K.md`**, **`fix500`** still scored **lower** on a white mealybug cluster than older **`mealybug_v2`** (~**19%** vs ~**38%** best box confidence). Treat **`fix500`** as a stepping stone, not the final accuracy target.

**Next train (documented, not run yet):** Full **Roboflow v10** export **`mealybug.v10-8th-yolo26n.yolo26/`** (~**16,175** train aug) → run name **`mealybug_v10`** on **Vast** (see **`docs/training/TRAIN_V10_17K.md`**, **`docs/training/VAST_TRAINING.md`**).

---

## 2) Supabase CSV → detection images zip

**Source:** `results/detections_rows.csv` (**826** detection rows, **410** unique `image_url` values, public Storage URLs).

**Tool:** `scripts/extract_detection_images.py`

```powershell
python scripts/extract_detection_images.py
```

**Outputs:**

| Output | Description |
|--------|-------------|
| `results/detections_images/` | One file per unique URL (`{user_id}_{timestamp}.jpg`) |
| `results/detections_images/manifest.csv` | Maps each `detection_id` → `zip_filename` + confidence/count |
| `results/detections_images.zip` | ~**757 MB**, **411** entries (410 images + manifest) |

Use the manifest when pairing exported images back to thesis/statistician tables.

---

## 3) Thesis / manuscript alignment notes

Added **`docs/thesis/THESIS_FIGURES_TABLES_ERRATA.md`** — code-vs-PDF checklist for defense prep, including:

- Deployed threshold **20% (0.20)** in `AppConstants.detectionThreshold`, not **30%** in Chapter IV prose.
- Conceptual **ERD (Figure 5)** vs implemented Supabase/SQLite schema (`profiles`, `fields`, `detections`).
- **YOLO11n** (archived val metrics) vs **YOLO26n TFLite** (deployed) naming in Abstract/Keywords.
- Table **4.8** long-press vs edit-button wording; Figure **4.6** / **4.7** caption fixes.

Apply edits in the Word/LaTeX source, then re-export the PDF.

---

## 4) Training hardware reality check (planning)

Documented for the team (no code change):

- **Ryzen 7 5700G + 16 GB RAM** (integrated graphics) is **not** a practical box for **17k × 100-epoch** YOLO training in ~8–10 hours; Ultralytics expects **CUDA (NVIDIA)**.
- Practical paths: **Vast.ai** / cloud GPU, **RTX 3050 Ti laptop** (4 GB, slower), or add a discrete NVIDIA GPU.
- **17k augmented data ≠ field close-ups** — crown/field photos still need **CVAT review** + merge (`docs/data/FIELD_DAY_INGEST.md`, `docs/data/BOXING_GUIDELINES.md`) before expecting better phone scans.

---

## 5) Related docs touched or referenced today

| Doc | Purpose |
|-----|---------|
| `docs/training/TRAIN_V10_17K.md` | v10 17k train + compare fix500 vs v2 on field photo |
| `docs/training/VAST_TRAINING.md` | fix500 / Vast bundle + SSH train steps |
| `docs/data/OPTION_A_WORKFLOW.md` | Roboflow + CVAT + field-day merge |
| `docs/thesis/THESIS_FIGURES_TABLES_ERRATA.md` | Manuscript corrections |

---

## 6) Open items (carry forward)

- [ ] Run **`mealybug_v10`** on **Vast** (or long local GPU session); export TFLite; retest **same** field reference photo.
- [ ] Continue **field batch** CVAT → `merge_field_batch.py` → optional **`mealybug_field_v11`**.
- [ ] Apply **thesis errata** in source document before final PDF.
- [ ] Decide whether to **revert app model** to **`mealybug_v2` TFLite** for demos if fix500 field scores stay worse until v10/v11 ships.

---

*End of work log — 21 May 2026.*
