# Work log — 28–29 April 2026

Supplement to **`docs/RECENT_WORK_LOG.md`**. This entry is a detailed, two-day narrative covering:

- **Restoring detection accuracy** by swapping back a known-good **V2 `best.tflite`** and tuning thresholds (UI unchanged).
- **Validating builds** (debug APK + analyzer).
- **Auditing and cleaning the “~5k” dataset export** (and explaining why it trained worse than the smaller set).
- **UX fixes**: faster navigation guide animation, dark mode coverage, image resolution, profile photo viewer/actions, and “what to do next” guidance after scanning.

**Stack reminder:** Flutter (Android). Supabase compile-time defines (`SUPABASE_URL`, `SUPABASE_ANON_KEY`) are passed via scripts (`scripts/run_debug.ps1`, `scripts/build_release_auto_version.ps1`). On-device detection is YOLO→TFLite shipped as `assets/model/best.tflite`.

> **Note on dates:** A portion of the UI work landed shortly after midnight (early 30 Apr local), but it is included here as part of the same “two-day” work session window.

---

## Handoff for another agent (high-signal)

| Area | What to know |
|------|--------------|
| **Detection regression root cause** | The app accuracy drop was primarily **model + threshold**. Restoring the older V2 `best.tflite` (and making the default threshold slightly more sensitive) yielded a large field accuracy improvement without changing UI flows. |
| **Bundled model** | Current bundled model is at **`D:\old_PINE\assets\model\best.tflite`** (size **5,424,062 bytes**, timestamp **4/28/2026 9:24 PM**). |
| **Balanced preset tuning** | Default `AppConfig.balanced()` was tuned to **`detectionThreshold=0.20`**, **`nmsThreshold=0.45`** (slightly more sensitive than V2’s old `0.30`, but still fast; accuracy preset remains available). |
| **Dataset cleanliness matters** | The “5k” export contains **duplicates**, **empty/unparseable labels**, and **tiny-object boxes** where label noise is very costly. A smaller but cleaner dataset can outperform a larger, noisier one. |
| **Disease images** | Asset resolver previously required **exact filename == exact card title**. It now tries normalized variants (case/underscores/dashes/punctuation), so images display even if filenames don’t perfectly match titles. |
| **Profile photo UX** | Tapping avatar now opens a bottom sheet with **View / Camera / Gallery**. Viewer is full-screen and zoomable. Profile screen no longer hardcodes light theme colors. |
| **Post-scan guidance** | Results screen now includes a “What to do next” card with basic prevention/containment steps when detections occur (and a rescan checklist when none do). |

---

## 1) Restore detection accuracy (model + thresholds; UI kept intact)

### 1.1 Confirmed older “accurate” model source

User identified the older accurate app version as **PINE V2** and pointed to the model file:

- **Source model:** `D:\PINE V2\PINE\assets\model\best.tflite`
- **Observed metadata:** size **5,424,062 bytes**, modified **4/28/2026 9:24 PM**

### 1.2 Copied model into the current app project

Copied the V2 model into the current working repo:

- **Destination:** `D:\old_PINE\assets\model\best.tflite`
- Verified destination size and timestamp match the source.

This ensured the app ships the expected model (since the code already references `assets/model/best.tflite`).

### 1.3 Tuned default thresholds (balanced preset)

The codebase already had an “accuracy” preset (tiling + TTA) and a “balanced” preset used by default. To match the user’s request (“slightly more sensitive than V2, still fast”), we tuned defaults:

- **File:** `lib/core/config.dart`
  - `AppConfig.balanced()`:
    - `detectionThreshold`: **0.26 → 0.20**
    - `nmsThreshold`: **0.42 → 0.45**
  - `accuracy()` and `lowEnd()` were left unchanged.

And we aligned the documentation constants:

- **File:** `lib/core/constants.dart`
  - `detectionThreshold`: **0.14 → 0.20**
  - `nmsThreshold`: **0.48 → 0.45**
  - Updated surrounding doc text to reflect the new defaults.

### 1.4 Build + smoke verification

We validated the project still builds cleanly:

- Ran `flutter pub get` (to ensure `.dart_tool/package_config.json` exists for Gradle).
- Built: `flutter build apk --debug`
  - Output: `build/app/outputs/flutter-apk/app-debug.apk`
