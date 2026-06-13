# How to run PINE after cloning from GitHub

This project is a **Flutter** app (primary target **Android**). Follow the steps below on your machine after you clone the repository.

---

## 1. Prerequisites

Install the following before you continue:

| Tool | Notes |
|------|--------|
| **Git** | To clone the repo. |
| **Flutter SDK** | Stable channel recommended. Run `flutter doctor` and fix any issues it reports. |
| **Android toolchain** | Android Studio (or SDK + platform tools), an **Android emulator** or a **physical device** with USB debugging. |
| **scrcpy** (optional) | Mirror/control a physical Android device from the PC; needs `adb` (see §5). |
| **Dart SDK** | Bundled with Flutter; this project expects **`>=3.2.0 <4.0.0`** (see `pubspec.yaml`). |

Verify:

```bash
flutter --version
flutter doctor -v
```

---

## 2. Clone the repository

Replace the URL with your fork or the upstream repo URL.

```bash
git clone https://github.com/YOUR_USERNAME/PINE-new.git
cd PINE-new
```

(Use the actual folder name shown after clone if it differs.)

---

## 3. Install dependencies

This repository does **not** commit `pubspec.lock` (it is listed in `.gitignore`). After clone, resolve packages locally:

```bash
flutter pub get
```

If you see errors about missing packages, run `flutter pub get` again from the project root (where `pubspec.yaml` lives).

---

## 4. Supabase configuration (required for cloud features)

The app initializes **Supabase** at startup using **compile-time** environment variables:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

If these are **not** provided, the app starts with a **configuration screen** instead of the full dashboard (`ConfigRequiredScreen` in `lib/main.dart`).

### Run with Supabase (recommended)

From the project root, pass both values as `--dart-define` (replace with your project URL and anon key from the Supabase dashboard):

**PowerShell (Windows)**

Prefer the repo script (uses **`--dart-define-from-file`**, which avoids JWT corruption from long `--dart-define=...` lines on Windows → Supabase **Invalid API key**):

```powershell
.\scripts\run_debug.ps1 -SupabaseUrl 'https://YOUR_PROJECT.supabase.co' -SupabaseAnonKey 'eyJ...'
```

The script checks locally that a **legacy JWT**’s `ref` matches your URL (or reminds you for **publishable** keys). It does **not** call Supabase over the network by default (network preflight can false-fail). Optional: add **`-TestSupabaseOnline`** to probe `GET /rest/v1/` first; add **`-StrictSupabaseProbe`** to abort if that request returns 401/403.

Or plain Flutter with explicit defines (fine for short values; JWTs can break on some Windows shells):

```powershell
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=your_anon_key_here
```

Or a JSON file (same mechanism as the script):

```powershell
# supabase_debug.json (do not commit — add to .gitignore if you use this)
# {"SUPABASE_URL":"https://YOUR_PROJECT.supabase.co","SUPABASE_ANON_KEY":"eyJ..."}
flutter run --dart-define-from-file=supabase_debug.json
```

