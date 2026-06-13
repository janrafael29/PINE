# v10 label cleanup (automated)

Applied **2026-05-19** to `mealybug.v10-8th-yolo26n.yolo26/` with:

```bash
python scripts/audit_and_clean_yolo_labels.py \
  --root mealybug.v10-8th-yolo26n.yolo26 \
  --splits train valid test \
  --apply --backup
```

## What changed (17,560 label files)

| Fix | Count |
|-----|------:|
| Lines in → out | 139,095 → 133,266 (~4.2% removed) |
| Polygon → tight bbox | 8,681 |
| Dropped tiny noise | 3,925 |
| Dropped huge (leaf-sized) boxes | 1,894 |
| Near-duplicate dedupe | 10 |

Each edited file has a sibling `*.txt.bak` (original label).

## Why this helps mAP

- **Polygons** were exported as multi-point lines; YOLO detection training expects `cls cx cy w h`. Tight AABB from polygon removes slack around pests.
- **Tiny boxes** are often mis-clicks or compression artifacts.
- **Huge boxes** (>22% of image area) are usually whole-leaf mistakes, not mealybugs.

Cleaning **ground truth** makes validation fairer and retraining (v11) learn tighter targets.

## Human review (optional, high impact)

Priority list: `runs/label_clean/worst_for_cvat.csv` (top 500 images by boxes dropped).

Import those images + labels into [CVAT](https://www.cvat.ai/) or Roboflow and fix remaining loose boxes on dense clusters.

## Next steps

1. **Retrain** from v10 weights on cleaned labels (recommended name: `mealybug_v11`):
   - Same Vast script as v10, or shorter fine-tune (30–50 epochs).
2. **Merge field batch** (~409 images) if ready: `scripts/merge_field_batch.py`.
3. **Re-export TFLite** after v11: `scripts/retrain_yolo.py --export-only …/best.pt`.
4. Delete `**/labels.cache` under the dataset after any label edit (Ultralytics rescans).

## Bad-box removal (2026-05-24)

```powershell
python scripts/clean_bad_labels.py --root mealybug.v10-8th-yolo26n.yolo26 --apply --backup
```

| Action | Count |
|--------|------:|
| Boxes in → out | 133,266 → **118,227** (−11.3%) |
| Removed loose (≥25% vs mask) | 12,249 |
| Removed bad (`shrink_too_much`) | 2,789 |
| Minor tighten (3–25% slack) | 13,005 |

Backup: `<split>/labels/backup_before_bad_clean/`. Report: `runs/label_bad_clean/`.

## Rollback

```powershell
Get-ChildItem -Path mealybug.v10-8th-yolo26n.yolo26 -Recurse -Filter "*.txt.bak" | ForEach-Object {
  Copy-Item $_.FullName ($_.FullName -replace '\.bak$','') -Force
}
```
