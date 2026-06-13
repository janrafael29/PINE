# V18 CVAT Audit Setup — Phase 0.4

Use this checklist to create the **v18_audit** labeling project for Phase 2 (annotation quality).

---

## 1. Create project

| Field | Value |
|-------|-------|
| **Name** | `PINYA-PIC v18_audit` |
| **Labels** | `mealybug` (rectangle only) |
| **Rules doc** | `docs/data/BOXING_GUIDELINES.md` |

---

## 2. Import priority queues (in order)

Generate queues from confusion export:

```powershell
cd D:\old_PINE
python scripts/export_confusion_cases.py --max-images 1952 --samples-per-class 50 --conf 0.25
```

| Queue | Source folder | Priority | Target count |
|-------|---------------|----------|-------------|
| **Q1 — False negatives** | Audit list from FN manifest | Highest | 300–400 images |
| **Q2 — Poor localization** | `poor_localization/` samples + low IoU list | High | 200–300 |
| **Q3 — False positives** | `fp/` + white-residue failures | Medium | 150–200 |
| **Q4 — Pseudo-label spot-check** | Top v16 self-train add-count images | Medium | 200–300 |

**CVAT import:** Task per queue → upload images from `datasets/mealybug_v13afix/test/images/` (match filenames in `docs/thesis/assets/confusion_cases_v16/manifest.json`).

---

## 3. Review rules (summary)

1. **Tight box** around visible wax / cluster — improves mAP@0.5:0.95  
2. **Cluster policy:** one box per **visible cluster** (document choice; stay consistent)  
3. **Small pests:** do not skip specks if clearly mealybug  
4. **White dust / fungus / glare:** no box  
5. **Empty image:** delete all boxes (true negative)  
6. **Do not** accept model box blindly — verify visually  

Full rules: `docs/data/BOXING_GUIDELINES.md`

---

## 4. Export after review

Export YOLO 1.1 detect format → merge into:

```
datasets/mealybug_v18_audit/
  images/
  labels/
```

Track in spreadsheet:

| Column | Example |
|--------|---------|
| `image` | test_001468.jpg |
| `queue` | Q1_FN |
| `action` | add_box / tighten / remove_fp / empty |
| `reviewer` | initials |
| `date` | 2026-06-12 |

---

## 5. Phase 0 exit (this item)

- [ ] CVAT project created  
- [ ] Q1 task created with ≥ **50** seed images from FN export  
- [ ] Annotators read boxing guidelines  
- [ ] Export path agreed (`mealybug_v18_audit`)  

---

## 6. Annotator roster

| Name | Role | Queues |
|------|------|--------|
| | Annotation lead | Q1, Q2 |
| | Reviewer 2 | Q3, Q4 |
| | ML lead | Spot-check 10% |

Fill before Phase 2 kickoff (Week 2).
