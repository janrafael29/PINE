# Work log — 25 May 2026

Covers **v12 report improvements**, **v14 pipeline planning** (1280 + Va + fix500), **Va/fix500 augmentation**, **defense prep documents**, and **thesis paste fixes**.

**Stack reminder:** Flutter (Android), **YOLO26n** → **TFLite** (`nms=False`, Dart NMS), Supabase, Ultralytics training. Shipped model: **mealybug_v13afix** (61.0% mAP@0.5 native test).

---

## 1) v12 report — layout fixes, compression, and context panel

**Goal:** Fix legend/text overflow in the PNG report, compress output, and add training context (augmentations, annotation method, box density, dataset diversity).

**Changes to `scripts/generate_model_report.py`:**

- Pie chart legends moved **below** each donut (was overlapping histogram y-axis).
- Two-paragraph header description replacing single long line.
- **New "Training & annotation context" panel** on the report:
  - Train-time augmentations (mosaic, HSV, fliplr, RandAugment, erasing; no mixup/cutmix).
  - Dataset-level aug (~5× Roboflow on ~3k sources).
  - Manual annotation (CVAT/Roboflow), not SAM3; rules in `docs/data/BOXING_GUIDELINES.md`.
  - Va (~877 field images) **not** in v12 training.
  - Box density stats (train max **157**, p99 **73**, median **2**; test max **67**).
- PNG compression: `optimize=True`, `compress_level=9`, DPI 110 (~**217–285 KB** vs ~344 KB before).
- Also outputs `*_compressed.jpg` (~203–257 KB).
- New CLI args: `--dpi`, `--jpeg-quality`.

**Outputs:**

| File | Size |
|------|------|
| `runs/retrain/mealybug_v12/report/pinya_mealybug_v12_report.png` | ~285 KB |
| `pinya_mealybug_v12_report_compressed.jpg` | ~257 KB |
| `pinya_mealybug_v12_report.html` | updated |

Regenerate: `py -3 scripts/generate_model_report.py --run mealybug_v12 --skip-val`

---

## 2) Dataset analysis — box density, augmentation, annotation, diversity

Ran a full label scan on the v12 training data (`mealybug.v10-8th-yolo26n.yolo26`):

| Split | Images | Max boxes/image | p99 | Median | ≥50 boxes | ≥20 boxes |
|-------|-------:|----------------:|----:|-------:|----------:|----------:|
| Train | 16,175 | **157** | 73 | 2 | 280 | 1,696 |
| Valid | 923 | 135 | 48 | 3 | 8 | 111 |
| Test | 462 | 67 | 50 | 4 | 5 | 46 |

Densest train images: `mealybug-23-*` variants (157 boxes), `mealybug-87-*` (118 boxes). Most images are sparse (median 2).

**Key clarifications documented:**

- **Va = field batch** (~877 images) — separate from v12.
- **Annotation = manual** (CVAT/Roboflow human review) — not SAM3.
- **640×640** = **deploy + benchmark** size; v12 trained at **1024**; YOLO letterboxes at train time.
- **Dataset diversity** — moderate (large aug train, many tiny pests, empty negatives); limited by Roboflow-style photos; field domain gap until Va is merged.

---

## 3) Va + fix500 augmentation (`scripts/augment_va_fix500.py`)

**Goal:** Augment Va and fix500 to increase effective field/review data in the training pool (v10 Roboflow aug left untouched).

**Pipeline:** `augment_yolo_subset.py` (refactored to `augment_batch()` function) — flip, 90° rotate, ±15° rotate, mild brightness/contrast, light noise. Sanitized label boxes (clipped out-of-bounds coords). Updated `GaussNoise` API for albumentations v2.

| Target | Sources | Copies per | Created | Total |
|--------|--------:|-----------:|--------:|------:|
| **fix500** (`fix_sets/fix500_20260520`) | 500 | 2× | +1,000 | **1,500** |
| **Va** (`mealybug_va_field/train`) | 613 | 3× | +1,839 | **2,452** |
| **Va in v10+** (`ann_*` train only) | 877 | 3× | +2,631 | **19,683** |

Report: `runs/augment_va_fix500_report.json`

### Renamed augmented copies

Renamed to versioned prefixes for traceability (`scripts/rename_augmented_va_fix500.py`):

| Old pattern | New pattern | Count |
|-------------|-------------|------:|
| `*_aug0`, `*_aug1` … | `Vb_<stem>_0` … | **4,470** (Va) |
| `*_aug0`, `*_aug1` … | `Vfix500b_<stem>_0` … | **1,000** (fix500) |

