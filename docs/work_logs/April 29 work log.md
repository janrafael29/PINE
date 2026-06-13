# Work log — 29 April 2026

Supplement to **`docs/RECENT_WORK_LOG.md`**. This entry captures the **Apr 29, 2026** work from the ongoing session focused on **restoring detection accuracy** and **UI/UX fixes** (dark mode + navigation guide + profile experience). Some small follow-up tweaks landed shortly after midnight (early Apr 30 local) but are included here as part of the same workflow.

**Stack reminder:** Flutter (Android). Supabase compile-time defines passed via `scripts/run_debug.ps1`. On-device detection is YOLO→TFLite shipped as `assets/model/best.tflite`.

---

## 1) Detection accuracy restoration (keep UI intact)

- **Model swap back to known-good V2**:
  - Replaced the current model with the older accurate model as **`assets/model/best.tflite`**.
- **Default detection tuning (balanced preset)**:
  - Adjusted defaults to match the older V2 “feel” (higher recall without changing UI):
    - `detectionThreshold` → **0.20**
    - `nmsThreshold` → **0.45**
  - Kept other presets available for speed/accuracy trade-offs.

---

## 2) Dataset investigation: why “~5k images” trained worse than “1.5k”

**Key conclusion:** Dataset size didn’t help because the larger export contained enough **label noise** and **duplicate/low-diversity images** to hurt generalization—especially for **tiny-object** detection.

Work completed:

- **Extracted and audited** the Roboflow-style YOLO export (train/valid/test).
- Found issues consistent with accuracy degradation:
  - **empty/unparseable labels**
  - **degenerate/out-of-range boxes**
  - **duplicate images**
  - many very small boxes (high sensitivity to label noise)
- **Cleaned the dataset** (label sanity fixes + exact-image dedup), with reports written under the project `runs/` folders used by the scripts.

---

## 3) Navigation guide (spotlight tour) fixes

### 3.1 Dark mode + white surfaces

- Updated guide screens to respect `Theme.of(context)` so dark mode applies (including the “How should we show this guide?” chooser screen).

### 3.2 Faster + smoother transitions (without lag)

- Reduced heavy animation overhead and removed expensive transitions that caused jank.
- Added a small, smooth transition between sequence parts (light fade/slide + short enter/exit).

### 3.3 Auto-advance reliability

- Implemented reliable **auto-advance per sequence part** (now **3 seconds**) and hardened it against:
  - layout/measurement timing issues
  - page transitions
  - slow devices dropping frames
- Added **Back** support while keeping auto-advance running.
- Improved spotlight measurement accuracy (re-measure after settle).
- Reduced expensive painting work in the overlay to improve performance on low-end devices.

### 3.4 Late-session stabilization & performance fixes (the “just now” changes)

- **Prevented layout re-entrancy crashes** during guide transitions/measuring by adding measurement guards and deferring state changes to safe frames.
- **Removed animated auto-scroll** while the spotlight guide is active (`ensureVisible` uses `Duration.zero`) to avoid frame floods on slower phones.
- **Optimized spotlight overlay painting**:
  - replaced expensive `Path.combine` difference operations with an **even-odd fill** hole path
  - enabled `CustomPaint` complexity hints for better raster caching (`isComplex`, `willChange`)
- **Fail-safe behavior**: if a spotlight target cannot be measured after retries, the tour **does not stall**—it continues with no hole and keeps the 3s sequence auto-advance running.

---

## 4) Dark mode coverage (camera/add-photo + disease/capture/fields flows)

- Updated screens that still hardcoded light colors to use `Theme.of(context).colorScheme` / `textTheme` so dark mode applies consistently across:
  - Add Photo / camera & gallery permission flows
  - disease info/detail screens
  - captured photo viewing
  - fields list and add/edit field flows

---

## 5) Profile page modernization + full-screen photo viewer

- Reworked profile UX to match the modern app sections:
  - removed oversized header
  - added bottom-sheet actions for avatar: **View / Camera / Gallery**
  - added full-screen photo viewer (zoom/pan)
  - ensured profile screen respects dark mode

---

## 6) Post-scan guidance (“What to do next”)

- Added a small guidance section on the results screen that provides:
  - basic containment/prevention steps when detections occur
  - rescan tips when none are detected

---

## 7) Key files touched (high signal)

- **Detection**
  - `assets/model/best.tflite`
  - `lib/core/config.dart`
  - `lib/core/constants.dart`
- **Guide**
  - `lib/widgets/spotlight_navigation_guide_overlay.dart`
  - `lib/screens/navigation_guide_preference_screen.dart`
  - `lib/screens/app_navigation_guide_screen.dart`
- **Dark mode / UI**
  - `lib/screens/permission_screens.dart`
  - `lib/screens/profile_screen.dart`
  - `lib/screens/main_dashboard_screen.dart` (fixed a layout crash encountered during guide steps)
  - `lib/screens/disease_info_screen.dart`
  - `lib/screens/disease_detail_screen.dart`
  - `lib/screens/captured_photo_detail_screen.dart`
  - `lib/screens/fields_list_screen.dart`
  - `lib/screens/field_selection_screen.dart`
  - `lib/screens/edit_field_screen.dart`
  - `lib/screens/farm_details_screen.dart`
- **Assets**
  - `lib/core/more_tab_images.dart` (improved title→asset filename matching)

---

## 8) Notes / follow-ups

- If you want the guide to never skip highlighting even on very slow devices, we can add a per-target fallback (highlight a parent container when a child key can’t be measured).
- Consider establishing a fixed “golden” evaluation set for comparing future trained models (1.5k vs cleaned ~5k) to avoid subjective regressions.

---

*End of work log — 29 April 2026.*

