# Work log — 30 April 2026

Supplement to **`docs/RECENT_WORK_LOG.md`**. This entry captures the **Apr 30, 2026** work focused on **map fixes (terrain + styles + zoom)**, **permission/log spam hardening**, **performance smoothing**, **Android release shrinking**, and **repo cleanup**.

**Stack reminder:** Flutter (Android) with **Supabase** compile-time defines (**`SUPABASE_URL`**, **`SUPABASE_ANON_KEY`**; Windows scripts: `scripts/run_debug.ps1`, `scripts/build_release_auto_version.ps1`). On-device detection is YOLO→TFLite shipped as `assets/model/best.tflite`.

Environment notes:
- Flutter: **3.41.2** (stable)
- Dart: **3.11.0** (stable)
- pubspec: **`version: 11.0.0+2029`**

---

## 1) Maps: terrain loading, style cleanup, and better zoom

### 1.1 Terrain tiles now load (no more “Map data not yet available” at normal zoom)

- Root cause: the previous “terrain” source (`World_Physical_Map`) only serves tiles up to ~z8, so at app zooms (z11–18) the provider shows blank placeholders.
- Fix: updated `MapTiles.esriTerrain` to **Esri World Topo**:
  - `https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}`
  - Added native zoom caps:
    - `maxNativeZoomTerrain = 19`
    - `maxNativeZoomOpenStreetMap = 19`

Files:
- `lib/core/map_tiles.dart`
- `lib/screens/location_picker_screen.dart`
- `lib/screens/land_map_screen.dart`

### 1.2 Removed “Dark” map option

- Removed `_MapStyle.dark` and its menu entry in the location picker.
- Removed the `cartodb-basemaps` URL branch (no longer used).

File:
- `lib/screens/location_picker_screen.dart`

### 1.3 Higher zoom support (camera zoom vs native tiles)

- Confirmed camera zoom can go higher than native tiles without disappearing by keeping:
  - `MapTiles.maxZoomSatellite = 21` (camera limit)
  - `MapTiles.maxNativeZoomSatellite = 19` (tile-native limit)

Files:
- `lib/core/map_tiles.dart`
- `lib/screens/location_picker_screen.dart`
- `lib/screens/land_map_screen.dart`

---

## 2) Location permission: stop log spam + improve UX when denied

Problem seen in logs: repeated
`[PINE] ERROR: Location error - User denied permissions to access the device's location.`

Fixes applied in `LocationPickerScreen`:
- Added state guards:
  - `_gpsFetchInFlight` prevents overlapping GPS calls.
  - `_locationDeniedNoticeShown` shows **one** notice per screen visit (prevents repeated SnackBars + logs).
- Permission flow:
  - Checks `Geolocator.checkPermission()` before GPS.
  - If denied/forever-denied, **stops auto retry**, logs a single warning, and shows one SnackBar.
  - “My Location” button resets the notice flag so the user can retry.
- Added `AppLogger.warn(...)` (new log level) for non-fatal warnings.

Files:
- `lib/screens/location_picker_screen.dart`
- `lib/core/app_logger.dart`
- (permission helper used) `lib/services/geo_service.dart`

---

## 3) UI fix: Field Detail stats overflow

Issue: the stats card (“Images Taken”, “Last Updated”) could overflow horizontally on small screens.

Fix:
- Wrapped stats in `Expanded`, added spacing, and ellipsized long values/labels.

File:
- `lib/screens/field_detail_screen.dart`

---

## 4) Performance work (smoothness / jank reduction)

### 4.1 Maps: reduce heavy recompute and expensive marker effects

- **Memoized heatmap polygons** so grid aggregation doesn’t rerun on every rebuild/pan:
  - Cached signature + cached polygon list (`_cachedGridSig`, `_cachedGridPolys`).
- **Marker pulse auto-disable** when there are many markers:
  - `pulse: pts.length <= 25`
- Added `RepaintBoundary` around map widgets to isolate expensive paints.