- Ran `flutter analyze` after UI changes later in the session:
  - End state: **No issues found**

### 1.5 Outcome observed in field testing

User reported the restored model + tuned defaults produced **~80% perceived accuracy improvement** vs the prior state, with no UI redesign and minimal behavioral changes.

---

## 2) Why the “5k dataset” trained worse than the 1.5k dataset

### 2.1 Identified the real dataset artifact

The “5k dataset” was provided as a Roboflow-style export zip:

- **Zip:** `D:\PINE\mealybug.v7-7th-yolo-26.yolo26.zip` (~204 MB)
- Layout inside zip: `data.yaml`, `train/`, `valid/`, `test/`

We counted image/label pairs in the zip:

- Train: **3,232 images** + **3,232 labels**
- Valid: **923 images** + **923 labels**
- Test: **462 images** + **462 labels**
- Total images across splits: **4,617** (often described as “~5k”)

### 2.2 Extracted + audited dataset (analysis run)

The dataset was extracted into `datasets/` and audited via `scripts/audit_yolo_dataset.py`.
Key findings (pre-cleaning, after correct `data.yaml` normalization):

- **Empty/unparseable labels exist** (train).
- **Some degenerate boxes** (zero/negative width or height) exist.
- **Extremely small median object area** (`w*h` ≈ ~0.0013–0.0015) → tiny objects.
- **Very large box-count images** (up to >100) → increases labeling inconsistency risk.

### 2.3 Duplicate content present

A fast duplicate estimate (hash-based) suggested non-trivial duplication (exact/near-exact) in the training split; duplicates reduce effective diversity and can worsen generalization.

### 2.4 Conclusion: “More images” did not equal “better data”

For tiny-object detection, extra images help only if they:

- add **diversity** (new scenes/lighting/distances/backgrounds),
- maintain **label quality**, and
- avoid **excessive duplicates** and overly destructive augmentations.

In the 4.6k export, label noise and duplicates were high-impact enough that the model trained on it could underperform a smaller, cleaner 1.5k dataset.

---

## 3) Cleaned the dataset (applied to `D:\PINE`, then also mirrored for analysis in `D:\old_PINE`)

> The user later requested that the “real” dataset work be applied to **`D:\PINE`** (not just `D:\old_PINE`). Both were used at different points during the session; the final “authoritative” cleanup is in `D:\PINE`.

### 3.1 Extraction (with safety backup)

