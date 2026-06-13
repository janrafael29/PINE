# Combined documentation

> **Current stack (Jun 2026):** **PINYA-PIC** — Flutter Android app; **Supabase** (Auth, Postgres, Storage); on-device **YOLO26s → TFLite** (`mealybug_v16_selffix`, **640×640** infer, trained @ 1280). Shipped model: **`assets/model/best.tflite`**. Training/revision: **v20 pipeline** on Vast H100 (`docs/V20_TRAINING_LOG.md`). Architecture: **`docs/thesis/SYSTEM_ARCHITECTURE.md`**. Primary runbook: **`RUN.md`**.

**Latest work log:** `docs/work_logs/June 10 work log.md` — Phase 0 on Vast, v20s training, disk cleanup 124→39 GB.

This file combines project Markdown that previously lived across the repo (some sections are summaries; prefer **`RUN.md`** for setup and operations).

---

## How the project works (end-to-end)

This section is a practical “system tour” for understanding **PINYA-PIC** without reading the whole codebase.

### High-level architecture

- **UI layer**: Flutter screens under `lib/screens/` (login/register, dashboard, fields, add photo, maps, result preview).
- **Core & state**: shared configuration and runtime flags under `lib/core/` (e.g., `config.dart`, `constants.dart`, `theme.dart`, `app_state.dart`).
- **Services**: concrete integrations and heavy work in `lib/services/` (inference, DB, cloud sync, Supabase wrappers).
- **Utilities**: preprocessing, coordinate transforms, severity math, helpers in `lib/utils/`.
- **Assets**: the shipped object detection model at `assets/model/best.tflite`.

### What happens when a user “detects” mealybugs

The app’s detection flow is **photo-based**:

1. **User captures/selects an image**
   - Camera capture and gallery selection are in `lib/screens/permission_screens.dart`.
   - Camera capture uses `image_picker` (system camera UI) and returns a JPEG file.
2. **Preprocessing (letterbox + normalize)**
   - The image is decoded and EXIF orientation is applied.
   - The preprocessor resizes with **letterboxing** to match the model input size (default 640×640).
   - Key file: `lib/utils/image_preprocessor.dart`.
3. **TFLite inference (on a background isolate)**
   - The model is loaded from assets (copied to disk for isolate safety).
   - Inference runs via `tflite_flutter` in an isolate to avoid UI jank.
   - Key file: `lib/services/inference_service.dart`.
4. **Post-processing: parse + score filter + NMS**
   - Model outputs are parsed into raw detections, then filtered by score threshold, then merged by NMS IoU.
   - NMS runs in Dart (export uses `nms=False`).
   - Thresholds come from `AppConfig` / `AppConstants`.
5. **Coordinate mapping + UI overlay**
   - Detected boxes are mapped back to the original image space and drawn on the result image.
   - You’ll see per-box confidence (as percent) in the results UI.
6. **Persist/save + (optional) sync**
   - The app saves locally for offline use; when online, it can upload and write detection rows to Supabase.
   - Supabase tables and storage policies are documented in `supabase/README.md`.

### Offline vs online responsibilities (important)

- **Offline (always available)**
  - Inference runs fully on-device using `assets/model/best.tflite`.
  - Local persistence uses SQLite through `DatabaseService`.
- **Online (Supabase-enabled features)**
  - Authentication, profile data, cloud detections, and storage uploads depend on compile-time defines:
    - `SUPABASE_URL`
    - `SUPABASE_ANON_KEY`
  - See `RUN.md` for the recommended Windows run script (`scripts/run_debug.ps1`) and `--dart-define-from-file`.

### Key configuration knobs (where to change behavior)

- **Model path / input size / default thresholds**: `lib/core/constants.dart`
- **Balanced / accuracy presets** (threshold, NMS, tiling): `lib/core/config.dart`
- **Model labels** (must match training class order): `InferenceService.classLabels` in `lib/services/inference_service.dart`
- **Shipped model file**: `assets/model/best.tflite`

### Recent application updates (summary — Apr–May 2026)