---

## 4) v14 pipeline design

Planned the **v14** training pipeline (not yet executed):

**Strategy:** Roboflow v14 export @ **1280×1280** (`Fit (black edges) in`) + merge Va + fix500 → train @ `imgsz=1280` on Vast → eval native v13-style (1,952+ test, conf 0.12).

**Roboflow credits issue:** No credits available for new version. **Workaround:** train `imgsz=1280` on existing v13afix 640 data (YOLO upscales each batch), or letterbox images locally without Roboflow.

**Documented in `docs/training/V14_PIPELINE.txt`:**

- Step 1: Auto-fix annotations (add missing high-confidence labels).
- Step 2: Train YOLO26s @ 1280, batch 32, 200 epochs on 2× RTX 5090.
- Step 3: Hybrid NMS+WBF ensemble (v13afix nano + v14 small).
- Target: **80%+** mAP@0.5 (from 61.0% baseline).

Also created `scripts/audit_annotations.py` — annotation audit tool that compares model predictions against labels to find missing/ghost/loose annotations.

---

## 5) Defense prep documents

Created several thesis defense materials:

| Doc | Purpose |
|-----|---------|
| `docs/thesis/DEFENSE_CHEAT_SHEET.md` | Critical numbers, model evolution (v2 → v13afix +35.6 pp), expert validation (91.75% F1), and anticipated panel Q&A |
| `docs/thesis/DEFENSE_SCRIPT_IMPROVED.txt` | Full presentation script for all team members |
| `docs/thesis/DEFENSE_FLASHCARDS.md` | Quick-reference flashcards |
| `docs/thesis/DEFENSE_DEMO_SCRIPT_5MIN.md` | 5-minute demo walkthrough |
| `docs/thesis/THESIS_PASTE_FIXES.md` | Copy-paste blocks for Abstract, Scope, Chapter IV, threshold wording |
| `docs/thesis/THESIS_CHAPTER_IV_METRICS_SECTION.md` | Paste-ready metrics section (benchmark + model lineage + expert validation) |
| `docs/thesis/THESIS_CHAPTER_IV_MODEL_PERFORMANCE_DISCUSSION.md` | Discussion paragraphs for Chapter IV |

---

## 6) v13afix Vast bundle completed (prior session, confirmed today)

`scripts/package_v13afix_for_vast.ps1` finished:

| Item | Value |
|------|-------|
| Bundle | `vast_upload/pine_v13afix_train_bundle.zip` |
| Size | **8,405 MB** (~8.4 GB) |
| Files | 39,047 |
| Dataset | 19,520 images (70/20/10, seed 42) |
| Includes | v10 + Va field + fix500 unique + field hflip aug |

**Vast command:** `unzip -d pine; cd pine; bash scripts/vast_train_v13afix.sh`

---

## 7) Scripts added / modified

| Script | Change |
|--------|--------|
| `scripts/generate_model_report.py` | Donut legend below, context panel, compression, `--dpi`/`--jpeg-quality` |
| `scripts/augment_yolo_subset.py` | Refactored to `augment_batch()`, added `--labels-dir`, `--name-prefix`, `--version-prefix`, box sanitization, albumentations v2 fix |
| `scripts/augment_va_fix500.py` | **New** — augments Va + fix500 only (versioned `Vb_`/`Vfix500b_` prefixes) |
| `scripts/rename_augmented_va_fix500.py` | **New** — renames `*_aug*` to `Vb_`/`Vfix500b_` prefixed names |
| `scripts/audit_annotations.py` | **New** — compares model predictions vs labels, finds missing/ghost/loose boxes |

---

## 8) Open items (carry forward)

- [ ] **Retrain on Vast** — upload v13afix bundle (8.4 GB); train from v12 weights; eval native test.
- [ ] **v14 @ 1280** — train `imgsz=1280` on v13afix data (YOLO upscales) or build local 1280 letterbox export.
- [ ] **Rebuild v13afix pool** after Va/fix500 augmentation: `build_v13afix_dataset.py --augment-field --fix-corrupt --split 0.7 0.2 0.1` → re-package for Vast.
- [ ] **Threshold sweep** on v13afix if deploying with new augmented data.
- [ ] **Apply thesis paste fixes** (`docs/thesis/THESIS_PASTE_FIXES.md`) in Word before final PDF.
- [ ] **Field batch May 2025** (510 images) — still in CVAT review, not merged.

---

*End of work log — 25 May 2026.*
