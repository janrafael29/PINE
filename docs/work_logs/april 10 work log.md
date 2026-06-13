# Work log — 10 April 2026

Single-day supplement to **`docs/RECENT_WORK_LOG.md`**. That file’s **Part I** is dated **30 March → 9 April 2026**; this entry records work **on or after 10 April 2026**.

**Git baseline:** At the start of this period, **`main`** pointed to **`1523435`** (**2026-04-09**, “feat: app updates, docs, training scripts, and model refresh”). The items below were captured from the **working tree** (modified and new files) as the factual record for **10 April 2026**; reconcile dates with **`git log`** / **`git diff`** after you commit.

**Stack reminder:** **Supabase** with **`SUPABASE_URL`** / **`SUPABASE_ANON_KEY`** at compile time. Display name **PINYA-PIC**. On-device model path: **YOLO → TFLite**; **current** Ultralytics default for training: **YOLO26n** (`retrain_yolo.py`).

---

## Handoff for another agent (paper / manuscript)

**What changed vs Part I Handoff (inference table):** **`AppConstants.detectionThreshold`** and **`AppConstants.nmsThreshold`** were retuned (see §2). **Sliding-window (tiled) inference** was added (§1). As of **Apr 2026** doc refresh, **`lib/core/constants.dart`** uses **`detectionThreshold = 0.14`**, **`nmsThreshold = 0.48`** — cite that file for Methods, not older markdown tables.

**New UX (non-core to detection science):** Post-login **app navigation guide** with **SharedPreferences** persistence and Settings replay (§4).

**Training script:** Optional Ultralytics kwargs exposed on the CLI for larger or noisier datasets (§5).

---

## 1. Sliding-window (tiled) inference

**Goal:** When the full frame is letterboxed to the model input, distant mealybugs occupy few tensor pixels. **Cropping the oriented image into overlapping tiles** (in **original pixel space**) restores apparent object size; each crop is letterboxed to **`inputSize`** and run through the same YOLO head, then boxes are **translated back** to full-image coordinates.

**New module:** **`lib/utils/tiled_inference.dart`**

| Symbol | Role |
|--------|------|
| **`ImageTileSpec`** | Rectangle **`x, y, width, height`** in source pixels. |
| **`planImageTiles(...)`** | Grid with **`tileSide`**, **`overlapFraction`**, **`maxTiles`**. Computes stride from overlap; if tile count exceeds **`maxTiles`**, **widens stride** iteratively (cap on runaway growth). **`tileSide`** clamped **64…4096**. |
| **`nmsMergedDetections(...)`** | Greedy **IoU NMS** on **`Detection`** list in **one coordinate system** (full image), sorted by confidence. |

**Integration:** **`lib/services/inference_service.dart`**

- Gate: **`tiledInferenceEnabled`** and shorter side **`≥ tiledInferenceMinShortSide`** after **`bakeOrientation`**.
- Per tile: **`img.copyCrop`** → **`ImagePreprocessor.preprocessFromImage`** → **`_InterpreterSession.forward`** with **`maxDetectionsPerTile`**.
- Offset: **`d.copyWith(left: d.left + spec.x, top: d.top + spec.y)`**.
- Merge: **`nmsMergedDetections(merged, nmsThreshold, maxDetections)`**, then threshold filter.
- **Diagnostics:** **`AppLogger.debug`** lines for tile count, image size, timing, raw box totals; first tile can log **input tensor stats**.

**Config surface:** **`lib/core/config.dart`** — **`AppConfig`** gains tiled fields with defaults from **`AppConstants`**; **`AppConfig.lowEnd()`** sets **`tiledInferenceEnabled: false`**, lower **`maxTilesPerImage`** / **`maxDetectionsPerTile`**.

**Constants (see §2):** Tiling knobs live on **`AppConstants`** in **`lib/core/constants.dart`**.

---

## 2. `AppConstants` and inference policy (retune + tiling)

**File:** **`lib/core/constants.dart`**