In `D:\PINE`, we extracted the zip into `D:\PINE\datasets\` and backed up the existing dataset:

- Backup created: `D:\PINE\datasets.bak.1777387687`
- `data.yaml` paths normalized to be relative to `datasets/` (train/images, valid/images, test/images).

### 3.2 Label cleanup (Option A)

Ran the project’s label geometry cleaner:

- **Script:** `scripts/scan_fix_yolo_labels_option_a.py --apply`
- Result: **107 label files modified** (train 85, val 14, test 8)
- Backups/logs written under:
  - `D:\PINE\runs\label_clean\20260428_144827\backups`
  - `D:\PINE\runs\label_clean\20260428_144827\actions.jsonl`
  - `D:\PINE\runs\label_clean\20260428_144827\summary.json`

This step removes:

- invalid/out-of-range/degenerate boxes,
- “cluster parent” boxes (large parent bounding many children),
- duplicate/stacked boxes under configured IoU/area rules.

### 3.3 Image de-duplication (content-hash)

To remove identical images (and their paired label files), we introduced a small utility script and ran it:

- **New script:** `scripts/dedup_dataset_images.py`
- **Report output:** `D:\PINE\runs\dataset_dedup\20260428_145329\dedup_report.json`
- Removals (exact hash duplicates):
  - train removed **111**
  - valid removed **9**
  - test removed **2**

### 3.4 Resulting split sizes (post-cleaning)

After cleanup, dataset counts in `D:\PINE\datasets\` were:

- train: **3121 images** / **3121 labels**
- valid: **914 images** / **914 labels**
- test: **460 images** / **460 labels**

Additionally, we measured that some empty labels still remain in train (these are “negative” samples; whether that’s desirable depends on training intent).

### 3.5 Important: user requested `D:\old_PINE` remain unchanged

Late in the session, the user requested the `D:\old_PINE` folder be kept safe and unchanged going forward. After that point, changes were focused on `D:\PINE` where requested.

---

## 4) UX / UI fixes (guide, dark mode, images, profile, post-scan guidance)

### 4.1 Navigation guide animation “laggy” → sped up

Files:

- `lib/widgets/spotlight_navigation_guide_overlay.dart`

Changes:

- Reduced the enter animation duration and exit durations.
- Reduced scroll-into-view animation duration.
- Reduced card movement and content switch durations.
- Reduced silent auto-advance delay (so the tour doesn’t feel slow).

Net effect: the overlay guide should feel snappier and less “laggy.”

### 4.2 Dark mode didn’t affect the “Add Photo / Camera / Gallery” picker

File:

- `lib/screens/permission_screens.dart`

Changes:

- Replaced hardcoded light backgrounds (`AppTheme.backgroundLight`, `AppTheme.surfaceWhite`, `AppTheme.textDark`) for the “Add Photo” card with `Theme.of(context).colorScheme` and `textTheme` so it follows dark mode.
- Updated the GPS prompt `AlertDialog` background to use the theme surface.

### 4.3 Disease images not visible (e.g., Heart Rot placeholder icon)

Root cause:

- `moreTabImageForTitle()` originally required exact title match → `assets/placeholder_pics/<title>.<ext>`
  - Example: title “Heart Rot” required a file named exactly `assets/placeholder_pics/Heart Rot.png`

Fix:

- `lib/core/more_tab_images.dart` now generates candidate stems:
  - original title
  - spaces replaced by `_` or `-`
  - lowercase normalized title
  - punctuation removed
  - collapsed whitespace

Net effect: images show even if filenames don’t exactly match title casing/spaces.

### 4.4 Profile picture: full view + action button + dark mode

File:

- `lib/screens/profile_screen.dart`

Changes:

- Tapping the avatar now opens a bottom sheet with:
  - **View photo**
  - **Take photo (camera)**
  - **Choose from gallery**
- “View photo” opens a full-screen `InteractiveViewer` (zoom/pan).
- Replaced hardcoded light colors with theme-based colors so dark mode applies.

### 4.5 After scanning: basic prevention / next steps guidance

File:

- `lib/screens/permission_screens.dart` (inside `PhotoResultScreen`)

Change:

- Added a “What to do next” card with:
  - **If detections exist**: isolate/remove heavily infested material, control ants, soap/neem guidance, hygiene.
  - **If none detected**: re-scan tips (lighting, framing, sensitivity slider, accuracy mode).

---

## 5) Files changed (high signal)

### `D:\old_PINE` (app)

- `assets/model/best.tflite` (model restored from V2)
- `lib/core/config.dart` (balanced preset thresholds)
- `lib/core/constants.dart` (documented defaults aligned)
- `lib/widgets/spotlight_navigation_guide_overlay.dart` (faster guide animations)
- `lib/screens/permission_screens.dart` (dark mode for Add Photo + GPS dialog; “What to do next” card)
- `lib/core/more_tab_images.dart` (normalized filename matching for disease images)
- `lib/screens/profile_screen.dart` (viewer + camera/gallery picker + theme fixes)

### `D:\PINE` (dataset + tooling)

- Extracted `datasets/` from `mealybug.v7-7th-yolo-26.yolo26.zip` (with backup)
- `runs/label_clean/...` (label fix logs + backups)
- `runs/dataset_dedup/...` (dedup reports)
- Added `scripts/dedup_dataset_images.py` (dedup helper)

---

## 6) Follow-ups (optional but recommended)

- **Decide how to handle empty label files** in train (keep as “negative samples” vs quarantine/remove) and document the choice.
- **Retrain a new model** on the cleaned dataset in `D:\PINE\datasets\` and compare against the “known good” 1.5k model using a fixed “golden” test set.
- If you want dark mode to affect the **live camera preview UI** (not just Add Photo), we should review the camera widgets/services (`lib/services/camera_service.dart`, related screens) for any remaining hardcoded light colors.

---

*End of work log — 28–29 April 2026.*

