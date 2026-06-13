# Mealybug boxing guidelines (PINYA-PIC)

Use these rules for **all** CVAT review, field photos, and Roboflow/local exports. The app counts **one mealybug per box** at inference time.

## Core rules

1. **One box = one mealybug** (singular pest).
   - Two bugs touching → **two boxes** if each pest is distinguishable.
   - A dense cluster where individuals are not separable → use team judgment: split when you can see separate bodies; otherwise one tight box per **clearly separate** individual only.

2. **Shape** (PC `labeling_system` default: **auto-polygon**)
   - **Polygon** (preferred in click app): mask outline around one pest — tighter than a rectangle. YOLO-seg line format (`0 x1 y1 x2 y2 …`).
   - **Box** (optional `--shape box`): smallest axis-aligned rectangle around that pest.
   - Do **not** include large clean leaf/fruit area “for context.”

3. **Negatives**
   - Image has **no** mealybug → **empty** `.txt` label file (zero lines).
   - Do not delete the label file; leave it empty.

4. **Class**
   - Single class: `mealybug` (class id `0` in YOLO lines).

5. **Do not label**
   - Scale insects that are clearly not mealybug (unless your project lead says otherwise).
   - Blur-only guesses: skip or mark image for discard in `notes` (see fix-set manifest).

## YOLO line format

Each line: `0 cx cy w h` (normalized 0–1, center + size).

Example: one bug centered in the image:

```
0 0.512 0.481 0.042 0.038
```

## Common fixes in the 500-image review pass

| Problem | Fix |
|--------|-----|
| One huge box over many bugs | Split into one box per visible individual |
| One box for whole leaf | Shrink to each pest |
| Missed small white specks | Add boxes (zoom in CVAT) |
| Box on stain/sap/scale | Delete box |
| No bugs in image | Delete all boxes; save empty label |
| Duplicate overlapping boxes | Keep one tight box per bug |

## CVAT workflow (fix set)

1. Import `fix_sets/<name>/cvat_import.zip` (YOLO 1.1, pre-labels).
2. Review **every** image; do not bulk-accept.
3. Export → **YOLO 1.1** → save as `labels_reviewed/`.
4. Run merge script (see `fix_sets/<name>/README.md`).

## Automated tighten (optional)

After pre-label or export, optional PC pass: **`labeling_system/tools/tighten_batch.py`** (see `labeling_system/README.md`). Not used in the app. Always spot-check previews — blur and yellow fruit can fool the mask.

## Quality check before merge

- Spot-check 20 images: count boxes ≈ visible individuals.
- Negatives: empty files present where intended.
- No class ids other than `0`.

## After review

```powershell
cd D:\old_PINE
.\.venv\Scripts\python.exe scripts\merge_fix_set_review.py --fix-set fix_sets\fix500_YYYYMMDD
```

Then retrain YOLO and re-run threshold sweep (see `RUN.md`).