| Constant | Prior doc in `RECENT_WORK_LOG` (older) | Value in this work log (10 Apr tree) | **Current repo** (Apr 25 2026 doc sync) |
|----------|------------------------------------------|--------------------------------------|----------------------------------------|
| **`detectionThreshold`** | **0.30** | **0.22** | **0.14** — cite **`lib/core/constants.dart`** |
| **`nmsThreshold`** | **0.45** | **0.55** | **0.48** — cite **`lib/core/constants.dart`** |
| **`confidenceTemperature`** | **1.0** | **1.0** | Unchanged; calibration still a future option. |
| **`maxDetections`** | **50** | **50** | Unchanged. |
| **`tiledInferenceEnabled`** | — | **`true`** | Feature flag. |
| **`tiledInferenceMinShortSide`** | — | **640** | Min shorter side (px) of decoded image to enable tiling. |
| **`tileNativeSide`** | — | **480** | Crop square side in **source** pixels before letterbox. |
| **`tileOverlapFraction`** | — | **0.22** | Overlap between adjacent tiles. |
| **`maxTilesPerImage`** | — | **40** | Latency / RAM cap. |
| **`maxDetectionsPerTile`** | — | **48** | Per-tile cap before global merge. |

**Paper / reproducibility:** Any manuscript table of thresholds must match **shipped** `constants.dart` at release tag, not an older log section.

---

## 3. Isolate-based inference (UI thread safety)

**File:** **`lib/services/inference_service.dart`**

- **`InferenceService.runInference`** builds **`_InferenceParams`** (including tiling fields) and returns **`Isolate.run(() => _runInferenceIsolate(params))`** so **tiled multi-forward** work does not block the UI (reduces **ANR** risk on mid-range devices).
- **`_InterpreterSession`** holds one **`Interpreter`**, input/output tensors, **`Float32List`** output buffer, and inferred **`numClasses` / `hasObjectness`** — reused across tiles in a single isolate run, then **`interpreter.close()`** in **`finally`**.

---

## 4. Post-login app navigation guide

**Motivation:** Onboard users to **Home**, **bottom nav**, **center scan**, **Diagnose / My Fields** without blocking core auth.

**Persistence:** **`lib/core/navigation_guide_prefs.dart`** (**`shared_preferences`**)

| Key / API | Behavior |
|-----------|----------|
| **`shouldShowNavigationGuide()`** | **`true`** if “show each session” **or** user has not finished the guided flow. |
| **`setNavigationGuidePreference({required bool showEachSession})`** | Mark finished + store repeat preference (last page of tour). |
| **`getNavigationGuideShowEachSession()`** / **`setNavigationGuideShowEachSession(bool)`** | Read/update repeat-on-open; used from Settings without re-running the tour. |

**UI:** **`lib/screens/app_navigation_guide_screen.dart`** — **`PageView`** slides (dashboard, bottom nav, scan, diagnose/fields) + final page: **one-time vs every session** (when **`showPreferenceChooser`** is **`true`**). **“Skip to choice”** in app bar when chooser shown. **`AppTheme.primaryGreen`** app bar.

**Presentation host:** **`lib/widgets/navigation_guide_host.dart`** — **`NavigationGuideHost`** wraps child; after first frame, **500 ms** delay, then **`rootNavigator`** **`fullscreenDialog`** route to **`AppNavigationGuideScreen`** if prefs say so.

**Wire-in:** **`lib/screens/intro_flow_screen.dart`** — For signed-in users, **`UnlockGate`** → **`NavigationGuideHost`** → **`MainDashboardScreen`**. **`ValueKey<String>(userId)`** on host so **switching accounts** resets presentation eligibility per user session key.

**Settings:** **`lib/screens/settings_screen.dart`** — Loads **`getNavigationGuideShowEachSession`** for a **Switch** (“Show app guide when opening”); **`ListTile`** opens **`AppNavigationGuideScreen(showPreferenceChooser: false)`** for replay (“View app navigation guide”).

---

## 5. Registration, login routing, and email confirmation

**`LoginRouteArgs`** (**`lib/screens/login_screen.dart`**): optional **`email`** passed via **`Navigator.pushNamed(..., arguments:)`**.

**`lib/main.dart`** **`/login` route:** If **`arguments`** is **`LoginRouteArgs`**, builds **`LoginScreen(prefillEmail: args.email)`**.

**`lib/screens/login_screen.dart`:** Controllers created in **`initState`** from **`prefillEmail`**.

**`lib/screens/register_screen.dart`:**

