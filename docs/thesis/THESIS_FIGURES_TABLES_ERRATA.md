# Thesis figures, tables, and charts — alignment check & corrections

**Scope:** Compared manuscript text extracted from `docs/thesis/THESIS V4 (1).pdf` (via `THESIS_V4_extracted.txt` in the repo) with the **current** PINYA-PIC codebase (`d:\old_PINE`).  
**Note:** The PDF itself was not edited here. Apply the fixes below in your **Word / Google Docs / LaTeX** source, then re-export the PDF.

---

## Critical factual correction (deployed model threshold)

### Issue

Chapter IV states that observations support a **“30% confidence threshold”** used in the deployed application (e.g. discussion around Figure 4.7 / confidence histogram).

### Code (source of truth)

Default **minimum score for keeping a detection** is **`0.20` (20%)**, not 30%, in `AppConstants.detectionThreshold`.

```19:31:d:\old_PINE\lib\core\constants.dart
  /// Minimum confidence threshold for displaying detections.
  /// Small pests (mealybugs) often score well below 0.9; 0.20–0.35 is typical.
  /// ...
  static const double detectionThreshold = 0.20;
```

`AppConfig.accuracy` can lower the threshold further (e.g. **0.085**) when “accuracy” mode is selected — still not 30%.

### What to change in the thesis

1. Replace **“30% confidence threshold”** with **“default 20% (0.20) minimum confidence filter”** (or “0.20 score threshold”) everywhere that refers to **deployment**, and clarify that the UI shows **per-box confidence as a percent** while filtering uses the **model score in [0, 1]**.
2. If you discuss **user-facing bands** (e.g. “low / medium / high” in recommendations), label them clearly as **UX guidance**, not as the same constant as `detectionThreshold`, or recompute examples using **0.20**.

---

## Internal contradiction (task table vs narrative)

### Issue

- **Table 4.8** includes a task row: **“Edit existing field via long-press”**.
- **Section 4.2.4 (Field Editing)** states that editing is done through **explicit edit actions**, **not** long-press.

### What to change

- Rename the Table 4.8 row to something like: **“Edit existing field (edit button / menu on field card or detail)”** to match both the app and your own narrative.

---

## Figure / caption wording

### Figure 4.6 (Diagnose tab / 7-day chart)

**Issue:** Caption reads awkwardly: *“the peak-highlighted chart is highlighted.”*  
**Fix:** Use one clear phrase, e.g. *“Figure 4.6 shows the Diagnose tab with sample data; the chart uses peak highlighting on the highest daily count.”*

### Figure 4.7 (confidence histogram)

**Issue:** Manuscript still contains a **placeholder** line: *(Insert histogram as Figure 4.7: …)*.  
**Fix:** For final submission, either **insert the actual figure** and delete the placeholder, or **remove** the placeholder if the histogram is already embedded on the previous page.

---

## Table numbering (front matter vs body)

### Issue

The **LIST OF TABLES** in the extract uses **Table 1 … Table 10** (generic titles), while the body uses **Table 4.1 … Table 4.10** style for Chapter IV.

**Fix:** Regenerate the list of tables from your editor so numbering **matches the chapter convention** (e.g. all “Table 4.x” where appropriate, or consistent global numbering per your school’s format).

---

## Table formatting (metrics block)

### Issue

In the extract, the archived metrics table around **§3.3.2.1.6** shows a corrupted header sequence (`MetricValue` / duplicated `Metric` / `Value` lines). That may be PDF-to-text extraction noise, but **check the PDF**: the printed table should have exactly **one header row** and aligned columns.

---

## Numeric cross-checks (optional updates)

| Claim in manuscript | Check against repo | Suggestion |
|----------------------|--------------------|------------|
| TFLite model **~5.42 MB** | `assets/model/best.tflite` ≈ **5.17 MB** on disk (current tree) | Use **“≈5.2 MB”** or quote **measured byte size** for the exact build you submit. |
| **Dart 3.11.0** | `pubspec.yaml` constrains SDK **`>=3.2.0 <4.0.0`** | Prefer wording: **“Dart 3.x as required by the Flutter SDK used for the build”** and record **`flutter --version`** output in an appendix. |
| **SQLite schema version 12** | `_dbVersion = 12` in `database_service.dart` | **Consistent.** |
| **640×640** input / letterbox | `AppConstants.inputSize = 640` | **Consistent.** |
| **Severity** \(s = 1 - e^{-(b \cdot c/100)/k}\), \(k=8\) | `severity_score.dart` uses `raw = b * (c/100)`, `s = 1 - exp(-raw/k)`, default `k=8` | **Consistent** with manuscript (fix only if a typo uses `b·c` without `/100`). |

---

## Diagrams / architecture (spot-check)

**Primary reference (Jun 2026):** `docs/thesis/SYSTEM_ARCHITECTURE.md` — stack tables + Mermaid diagrams (mobile + Supabase + ML pipeline; admin excluded).

| Manuscript claim | Code | Verdict |
|------------------|------|--------|
| Point-in-polygon “geofencing” (not OS background geofences) | `GeoFenceService` | **Aligned** |
| Still-image pipeline (not continuous live stream) | `image_picker` in `permission_screens.dart` | **Aligned** |
| `CameraService` in service list | Registered in `main.dart`; **not referenced elsewhere** in `lib/` | Safe to describe as **“registered for future / auxiliary use”** or **omit** if unused, to avoid implying a second live-camera detector path. |
| `connectivity_plus` | Present in `pubspec.yaml` | **Aligned** |

---

## Abstract / keywords consistency

The **extracted** abstract uses generic **“YOLO-family”** wording, while other parts of the manuscript (and your repo docs) specify **YOLO11 (archived metrics)** vs **YOLO26n (deployed)**.  

**Fix:** Make **Abstract**, **Keywords**, and **Scope** use the **same naming** you defend in Chapter IV (e.g. explicitly **YOLO26n TFLite** deployed, **YOLO11** metrics archival).

---

## Title page (extract-only typo)

In `THESIS_V4_extracted.txt`, author names run together (`…MORGAANGELEI…`). **Verify the PDF title page**; if it is correct there, no change; if not, fix spacing in the source document.

---

## Quick checklist before defense

- [ ] Replace **30%** deployment threshold language with **20% (0.20)** unless you reverted code.  
- [ ] Fix Table **4.8** task label (**long-press** vs **edit button**).  
- [ ] Remove **Figure 4.7 placeholder** line; ensure figure exists.  
- [ ] Clean **Figure 4.6** caption redundancy.  
- [ ] Align **list of tables** numbering with body.  
- [ ] Re-scan **Table 4.1** title: it should read like **archived YOLO11** validation metrics, not YOLO26n.  
- [ ] Optionally add one line: **“Histogram bins describe deployed-model confidence; mAP in §4.1 refers to archived YOLO11 training.”**

---

*Generated from repository state at review time. Re-run file size / SDK checks if the bundled model or Flutter SDK changes.*
