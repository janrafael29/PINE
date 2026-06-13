# Work log — 28 April 2026

Supplement to **`docs/RECENT_WORK_LOG.md`**. Summarizes work focused on **documentation alignment**, **syncing docs into `D:\old_PINE`**, and a small **Dart lint cleanup**.

**Stack reminder:** **PINYA-PIC** (Flutter Android) with **Supabase** compile-time defines (**`SUPABASE_URL`**, **`SUPABASE_ANON_KEY`**, preferably via **`--dart-define-from-file`** on Windows; see **`RUN.md`**). On-device detection uses **Ultralytics YOLO26 → TFLite** (shipping guidance now emphasizes **float32-input TFLite** for device compatibility when float16-input kernels fail).

---

## 1. Documentation updates (repo-wide)

Updated Markdown docs in `D:\PINE` to reflect current reality and avoid stale instructions:

- **TFLite shipping guidance**
  - Updated several docs to recommend **shipping `best_float32.tflite`** when devices fail to initialize float16-input models (common error signature: `CONV_2D failed to prepare`).
  - Kept **float16** references only where they are explicitly historical/diagnostic.
- **Supabase preflight behavior**
  - Clarified that the optional REST probe (`GET /rest/v1/`) is **opt-in** via `run_debug.ps1` switches and can false-fail depending on key/header mode and project settings.
- **Results UX notes**
  - Ensured work logs reflect the **top-5 detections default**, **expand/collapse** list UX, and **live sensitivity slider** behavior.
- **Branding / launcher icons**
  - Updated branding notes to point adaptive icon foreground to **`assets/placeholder_pics/logo_foreground_fit.png`** (transparent + padded) to avoid Android adaptive icon cropping.

Files updated (high signal):

- `RUN.md`
- `ALL_DOCS.md`
- `docs/RECENT_WORK_LOG.md`
- `docs/work_logs/April 26 work log.md`
- `docs/work_logs/April 11 work log.md`
- `docs/work_logs/April 12-13 work log.md`
- `docs/work_logs/april 14-20 2026 work log.md`

---

## 2. Sync updated `.md` files into `D:\old_PINE`

Goal: keep `D:\old_PINE`’s documentation aligned without changing training/runtime code.

- Copied `*.md` files from `D:\PINE` → `D:\old_PINE` **recursively**, overwriting matching paths.
- Excluded generated/large directories (`.git`, `.dart_tool`, `build`, `.venv`, `runs`, etc.).
- **Note:** this approach **overwrites** matching `.md` files, but does **not delete** `.md` files that exist only in `D:\old_PINE` (no mirroring/purge flags used).

This operation does **not** interrupt ongoing training (it only touches markdown files; it does not stop Python processes).

---

## 3. Minor Dart cleanup (lint)

- `lib/screens/disease_by_category_screen.dart`: removed redundant `const` keywords (`unnecessary_const`) in the `fruit()` category’s `diseases:` list; verified no remaining lint warnings for that file.

---

## 4. Commands / snippets used

Copy markdown from `PINE` to `old_PINE` (recursive, overwrite, exclude generated folders):

```powershell
robocopy D:\PINE D:\old_PINE *.md /S /XO /R:1 /W:1 /XD .git .dart_tool build .venv runs node_modules android\.gradle ios\.symlinks
```

---

*End of work log — April 28, 2026.*