- **Detection:** Bundled **`assets/model/best.tflite`** was aligned with a known-good on-device model; default **balanced** tuning uses **`detectionThreshold = 0.20`** and **`nmsThreshold = 0.45`** (`lib/core/config.dart`, `lib/core/constants.dart`).
- **Dataset tooling:** **`scripts/audit_yolo_dataset.py`**, **`scripts/extract_dataset_zip.py`**, **`scripts/dedup_dataset_images.py`** support auditing/cleaning YOLO exports (label noise and duplicates hurt accuracy more than raw image count).
- **UX / theming:** Dark mode applied across camera/add-photo, disease screens, captured-photo detail, fields/farm edit flows, profile, and the in-app **navigation guide** (spotlight overlay + preference screens).
- **Auth UX (keyboard):** Login/register are keyboard-safe (scroll + viewInsets padding) and dismiss keyboard on outside tap/scroll-drag (`lib/screens/login_screen.dart`, `lib/screens/register_screen.dart`).
- **Camera capture clarity:** Camera capture uses rear camera + max quality in `image_picker` (`preferredCameraDevice: rear`, `imageQuality: 100`) to reduce compression blur on tiny pests (`lib/screens/permission_screens.dart`).
- **Guide:** Post-login spotlight tour with sequence steps, **Back** / **Next**, auto-advance per step (~3s), and performance-oriented overlay painting (low-end devices).
- **Profile:** Avatar actions (view full screen, camera, gallery) and compact header aligned with other tabs.
- **Post-scan:** Results screen includes short **“What to do next”** prevention/rescan guidance.
- **Dashboard:** Map preview row **`FilledButton`** constrained for valid layout inside `Row` (avoids infinite-width constraint crashes during guide measurement).
- **Detections Map:** Fields filter now **fits camera to all visible pins** (zoom in/out as needed) and uses an **animated pan+zoom** transition so users can follow the move (`lib/screens/detections_map_screen.dart`).
- **Images (performance):** Dashboard/Saved Images now request **resized thumbnails** via Supabase Storage render endpoints (less bytes + faster decode) with better loading placeholders (`lib/widgets/capture_thumbnail.dart`, `lib/screens/main_dashboard_screen.dart`).
- **Bulk gallery (Add Photo):** Multi-select runs **detection on every image first** (“Scanning photos…”), then **one map** (`BulkGalleryPinScreen`) to place **all no-GPS** photos inside the chosen field (numbered pins); cancel discards the batch (`lib/screens/permission_screens.dart`, `lib/screens/bulk_gallery_pin_screen.dart`). See **`docs/May 10-11 work log.md`**.
- **Select Location map:** When a local **field boundary** is known, **`LocationPickerScreen`** draws the **polygon** and **fits the camera** to it (optional `fieldBoundaryLand`); used from gallery “choose on map” and result-screen location edit (`lib/screens/location_picker_screen.dart`, `lib/screens/permission_screens.dart`).
- **Supabase (admin):** Migration **`supabase/migrations/20260509120000_admin_detections_insert.sql`** adds **`detections` insert** for JWT **`app_metadata.admin`** (dashboard / server-side inserts). See **`docs/May 10-11 work log.md`**.
- **Admin mobile visibility (May 12):** Admin JWT sessions now use centralized helpers in **`lib/core/admin_session.dart`** so dashboard, field lists/pickers, and map flows can show **all visible `fields` / `detections`** allowed by RLS instead of hard-filtering every query by `user_id`.
- **Owner labels for admins (May 12):** Field UIs batch-load **`profiles.display_name` / `email`** and show **Owner:** labels in admin views (dashboard field cards, map field sheet, assign/select flows, and field lists).
- **Admin field editing (May 12):** **`EditFieldScreen`** now allows JWT admins to edit another user's field while preserving the original **`fields.user_id`** and owner-scoped preview-image storage path.
- **Detections Map pins (May 12):** Final marker pass kept **one pin per detection**, reduced the on-screen size / hit box, and redesigned **`HexPulseMarker`** into a cleaner hex-framed pin closer to the desired reference style (`lib/widgets/hex_pulse_marker.dart`, `lib/screens/detections_map_screen.dart`).
- **Anonymized research export (May 12):** Added **`supabase/statistician_anonymized_export.sql`** and **`docs/STATISTICIAN_EXPORT_ANONYMIZED.md`** for pseudonymized CSV handoff (`detections_joined_anon.csv`, `field_summary_anon.csv`, `image_manifest_anon.csv`) plus a private-only image rename helper.
- **Model refresh (May 21):** **`mealybug_fix500`** fine-tune on merged **`datasets/`** (~3.6k train); **`assets/model/best.tflite`** updated from export (~9.8 MB). Field reference photo still weaker than **`mealybug_v2`** — see **`docs/TRAIN_V10_17K.md`**; full **v10 ~17k** train on Vast still pending.
- **Research export (May 21):** **`scripts/extract_detection_images.py`** downloads images from **`results/detections_rows.csv`** into **`results/detections_images.zip`** (+ **`manifest.csv`**).
- **Thesis errata (May 21):** **`docs/THESIS_FIGURES_TABLES_ERRATA.md`** — threshold (20% vs 30%), ERD vs live schema, YOLO11 vs YOLO26 naming, figure/table fixes.