**bash (macOS / Linux / Git Bash)**

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_anon_key_here
```

**VS Code / Android Studio:** Add the same `--dart-define=...` pairs to your run configuration’s **additional arguments** for the Flutter launch target.

### Run without Supabase (limited)

You can still run `flutter run` with no defines to open the app UI, but you will only see the **configuration required** flow until valid Supabase credentials are provided.

---

## 5. Run the app on a device or emulator

1. Start an Android emulator, or connect a phone with **USB debugging** enabled.
2. List devices:

   ```bash
   flutter devices
   ```

3. Run:

   ```bash
   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
   ```

   To target a specific device:

   ```bash
   flutter run -d <device_id> --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
   ```

The first build can take several minutes.

### Physical device mirroring (scrcpy)

[scrcpy](https://github.com/Genymobile/scrcpy) shows your Android phone on the PC and forwards input over USB (optional: wireless after setup). Useful next to `flutter run` on a real device.

1. Install **Android Studio** (or SDK **platform-tools**) so `adb` works; on the phone enable **Developer options** → **USB debugging**, connect USB, accept the RSA prompt.
2. Install scrcpy, e.g. with winget: `winget install Genymobile.scrcpy -e --accept-package-agreements`
3. **Open a new terminal** (PATH is updated on install), then:

   ```bash
   adb devices
   scrcpy
   ```

   If only one device is listed, `scrcpy` attaches to it. Use `scrcpy -s DEVICE_ID` when several are connected.

If `adb devices` shows **unauthorized**, unlock the phone and confirm the debugging prompt. If the device is **missing**, install the OEM **USB driver** (or Google USB Driver from Android SDK Manager).

---

## 6. Model and offline inference

The TensorFlow Lite model is bundled under `assets/model/` (see `pubspec.yaml`). **No download step is required** for inference after `flutter pub get` and a successful build.

### Training a new model (YOLO26 + dataset)

1. **Python venv:** `pip install -U ultralytics torch` (YOLO26 needs a current Ultralytics release). For TFLite export also install [`scripts/requirements-export.txt`](scripts/requirements-export.txt).
2. **New Roboflow zip:** `python scripts/retrain_yolo.py --from-zip path\to\export.zip` (backs up `datasets/` by default), or `python scripts/extract_dataset_zip.py path\to\export.zip`. Large zips / deleting old `datasets/` on Windows can take **a long time** with little output; `extract_dataset_zip.py` prints progress lines.
3. **Audit:** `python scripts/audit_yolo_dataset.py` — fix empty labels; ensure `datasets/data.yaml` paths resolve under `datasets/`.
4. **Train:** `python scripts/retrain_yolo.py` (default backbone **`yolo26n.pt`**; use `--weights` for another size). Do not `--resume` from an older YOLO generation’s `.pt`.
   - **GPU helpers (PowerShell):** [`scripts/train_gpu_50_then_100.ps1`](scripts/train_gpu_50_then_100.ps1), [`scripts/train_gpu_100.ps1`](scripts/train_gpu_100.ps1) — CUDA check, `python -u`, optional `-FromZip`, `-Batch`, and a session log under **`logs/train_session_*.log`** via **`retrain_yolo.py --log-file`**.
5. **Check export:** Run `python scripts/inspect_tflite.py` on the exported `.tflite` and confirm:
   - input: `[1, 640, 640, 3]` dtype `float32`
   - output: `[1, 300, 6]` dtype `float32`

6. **Ship:** Copy the exported `.tflite` to `assets/model/best.tflite`, then `flutter build apk --release` (plus your `--dart-define` values).

> **Device compatibility note:** Some phones fail to initialize **float16-input** Conv2D models (`CONV_2D failed to prepare`). If you hit that, export and ship a **float32-input** TFLite (`best_float32.tflite`) instead.

Details and checklist: header of [`scripts/retrain_yolo.py`](scripts/retrain_yolo.py).

### Option A — field photos without Roboflow credits

Pre-label new images locally, review in CVAT, merge into `datasets/train`:

- Guide: [`docs/OPTION_A_WORKFLOW.md`](docs/OPTION_A_WORKFLOW.md)
- Auto-label: `python scripts/auto_label_yolo.py --source path\to\photos --mark-empty`
- PowerShell: `.\scripts\field_day_option_a.ps1 -Source path\to\photos -MarkEmpty`
- Merge after review: `python scripts/merge_field_batch.py --batch field_batches\<batch_folder>`

---

## 7. Release build (optional)

To produce a release APK (Android):

```bash
flutter build apk --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

Output is typically under `build/app/outputs/flutter-apk/`.

---

## 8. Common issues

| Problem | What to try |
|--------|-------------|
| `flutter` not found | Add Flutter’s `bin` directory to your `PATH`, or use the full path to `flutter`. |
| No devices | Start an emulator, plug in a device, accept the USB debugging prompt, run `flutter devices`. |
| Gradle / Android build errors | Open **Android Studio** once to install missing SDK components; run `flutter doctor --android-licenses` and accept licenses. |
| `pub get` fails | Check network; ensure you are on a supported Flutter/Dart version and run `flutter upgrade` if needed. |
| App shows “configuration required” | Supabase URL/key were not passed at **run** or **build** time; add `--dart-define` as above. |