- **`signUp`** returns **`AuthResponse`**; inspect **`response.session`**.
- If **`session == null`** (typical when **email confirmation** is enabled in Supabase): snackbar **“Check your email…”**, then **`pushReplacementNamed('/login', arguments: LoginRouteArgs(email: …))`**.
- If session exists: existing **profile upsert** / **device unlock** flow, then **`pushNamedAndRemoveUntil('/', … false)`** instead of always sending the user back to login with a generic snackbar.

---

## 6. `retrain_yolo.py` — dataset note + optional train kwargs

**Docstring block:** Explains why a **larger** dataset can **underperform** a smaller one (noisy boxes, duplicates, scene imbalance, background dominance) and points to **data fixes first**, then optional **`--cos-lr`**, **`--multi-scale`**, **`--copy-paste`**, **`--label-smoothing`**, **`--freeze`** when fine-tuning from a strong **`best.pt`**.

**`retrain_model(...)`** new parameters (all optional except defaults):

| Parameter | CLI | Effect |
|-----------|-----|--------|
| **`patience`** | **`--patience N`** | Overrides default **15** early-stop patience. |
| **`cos_lr`** | **`--cos-lr`** | Sets **`cos_lr=True`** in **`model.train`**. |
| **`multi_scale`** | **`--multi-scale`** | Sets **`multi_scale=True`**. |
| **`copy_paste`** | **`--copy-paste P`** | **`copy_paste`** float **0…1**. |
| **`label_smoothing`** | **`--label-smoothing X`** | Passed through if set. |
| **`freeze`** | **`--freeze N`** | Freeze first **N** layers when fine-tuning. |

**Logging:** Prints a single line of enabled extras (**`🎯 Extra train args: …`**) before **`model.train`**.

---

## 7. Versioning

**`pubspec.yaml`:** Bumped from **`5.0.0+16`** to **`5.1.0+2018`** in the working tree (minor feature train + large **build** jump — confirm **`+build`** / Play **versionCode** policy before store upload).

---

## 8. Key paths — 10 April 2026

| Area | Paths |
|------|--------|
| Tiling + merge NMS | `lib/utils/tiled_inference.dart` |
| Inference isolate + session | `lib/services/inference_service.dart` |
| Constants + config | `lib/core/constants.dart`, `lib/core/config.dart` |
| Nav guide | `lib/core/navigation_guide_prefs.dart`, `lib/widgets/navigation_guide_host.dart`, `lib/screens/app_navigation_guide_screen.dart`, `lib/screens/settings_screen.dart`, `lib/screens/intro_flow_screen.dart` |
| Auth | `lib/screens/login_screen.dart`, `lib/screens/register_screen.dart`, `lib/main.dart` |
| Training CLI | `scripts/retrain_yolo.py` |

---

## 9. Command cheat sheet (verification)

After committing, re-run quality gates (figures below are **not** re-executed for this markdown file):

```powershell
Set-Location D:\PINE
flutter pub get
flutter analyze
flutter test
```

**Training examples (new flags):**

```powershell
D:\PINE\.venv\Scripts\python.exe D:\PINE\scripts\retrain_yolo.py --epochs 50 --no-export --patience 30 --cos-lr --multi-scale
D:\PINE\.venv\Scripts\python.exe D:\PINE\scripts\retrain_yolo.py --epochs 50 --no-export --freeze 10 --copy-paste 0.2
```

---

## 10. Limitations and follow-ups

- **Tiled inference:** More interpreter forwards per photo → **higher latency** and **battery** use; **`maxTilesPerImage`** and **`tileNativeSide`** trade recall vs cost. **No automated benchmark** is recorded here; log timings from **`AppLogger`** on target devices if the paper needs numbers.
- **Global NMS after merge:** Uses the same **`nmsThreshold`** as single-pass NMS; if you need **different** IoU for “merge across tiles” vs “per tile,” that would require a separate constant (not implemented in this tree).
- **Uncommitted state:** Until changes are committed, **`git blame`** and CI history will not show **10 April** as a single revision; merge this file’s §8 paths with **`git diff 1523435`** for an exact patch list.

---

*This file was authored to mirror the depth and reference style of **`docs/RECENT_WORK_LOG.md`** (tables, file paths, CLI, handoff). Update **`RECENT_WORK_LOG.md` Part I date range** if you fold 10 Apr work into the single-file changelog.*