Files:
- `lib/screens/detections_map_screen.dart`
- `lib/screens/land_map_screen.dart`

### 4.2 Glow markers: replace BoxShadow glows with a cheaper painter

- Replaced stacked `boxShadow` glow layers with a `CustomPainter` using `RadialGradient`.
- Keeps the same “severity glow” visual intent but reduces raster/GPU pressure.

File:
- `lib/widgets/severity_glow_marker.dart`

### 4.3 Captured photo detail: calm the embedded mini-map + avoid repeated image header decode

- Mini-map:
  - Added `RepaintBoundary`.
  - Disabled gestures (`InteractiveFlag.none`).
  - Disabled marker pulse (`pulse: false`).
- Saved detection overlay:
  - `_SavedDetectionOverlayImage` converted to a `StatefulWidget`.
  - Image dimension decode now happens once (in `initState`) instead of inside `build()`.
  - Added `cacheWidth` for `Image.memory` decode sizing.

File:
- `lib/screens/captured_photo_detail_screen.dart`

### 4.4 Thumbnails: cache local file futures + decode at display size

- Added an in-memory future cache keyed by local path so scrolling lists don’t re-hit disk.
- Added `cacheWidth` based on actual rendered size + device pixel ratio.
- Call sites pass the expected logical width for better decode sizing.

Files:
- `lib/widgets/capture_thumbnail.dart`
- `lib/screens/main_dashboard_screen.dart`
- `lib/screens/captured_photos_screen.dart`

### 4.5 Guide overlay: reduce background churn and paint cost

- Replaced the old “tick every 120ms” scheduling approach with a **single-shot timer** to the exact due time.
- Added lifecycle handling:
  - pauses countdown/timer when the app is paused and resumes by extending `_autoAdvanceDue`.
- Skipped redundant refined `setState` updates when holes don’t change.
- Added `RepaintBoundary` around the overlay and card.

File:
- `lib/widgets/spotlight_navigation_guide_overlay.dart`

### 4.6 Misc: throttling and rebuild reductions

- Inference progress UI ticker now updates at **120ms** (was 40ms).
- Results screen (`PhotoResultScreen`) precomputes sorted detections + summary values once (instead of sorting/reducing every build).
- Line chart painter wrapped in `RepaintBoundary`.

Files:
- `lib/widgets/inference_progress_dialog.dart`
- `lib/screens/permission_screens.dart`
- `lib/screens/main_dashboard_screen.dart`

---

## 5) Android release: shrinking/minification + symbol outputs

### 5.1 Enable R8 minify + resource shrinking

- `android/app/build.gradle.kts` (release build type):
  - `isMinifyEnabled = true`
  - `isShrinkResources = true`
  - Keeps existing ProGuard configuration.

File:
- `android/app/build.gradle.kts`

### 5.2 Release build script improvements (obfuscation + split debug info)

- `scripts/build_release_auto_version.ps1` now adds:
  - `--split-debug-info=build\\app\\symbols`
  - `--obfuscate`

File:
- `scripts/build_release_auto_version.ps1`

### 5.3 Verified release build

Release APK built successfully (R8 outputs present):
- `build\\app\\outputs\\flutter-apk\\app-release.apk` → **88.7 MB**
- `build\\app\\outputs\\mapping\\release\\mapping.txt` → **14.9 MB**
- `build\\app\\outputs\\native-debug-symbols\\release\\native-debug-symbols.zip` → **17.8 MB**

For comparison:
- `build\\app\\outputs\\flutter-apk\\app-debug.apk` → **115.6 MB**

---

## 6) Repo cleanup (safe deletions + guardrails)

### 6.1 Deleted/cleaned generated artifacts (then regenerated as needed)

- Removed and re-generated as needed:
  - `build/`
  - `android/app/build/`
  - `.dart_tool/` (recreated via `flutter pub get`)

Note: After the release build, these exist again (expected):
- `build/` ≈ **1.97 GB**
- `android/app/build/` ≈ **458.1 MB**
- `.dart_tool/` ≈ **191.4 MB**