---

## 9. Quick reference (copy-paste)

```bash
git clone <YOUR_REPO_URL>
cd <REPO_FOLDER>
flutter pub get
flutter doctor
flutter run --dart-define=SUPABASE_URL=<URL> --dart-define=SUPABASE_ANON_KEY=<KEY>
```

Replace `<URL>` and `<KEY>` with your Supabase project values.

---

## 10. What changed recently (project summary)

Use **`RUN.md`** for setup; this section summarizes **recent app and tooling work** (Apr 2026) without duplicating per-day work logs.

| Area | Notes |
|------|--------|
| **On-device model** | **`assets/model/best.tflite`** — currently **`mealybug_v12`** (see `assets/model/README.md`, `AppConstants.shippedModelId`). Re-export from `runs/retrain/mealybug_v12/weights/best.pt` @ 640 after retraining. |
| **Default thresholds** | **`detectionThreshold = 0.20`**, **`nmsThreshold = 0.45`** in **`lib/core/constants.dart`** and **`AppConfig.balanced()`** in **`lib/core/config.dart`**. Accuracy/low-end presets may differ. |
| **Dataset hygiene** | Scripts: **`scripts/audit_yolo_dataset.py`**, **`scripts/extract_dataset_zip.py`**, **`scripts/dedup_dataset_images.py`**. Large exports need clean labels and low duplicate rate; see script headers. |
| **Navigation guide** | Post-login spotlight tour: **`lib/widgets/spotlight_navigation_guide_overlay.dart`**, preference UI in **`lib/screens/navigation_guide_preference_screen.dart`** and **`lib/screens/app_navigation_guide_screen.dart`**. |
| **Theming / UX** | Dark mode fixes across permission/camera flows, disease and field screens, profile (full-screen photo viewer + camera/gallery), post-scan **“What to do next”** card. |
| **Auth UX (keyboard)** | Login/register screens are keyboard-safe (scroll + viewInsets padding) and dismiss keyboard on outside tap/scroll-drag: **`lib/screens/login_screen.dart`**, **`lib/screens/register_screen.dart`**. |
| **Camera capture clarity** | Camera capture uses **rear camera** + **max quality** in `image_picker` (`preferredCameraDevice: rear`, `imageQuality: 100`) to reduce blur/compression loss for tiny pests: **`lib/screens/permission_screens.dart`**. |
| **Layout fix** | Map preview **`FilledButton`** in **`lib/screens/main_dashboard_screen.dart`** uses finite **`minimumSize`/`maximumSize`** so it lays out correctly inside a **`Row`** (prevents guide-step crashes). |

**Older narrative changelog (optional):** **[`docs/RECENT_WORK_LOG.md`](docs/RECENT_WORK_LOG.md)** — Part I (30 Mar–9 Apr 2026), Part II (earlier). Training/export: **`scripts/retrain_yolo.py`**, **`scripts/requirements-export.txt`**, **`scripts/train_gpu_*.ps1`**.

**Daily supplement logs (optional):** e.g. **[`docs/May 8 work log.md`](docs/May%208%20work%20log.md)** (map fit-to-pins + animated camera; faster image loading via resized Supabase thumbnails).

---

## 11. Default detection thresholds (reference)

Calibrated on **`mealybug.v10`** valid split (`scripts/sweep_detection_threshold.py`).

| Constant | Value | Role |
|----------|-------|------|
| `detectionThreshold` | **0.12** | Show box in UI ("possible" tier) |
| `confirmedDetectionThreshold` | **0.22** | Headline count / severity / save |
| `nmsThreshold` | **0.45** | Dart NMS IoU |

**Two-tier UI:** yellow = confirmed, orange = possible (review). Accuracy mode uses **0.08** / looser NMS for higher recall.

Re-run calibration after retraining: `python scripts/sweep_detection_threshold.py --quick`

Export remains **`nms=False`** (NMS in Dart).