**Historical session log (optional):** **`docs/RECENT_WORK_LOG.md`** — narrative changelog with per-day supplements (**`docs/May 21 work log.md`**, **`docs/May 15 work log.md`**, **`docs/May 12 work log.md`**, **`docs/May 10-11 work log.md`**, **`docs/May 9 work log.md`**, etc.); day-to-day accuracy for clone/run is **`RUN.md`**.

---

## Source: `README.md`

# 🌱 PINE / PINYA-PIC — Pest Identification on Native Environments

[![Flutter](https://img.shields.io/badge/Flutter-stable-blue)](https://flutter.dev)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen)](CONTRIBUTING.md)

Offline-first Android app (**PINYA-PIC** in the UI) for detecting tiny agricultural pests (e.g., mealybugs) using **Ultralytics YOLO26** (default **nano**) exported to **TensorFlow Lite**. Optimized for low-end devices (~3 GB RAM class).

## ✨ Features

- 📱 **Fully Offline** - No internet required for inference
- 🎯 **Small Object Detection** - Optimized for tiny pests like mealybugs
- 📸 **Real-time Camera** - Live detection with bounding boxes
- 🗺️ **Geo-tagging** - Map integration for field data
- 💾 **Local Storage** - Save detection results with SQLite
- ⚡ **Lightweight** - Runs smoothly on 3GB RAM devices

## 🏗️ Tech Stack

| Layer | Technology |
|-------|------------|
| Dataset Management | [Roboflow](https://roboflow.com) |
| Model Training | [Ultralytics YOLO26](https://github.com/ultralytics/ultralytics) (default `yolo26n.pt` in `scripts/retrain_yolo.py`) |
| Export Format | TensorFlow Lite (ship float32-input when needed; export via `retrain_yolo.py`, **`nms=False`**) |
| Mobile Framework | [Flutter](https://flutter.dev) (Dart SDK per `pubspec.yaml`) |
| Inference Engine | [tflite_flutter](https://pub.dev/packages/tflite_flutter) |

## 📁 Project Structure

```
PINE/
├── lib/
│   ├── main.dart
│   ├── core/           # Constants and configuration
│   ├── screens/        # UI screens (detection, maps)
│   ├── services/       # Camera, inference, geolocation
│   ├── models/         # Data models
│   └── utils/          # Image processing, bounding boxes
├── assets/
│   └── model/          # Place your trained model here
│       └── best.tflite
├── android/            # Native Android configuration
├── pubspec.yaml        # Dependencies
└── RUN.md              # Clone → Flutter → Supabase → train/ship model
```

## 🚀 Quick Start

### Prerequisites
- Flutter SDK (stable; see `pubspec.yaml` / `flutter doctor`)
- Android Studio with SDK
- JDK 17+ (align with `android/` Gradle settings)

### 1. Clone & Install
```bash
git clone <your-repo-url>
cd PINE
flutter pub get
```

### 2. Add Your Model
```bash
# Train + export (project script; default YOLO26n). See RUN.md §6.
python scripts/retrain_yolo.py
# Optional GPU wrapper: scripts/train_gpu_50_then_100.ps1

# Copy to assets (Windows PowerShell)
# Prefer float32-input for device compatibility; use float16 if you know your phone supports it.
copy runs\retrain\mealybug_v2\weights\best_float32.tflite assets\model\best.tflite

# Or on macOS/Linux:
# cp runs/retrain/mealybug_v2/weights/best_float32.tflite assets/model/best.tflite
```

### 3. Run on Device/Emulator
```bash
# Start an emulator or connect a device, then (Supabase keys required for full app):
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
# On Windows, prefer:  .\scripts\run_debug.ps1 -SupabaseUrl '...' -SupabaseAnonKey '...'
```

## 🎯 Model Specifications

| Parameter | Value |
|-----------|-------|
| **Model Variant** | yolo26n (default train weights; override with `--weights`) |
| **Input Resolution** | 640×640 |
| **Quantization** | Float16 or float32-input (ship float32-input when float16-input kernels fail on-device) |
| **Display threshold** | **0.20** default (`AppConstants.detectionThreshold` in `lib/core/constants.dart`; `AppConfig.balanced()`; user presets may differ) |
| **NMS IoU** | **0.45** (`AppConstants.nmsThreshold`) — NMS runs in **Dart**, not in the TFLite graph |
| **Output Format** | Bounding boxes + class confidences |

## 🧪 Testing Features

| Feature | How to Test |
|---------|-------------|
| Camera Detection | Point at sample images |
| Bounding Boxes | Check overlay accuracy |
| Map Integration | Navigate to Lands tab |
| Geolocation | Grant permission, check location |
| Database | Save and retrieve detections |

## ⚙️ Configuration

Key configuration files:
- `lib/core/constants.dart` — model path, input size, thresholds, optional tiled inference
- `lib/core/config.dart` — balanced / accuracy presets
- `android/app/build.gradle.kts` — SDK versions
- `pubspec.yaml` — dependencies

## 🔧 Troubleshooting

| Issue | Solution |
|-------|----------|
| **BaseVariant error** | Check Kotlin (1.9.24), AGP (8.6.0), Gradle (8.7) |
| **Emulator crashes** | Use API 34, set RAM to 1024MB, cold boot |
| **ADB not detecting device** | `adb kill-server` then `adb start-server` |
| **Model not loading** | Verify path in `constants.dart` |

## 📚 Documentation

- **[RUN.md](RUN.md)** — clone, Flutter, **Supabase** `--dart-define`, optional scrcpy, **YOLO26** train/export, recent project summary (§10–11)
- **[docs/RECENT_WORK_LOG.md](docs/RECENT_WORK_LOG.md)** — narrative changelog (supplements index)
- **[docs/May 21 work log.md](docs/May%2021%20work%20log.md)** — fix500 train + TFLite ship, detection image zip export, thesis errata, v10/Vast roadmap
- **[docs/MODEL_COMPARISON_V2_V10_V11_V12.md](docs/MODEL_COMPARISON_V2_V10_V11_V12.md)** — fair benchmark table (v2 / v10 / v11 / v12 @ conf 0.12, IoU 0.45, imgsz 640)
- **[docs/TRAIN_V10_17K.md](docs/TRAIN_V10_17K.md)** — full Roboflow v10 (~17k) train on Vast vs local; fix500 vs v2 field photo compare
- **[docs/THESIS_FIGURES_TABLES_ERRATA.md](docs/THESIS_FIGURES_TABLES_ERRATA.md)** — manuscript vs codebase corrections before final PDF
- **[docs/May 15 work log.md](docs/May%2015%20work%20log.md)** — per-field image counts (Supabase aggregates + dashboard/map)
- **[docs/May 12 work log.md](docs/May%2012%20work%20log.md)** — admin mobile visibility, owner labels, admin field edit, final map pins, anonymized export
- **[docs/May 10-11 work log.md](docs/May%2010-11%20work%20log.md)** — bulk gallery scan-then-pin, location picker field boundary, admin `detections` insert policy
- **[docs/May 9 work log.md](docs/May%209%20work%20log.md)** — map/cache/sync/captured-photos/welcome/password UX (earlier May 2026)
- **[docs/STATISTICIAN_EXPORT_ANONYMIZED.md](docs/STATISTICIAN_EXPORT_ANONYMIZED.md)** — safer pseudonymized CSV + image handoff for external analysis
- **[supabase/README.md](supabase/README.md)** — migrations, RLS, Storage
- [Contributing](CONTRIBUTING.md) — how to contribute

## May 8, 2026 updates (full summary)

### Detections Map: fit-to-pins on filter selection

- When switching the Fields filter (**All detections**, **Unassigned**, or a specific field), the map now automatically re-aligns so **all visible pins** are on screen.
- Implementation uses a one-shot flag (`_pendingFitToPins`) and schedules a post-frame camera update after the filtered pin list (`pts`) is computed.
- Uses `CameraFit.coordinates(...)` with padding (extra bottom padding so pins aren’t hidden behind the Fields FAB).
- If there are **no pins**, the camera falls back to fitting the selected field’s local fence polygon (when available), otherwise it moves to the default region.
- File: `lib/screens/detections_map_screen.dart`

### Detections Map: animated camera transitions

- Map camera adjustments (fit-to-pins and no-pins fallback) now **animate** (pan + zoom) so users can see where the map moved instead of an instant jump.
- File: `lib/screens/detections_map_screen.dart`

### Dashboard: faster image loading (Saved Images + Field previews)

- Thumbnails now request **resized images** from Supabase (render endpoint) instead of always downloading full-size originals, which reduces bytes and speeds up decode.
- Added better loading placeholders and decode sizing via `cacheWidth` where network images are shown.
- Files:
  - `lib/widgets/capture_thumbnail.dart` (adds `maybeSupabaseRenderUrl(...)` and uses it for remote thumbnails)
  - `lib/screens/main_dashboard_screen.dart` (uses resized URLs + loading builders for preview images)

## May 10–11, 2026 updates (full summary)

### Add Photo — bulk gallery: scan first, place pins once

- After field selection, the app scans **all** picked images (EXIF GPS when present + on-device mealybug inference per image) before saving.
- Photos **without EXIF GPS** (when online and a **field polygon** exists locally) open **`BulkGalleryPinScreen`**: satellite map, field outline, **numbered markers**; user adjusts positions then **confirms all**; cancelling drops the whole batch.
- Files: `lib/screens/permission_screens.dart`, `lib/screens/bulk_gallery_pin_screen.dart`
- Day log: **`docs/May 10-11 work log.md`**

### Select Location — field boundary on the map

- **`LocationPickerScreen`** accepts optional **`fieldBoundaryLand`** (`Land`): draws **`PolygonLayer`**, fits camera to the fence, relaxes Polomolok-only camera constraint when needed; avoids auto-snapping the pin to GPS on first load when a boundary is shown.
- Wired from gallery “choose on map”, **`PhotoResultScreen`** location card (uses **`_fence?.land`**), and single-gallery flows that resolve land by field name.
- Files: `lib/screens/location_picker_screen.dart`, `lib/screens/permission_screens.dart`

### Supabase — admin insert on `detections`

- Migration **`supabase/migrations/20260509120000_admin_detections_insert.sql`**: RLS **`insert`** on **`public.detections`** for JWT **`app_metadata.admin` = true**.
- End-user “duplicate capture to another field” in the mobile app is separate (not covered by this policy-only change).

## May 12, 2026 updates (full summary)

### Admin mobile sessions: all fields / detections allowed by RLS

- Added **`lib/core/admin_session.dart`** to centralize admin JWT checks and session-aware Supabase reads/streams.
- Dashboard, field lists, map field filters, assign/select flows, and Diagnose detections now avoid hard-coded `user_id` filtering for admins.
- Local field caching preserves each row's original **`user_id`** so admin sessions do not overwrite ownership in cache.

### Owner labels in admin views

- Admin field cards and pickers now batch-load **`profiles.display_name`** / **`email`** and show **Owner:** labels with fallback to shortened user id.
- Applied in dashboard field cards, map field sheet, assign/select flows, captured-photos field picker, and standalone fields list.

### Admin can edit another user's field

- **`EditFieldScreen`** now accepts admin sessions, preserves the original field owner on save, and keeps preview-image upload paths under the real owner's storage prefix.

### Detections Map marker redesign

- Final pin changes kept **one marker per detection** (no clustering in the final state), reduced on-screen size / hit box, and redesigned **`HexPulseMarker`** into a cleaner hex-framed pin style.

### Anonymized statistician export materials

- Added **`supabase/statistician_anonymized_export.sql`** for pseudonymized CSV exports.
- Added **`docs/STATISTICIAN_EXPORT_ANONYMIZED.md`** with share / do-not-share guidance, salt usage, and image-rename workflow.

## May 21, 2026 updates (full summary)

### `mealybug_fix500` fine-tune and bundled TFLite

- Fine-tuned **YOLO26n** from **`mealybug_v2/weights/best.pt`** on merged **`datasets/`** (~**3,621** train images after fix-set review).
- Exported **float32-input** TFLite and copied to **`assets/model/best.tflite`** (~**9.8 MB**).
- **Field-test regression:** on a fixed reference photo, **`fix500`** still underperformed **`mealybug_v2`** for a white cluster (~**19%** vs ~**38%** confidence) — documented in **`docs/TRAIN_V10_17K.md`**.
- **Next:** **`mealybug_v10`** on Roboflow v10 export (~**16k** train aug) via **Vast** (see **`docs/VAST_TRAINING.md`**, **`docs/TRAIN_V10_17K.md`**).

### Supabase detection images export

- **`results/detections_rows.csv`** → **`scripts/extract_detection_images.py`** → **`results/detections_images.zip`** (**826** rows, **410** unique images, **`manifest.csv`** for `detection_id` linkage).
- Day log: **`docs/May 21 work log.md`**

### Thesis / manuscript errata checklist

- **`docs/THESIS_FIGURES_TABLES_ERRATA.md`** — deployed **0.20** threshold vs **30%** prose, conceptual ERD vs **`profiles`/`fields`/`detections`**, YOLO11 metrics vs YOLO26n deployment, figure/table fixes.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Ultralytics for YOLO / YOLO26
- Flutter team for the framework
- [Your Professor] for guidance

---
⭐ Star this repo if you find it useful!

---

## Source: `ARCHITECTURE.md`

## PINE Architecture Overview

PINE / **PINYA-PIC** is an offline-first Flutter application for detecting tiny agricultural pests on pineapple plants using on-device **YOLO TFLite** inference, with optional **Supabase**-backed cloud sync (Auth, Postgres, Storage) and analytics.

### High-level layers

- **Presentation (`lib/screens`)**
  - Flutter `Widget`s for user flows:
    - Onboarding, login/register, profile, settings.
    - Detection flow (`DetectionScreen`) and related navigation (`HomeScreen`, dashboards).
    - Fields/lands management and disease/education content.
- **Services (`lib/services`)**
  - Infrastructure and domain-oriented helpers:
    - Camera (`CameraService`) for image capture.
    - Inference (`InferenceService`) for YOLO TFLite execution.
    - Database (`DatabaseService`) for SQLite persistence of lands and detections.
    - Geo (`GeoService`) for GPS acquisition and `GeoFenceService` for point-in-polygon checks.
    - Image storage (`ImageStorageService`) for storing captured images on device.
    - Orchestration (`DetectionFlowController`) for end-to-end detection capture and persistence.
    - Dashboard helpers (`DashboardStatsCalculator`) for aggregating detection statistics.
- **Core (`lib/core`)**
  - Cross-cutting concerns:
    - Theming (`theme.dart`).
    - Model configuration (`config.dart`, constants).
    - Simple dependency injection via `ServiceLocator`.
    - Global app state via `AppState` (e.g., auth flags).
- **Models (`lib/models`)**
  - Data models representing:
    - `DetectionRecord`, `DetectionResult`, detection boxes.
    - `Land` and `LatLngPoint` for geofencing.

### Key data flows

#### 1. Detection flow (camera → inference → DB → UI)

1. User navigates to `DetectionScreen`.
2. `DetectionFlowController` coordinates:
   - Capture image bytes from `CameraService`.
   - Run YOLO inference via `InferenceService` (separate isolate).
   - Acquire GPS via `GeoService` (with last-known fallback and explicit errors).
   - Geo-fence the point against local lands via `GeoFenceService`.
   - Save image to on-device storage (`ImageStorageService`).
   - Persist a `DetectionRecord` into SQLite through `DatabaseService`.
3. `DetectionScreen` receives a `DetectionFlowOutcome` and:
   - Updates UI state (image preview, bounding boxes, inference time).
   - Displays geo info and land association or a clear error if GPS fails.

#### 2. Offline data flow (SQLite + Supabase)

- Local spatial and detection data:
  - Stored in SQLite (`DatabaseService`) and used for:
    - Geo-fencing land boundaries.
    - Local history and analytics.
- Cloud-backed views:
  - **Supabase** (Postgres + Storage) backs profiles, fields, detections, and uploads. The app is configured at compile time with **`SUPABASE_URL`** and **`SUPABASE_ANON_KEY`** (`RUN.md`). SQLite remains the authoritative store for geometry and unsynced captures; see **`docs/RECENT_WORK_LOG.md`** Part II §14 for restore semantics.

### Dependency injection and state management

- **DI**
  - `ServiceLocator` (`lib/core/service_locator.dart`) provides a tiny service registry.
  - Core services (camera, inference, DB, geo, geofence, image storage) are registered in `main.dart` at startup.
  - `DetectionFlowController` resolves services from the locator when explicit instances are not provided, enabling easier testing and replacement.
- **State management**
  - Screens primarily use local `StatefulWidget` state for view-specific concerns.
  - `AppState` (`lib/core/app_state.dart`) is a `ChangeNotifier` exposed via `ChangeNotifierProvider` at the root (`main.dart`), enabling reactive updates for app-wide flags (for example, login state influencing greetings on the dashboard).

### Invariants and design principles

- Detection records are only persisted with valid GPS coordinates; failures surface as user-visible errors (no `(0,0)` fallbacks).
- SQLite is the authoritative offline store for lands and on-device detections; Supabase mirrors uploaded captures and powers dashboards when online.
- Expensive operations (model inference) are offloaded to isolates; IO-heavy flows are orchestrated in services rather than embedded directly in widgets.

---

## Source: `CONTRIBUTING.md`

# Contributing to PINE

Thank you for your interest in contributing to PINE (Pest Identification on Native Environments).

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/PINE.git`
3. Follow **[RUN.md](RUN.md)** for installation and Supabase setup

## Development Workflow

1. Create a feature branch: `git checkout -b feature/your-feature`
2. Make your changes
3. Test thoroughly: `flutter test`
4. Run the linter: `flutter analyze`
5. Commit with clear messages: `git commit -m "Add: brief description"`
6. Push and create a Pull Request: `git push origin feature/your-feature`

## Code Style

- Follow Flutter lint rules in `analysis_options.yaml`
- Use meaningful variable and function names
- Add comments for complex logic
- Update documentation (**RUN.md**; optional **docs/RECENT_WORK_LOG.md**) for new features

## Reporting Issues

- Use [GitHub Issues](https://github.com/YOUR_TEAM/PINE/issues)
- Include device/emulator details (e.g. API level, RAM)
- Attach error logs or screenshots when possible
- Check existing issues before opening a new one

## Pull Request Guidelines

- Keep PRs focused on a single feature or fix
- Test on both emulator and physical device when relevant
- Ensure `flutter analyze` passes
- Request review from a maintainer

## Model & Large Files

- Do **not** commit large model files (>100MB) to the repo
- Use shared drive or cloud storage and document the link/version
- Document model version and training date in code or docs

---

For detailed setup (Gradle, Kotlin, emulator), see **RUN.md** and Android Studio / `flutter doctor` output.

---

## Source: `SETUP_GUIDE.md`

*(Legacy placeholder — use **[RUN.md](RUN.md)** for current setup. Original `SETUP_GUIDE.md` is not maintained in-tree.)*

---

## Source: `COMPLETE_SETUP_SUMMARY.md`

*(Legacy placeholder — use **[RUN.md](RUN.md)** and **[supabase/README.md](supabase/README.md)**.)*

---

## Source: `docs/COMPLETE_SETUP_GUIDE.md`

*(Legacy placeholder — Firebase-era doc; **current backend is Supabase**. See **RUN.md**.)*

---

## Source: `docs/OFFLINE_STRATEGY.md` (updated summary — Supabase)

## Offline Data Strategy for PINE / PINYA-PIC

SQLite and **Supabase** work together: **SQLite** is the on-device source of truth for lands, local detection rows, upload queue, and captured-photo metadata. **Supabase** stores `profiles`, `fields`, `detections`, and **Storage** objects for synced captures; the app uses **`CloudSyncService`** / **`DetectionService`** and optional remote restore (**`CapturedPhotosRemoteSync`**). Only rows that **successfully uploaded** can be restored after reinstall. See **`docs/RECENT_WORK_LOG.md`** Part II §14 and **`supabase/README.md`** for RLS and migration order.

---

## Source: `firebase/SECURITY_RULES_CHECKLIST.md` (historical)

> **Not used in the current app.** Security for cloud data is **Supabase RLS** and Storage policies in **`supabase/migrations/*.sql`**. Run **`supabase/verify_setup.sql`** after migrations. The checklist below is kept only as a generic reference pattern.

### 1. Row Level Security (Supabase Postgres)

- Enforce **`auth.uid()`** (or equivalent) on `profiles`, `fields`, `detections`.
- Validate column types and required fields on insert/update.

### 2. Storage policies

- Restrict **`detections`** and **`avatars`** buckets to authenticated users as implemented in migrations.

### 3. Operational checklist

- Separate Supabase projects for dev vs production where possible.
- Re-audit when adding tables, buckets, or new client write paths.

---

## Source: `scripts/README.md`

# YOLO retraining scripts (YOLO26 default)

## Prerequisites

- **Python 3.10+** (3.12/3.13 common on Windows); use a **venv** at **`.venv/`**
- **GPU recommended** (CUDA PyTorch) for multi-hour runs
- Current Ultralytics with **YOLO26** support

```bash
pip install -U ultralytics torch
pip install -r scripts/requirements-export.txt   # TFLite export chain
```

## 1. Prepare dataset

- Standard layout under **`datasets/`**: `data.yaml`, `train/images`, `train/labels`, `valid/...`, optional `test/...` (Roboflow YOLO export).
- From a zip: `python scripts/retrain_yolo.py --from-zip path\to\dataset.zip` (see **`RUN.md`**).
- Audit: `python scripts/audit_yolo_dataset.py`

## 2. Retrain

```powershell
cd D:\PINE
.\.venv\Scripts\python.exe scripts\retrain_yolo.py
# Optional: long runs + CUDA preflight + session log under logs/
# .\scripts\train_gpu_50_then_100.ps1 -FromZip "...\export.zip" -NoDatasetBackup -Batch 1
```

Default weights: **`yolo26n.pt`**. Do not **`--resume`** from a different YOLO generation’s `.pt`.

## 3. Use new model in app

```powershell
# Prefer float32-input unless you know float16-input works on your phone.
copy runs\retrain\mealybug_v2\weights\best_float32.tflite assets\model\best.tflite
```

Then `flutter pub get` / rebuild. Align **`InferenceService.classLabels`** with `datasets/data.yaml` **`names`**.

---

## Source: `scripts/fix_tflite_export.md`

# Fix TFLite export (NumPy/TensorFlow conflict)

> **Current path:** Prefer **`python scripts/retrain_yolo.py --export-only …`** and **`scripts/requirements-export.txt`** (TensorFlow **2.20+** / **tf_keras** pins for Python 3.13). The steps below are a **legacy venv cleanup** if you still hit NumPy/TF conflicts.

The export failed because of mixed NumPy versions and TensorFlow's requirements.

## Option A: Clean venv and re-export (recommended)

**1. Close the current terminal and open a new one.**

**2. Activate venv and remove conflicting packages:**
```powershell
cd D:\PINE
.\.venv\Scripts\Activate.ps1
pip uninstall numpy scipy tensorflow tensorboard keras -y
```

**3. Remove leftover NumPy folders** (if they exist):
```powershell
Remove-Item -Recurse -Force "D:\PINE\venv\Lib\site-packages\~umpy" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "D:\PINE\venv\Lib\site-packages\~umpy.libs" -ErrorAction SilentlyContinue
```

**4. Install a compatible set** (TensorFlow 2.19 needs NumPy < 2.2):
```powershell
pip install "numpy>=1.26,<2.2"
pip install tensorflow>=2.18,<=2.19
```

**5. Run export again:**
```powershell
yolo export model=runs/detect/train3/weights/best.pt format=tflite imgsz=640 half=True
```

**6. If it still fails with the same NumPy error**, install NumPy 2.1.3 explicitly and reinstall scipy:
```powershell
pip install numpy==2.1.3
pip install --force-reinstall scipy
yolo export model=runs/detect/train3/weights/best.pt format=tflite imgsz=640 half=True
```

---

## Option B: Export ONNX then convert (skip TensorFlow)

If Option A keeps failing, you can export to ONNX (no TensorFlow), then convert to TFLite using another tool, or use the ONNX model with an ONNX runtime on device. For Flutter we need TFLite, so Option A is simpler.

---

## After export succeeds

```powershell
copy runs\detect\train3\weights\best_float32.tflite assets\model\best.tflite
flutter run
```

---

## Source: `assets/model/README.md`

# Model Directory

Place your trained **YOLO26** (or compatible) TensorFlow Lite model here.

**Required file:** `best.tflite`

## Export from Ultralytics (must use `nms=False`)

The app does NMS in Dart. Export **without** in-graph NMS to avoid TFLite PAD errors on device.

From project root with venv activated:

**Option A – use the retrain script (recommended):**

```powershell
# Full run: train then export
python scripts/retrain_yolo.py

# Export only (if you already have best.pt)
python scripts/retrain_yolo.py --export-only runs/retrain/mealybug_v2/weights/best.pt
# or: python scripts/retrain_yolo.py --export-only runs/detect/train3/weights/best.pt
```

Then copy the printed path into assets:

```powershell
copy runs\retrain\mealybug_v2\weights\best_float32.tflite assets\model\best.tflite
```

**Option B – yolo CLI (must pass nms=False):**

```powershell
yolo export model=runs/detect/train3/weights/best.pt format=tflite imgsz=640 half=False nms=False
copy runs\detect\train3\weights\best_float32.tflite assets\model\best.tflite
```

Then: `flutter clean`, `flutter pub get`, then run or build.

See **`RUN.md`** §6 and the header of **`scripts/retrain_yolo.py`**.

## Requirements

- Format: TensorFlow Lite
- Quantization: Float16 or float32-input (ship float32-input when float16-input kernels fail on-device)
- Input size: 640×640 (must match `AppConstants.inputSize` unless you change all three: train, export, app)
- Default train variant: **yolo26n** (Ultralytics)

## Class labels (multi-class models)

If your model has **more than one class**, you must keep labels in sync in two places:

1. **`assets/labels/labels.txt`** – one label per line, in the **same order** as the class indices used during training (e.g. class 0 = first line, class 1 = second line).
2. **`lib/services/inference_service.dart`** – the `InferenceService.classLabels` list (e.g. `List<String> classLabels = ['mealybug', 'aphid'];`) must match the same order.

The app uses the class index from the model output to look up the label; wrong order will show incorrect names on detections.

---

## Source: `assets/tiles/README.md`

# Offline Map Tiles

For fully offline map rendering, add an MBTiles file here (e.g., `map.mbtiles`).

Download MBTiles from:
- https://protomaps.com/downloads
- https://openmaptiles.org/

Without MBTiles, the map will use OpenStreetMap tiles (requires network on first load).