### 6.2 `.gitignore` improvements

Added/verified ignores for:
- `/flutter_*.log`
- `/logs/`
- `/android/hs_err_pid*.log`
- `/android/.gradle/kotlin/errors/`

File:
- `.gitignore`

### 6.3 Asset cleanup (kept runtime-critical assets)

Kept:
- `assets/model/best.tflite` (~**5.17 MB**)
- `assets/placeholder_pics/*` (~**2.85 MB**) including `logo.png` and `logo_foreground_fit.png`

Removed:
- Unused placeholder images + directory README.
- Unbundled/unreferenced files:
  - `assets/labels/labels.txt`
  - `assets/branding/README.txt`
  - `assets/placeholder_pics/logo_foreground_padded.png`

### 6.4 Script cleanup

Removed ML/training-only scripts not needed for app runtime; kept only dev workflow scripts:
- Remaining `scripts/` size: ~**31.1 KB**
- Remaining files:
  - `build_release_auto_version.ps1`
  - `bump_pubspec_version.ps1`
  - `make_agent_bundle.ps1`
  - `run_debug.ps1`, `run_debug.cmd`
  - `run_emulator_verbose.ps1`
  - `scrcpy_phone.ps1`
  - `view_phone.ps1`, `view_phone.cmd`

---

## 7) Verification summary

- Analyzer:
  - `dart analyze lib` → **No issues found**
- Release build:
  - `flutter build apk --release` → produced `app-release.apk` successfully

---

## 8) Password reset (forgot password) + deep link flow + UX polish

### 8.1 Mobile deep link redirect for Supabase recovery

- App now requests password recovery emails to redirect to the app via:
  - `redirectTo: 'pine://reset-password'`
- App handles the recovery link by:
  - Parsing incoming `pine://reset-password` URIs
  - Calling `supabase.auth.getSessionFromUrl(uri)`
  - Navigating to the in-app “Create new password” screen

Files:
- `lib/screens/forgot_password_screen.dart`
- `lib/main.dart`
- `android/app/src/main/AndroidManifest.xml`
- `pubspec.yaml` (added `app_links`)
- `lib/screens/reset_password_screen.dart` (new screen)

### 8.2 Forgot password: clearer confirmation message

- Updated the post-send message to:
  - Mention checking **Inbox + Spam/Junk**
  - Mention the expected sender: **Pinya-Pic / `p1ny4p1c@gmail.com`**
- SnackBar kept short for readability and set to a longer on-screen duration.

File:
- `lib/screens/forgot_password_screen.dart`

### 8.3 Create new password screen: fixed “bottom overflowed” on small screens/keyboard

- Converted layout to be keyboard-safe and scrollable (`SingleChildScrollView` + viewInsets padding).

File:
- `lib/screens/reset_password_screen.dart`

---

## 9) UI polish: animated welcome gradient + feedback page tweaks + tile overflow fix

### 9.1 Welcome screen: subtle moving gradient background

- Implemented a slow, smooth animated gradient by shifting gradient alignment over time.

File:
- `lib/screens/welcome_screen.dart`

### 9.2 Feedback screen: white text + updated email

- Set the feedback cards to use **white** (and `white70`) text for better contrast.
- Updated “Send via Email” display and `mailto:` target to:
  - `p1ny4p1c@gmail.com`

File:
- `lib/screens/feedback_screen.dart`

### 9.3 More tiles: fixed title overflow on long labels

- Prevented bottom overflow in the “More” horizontal tiles by tightening the title layout:
  - limited to 2 lines with ellipsis
  - made the text region flexible within the fixed-height tile

File:
- `lib/screens/main_dashboard_screen.dart`

---

## 10) Guide overlay: countdown duration

- Updated guide auto-advance/countdown to **4 seconds** per step/part.

File:
- `lib/widgets/spotlight_navigation_guide_overlay.dart`

---

*End of work log — 30 April 2026.*

