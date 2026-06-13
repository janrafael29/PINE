# Work log — 12–13 April 2026

Supplement to **`docs/RECENT_WORK_LOG.md`** and the day-scoped logs **`docs/work_logs/april 10 work log.md`**, **`docs/work_logs/April 11 work log.md`**. This entry captures **Flutter app UX, inference pipeline, Android toolchain, and IDE** work done across **12–13 April 2026** (including agent-assisted edits on the working tree).

**Git note:** Reconcile exact hunks with **`git log` / `git diff`** after commits; this log is organized by **theme** and **file paths** for manuscript and handoff use.

**Stack reminder:** **Supabase** via **`--dart-define=SUPABASE_URL`** and **`--dart-define=SUPABASE_ANON_KEY`** (or **`--dart-define-from-file`** / **`run_debug.ps1`**). Display name **PINYA-PIC**. Training stack in repo: **YOLO26n** default in **`scripts/retrain_yolo.py`**. **`pubspec.yaml`** version: see repo (this log referenced **`7.1.0+2022`** when written).

---

## Handoff for another agent

- **Inference:** Model file is prepared on the **root isolate** (`rootBundle` + disk) and the background isolate uses **`Interpreter.fromFile`** so **`ServicesBinding`** is never required off the UI isolate. **`main()`** must **`await AppState.loadPreferences()`** *before* **`runApp`** so inference uses the saved user preference on first run (e.g. a persisted **sensitivity threshold**, if set) and avoids stale `thr=` values in no-detection dialogs.
- **Thresholds:** **`AppConstants`** / **`AppConfig.balanced()`** / **`AppConfig.accuracy()`** were tuned for recall (see §2); align any paper table with **`lib/core/constants.dart`** and **`lib/core/config.dart`** at the release tag.
- **Navigation guide:** **`NavigationGuideHost`** uses a **process-wide guard** so the spotlight tour does not re-run every time **`UnlockGate`** remounts after biometric unlock (see §4).
- **Retake:** **`PhotoResultScreen`** returns the user to **`PhotoSourcePicker`** (Add Photo / Camera vs Gallery) via **`pushAndRemoveUntil`**, not a single **`pop`** (see §3).
- **Android builds:** **`org.gradle.java.home`** must live in **`android/gradle.properties`** (or env / **`-D`**), **not** only in **`local.properties`** — Gradle ignores it there. **`flutter config --jdk-dir=…`** aligns Flutter tooling with JDK 21.

---

## 1. Detection, thresholds, and inference UX

### 1.1 Thresholds and config

**Files:** **`lib/core/constants.dart`**, **`lib/core/config.dart`**

| Setting | Role |
|---------|------|
| **`detectionThreshold`** | Lowered toward **~0.14** (balanced / defaults) so borderline scores (e.g. high teens percent raw) can pass; **accuracy** preset uses a still-lower value for recall. |
| **`nmsThreshold`** | Tuned (e.g. **~0.48**) for dense same-class pests. |

**`AppConfig.balanced()`** / **`AppConfig.accuracy()`** expose explicit values aligned with **`AppConstants`** so dialogs that print **`thr=`** match the service (**`InferenceService.config`**).

### 1.2 Startup race (first inference vs prefs)

**Files:** **`lib/main.dart`**, **`lib/core/app_state.dart`**

- **`InferenceService`** is registered as a singleton before prefs load.
- **`AppState.loadPreferences()`** calls **`_applyInferenceConfigToService()`** when accuracy / dark / language prefs are read.
- **Change:** construct **`AppState`**, **`await loadPreferences()`**, then **`runApp(ChangeNotifierProvider.value(value: appState, …))`** so the first **`runInference`** does not run on default config while async prefs are still in flight.

### 1.3 Isolate-safe model loading

**File:** **`lib/services/inference_service.dart`**

- **`rootBundle.load`** + write **`best.tflite`** (or configured asset) under **`path_provider`** temp dir on the **main isolate**.
- **`Isolate.run`** uses **`Interpreter.fromFile(modelFilePath)`** so the worker isolate never touches **`rootBundle`** (fixes **binding / ServicesBinding** class of errors).

### 1.4 Scan progress UI (minimum dwell + linear bar)

**Files:** **`lib/widgets/inference_progress_dialog.dart`** (**`runInferenceWithProgressUi`**), **`lib/screens/permission_screens.dart`**

- Dialog enforces a **minimum visible duration** (order of **~5 s**) without a numeric countdown.
- **`LinearProgressIndicator`** (and optional “taking longer” copy) during inference.
- Gallery / camera / album flows call **`runInferenceWithProgressUi`** instead of a bare spinner where integrated.

### 1.5 “No detections” copy

**File:** **`lib/screens/permission_screens.dart`**

- **`_noDetectionsDetailMessage`** includes the **live** **`detectionThreshold`** from **`InferenceService.config`**, plus short domain / settings hints where applicable.

---

## 2. Retake → Add Photo flow

**File:** **`lib/screens/permission_screens.dart`** (**`PhotoResultScreen`**)

- **Before:** **`Navigator.pop(context)`** returned one route; after **`pushReplacement`** from **`PhotoSourcePicker`** or **`push`** from **`CameraModeSelector`**, users could land on the wrong screen (e.g. dashboard or camera-only scaffold).
- **After:** **`Navigator.pushAndRemoveUntil`** with a new **`PhotoSourcePicker(fieldName:, fieldId:)`** route and predicate **`(route) => route.isFirst`**, so the stack is cleared to the app root and **Add Photo** (Camera / Gallery chooser) is shown again with the same field context.

---

## 3. Navigation guide: when it shows

**Files:** **`lib/widgets/navigation_guide_host.dart`**, **`lib/core/navigation_guide_prefs.dart`**, **`lib/widgets/unlock_gate.dart`**, **`lib/screens/intro_flow_screen.dart`**

- **Issue:** **`NavigationGuideHost`** is a child of **`UnlockGate`**. When the gate swaps **`DeviceUnlockScreen`** → dashboard subtree, **`NavigationGuideHost`** can **mount again**; **`initState`** + **`shouldShowNavigationGuide()``** caused the tour to feel like it ran “every time” you returned to the main shell after unlock.
- **Mitigation:** static **`_presentedGuideThisProcess`** (or equivalent) so the spotlight runs **at most once per app process** when prefs still request it. (Users who enabled “show each session” in prefs may still want every **cold start**; same-process remounts are deduped.)

Related UX from the same period (spotlight overlay, **`navigation_guide_content.dart`**, **`spotlight_navigation_guide_overlay.dart`**): lighter dimmer, **`Scrollable.ensureVisible`**, silent **~5 s** sub-step timer, per-step body copy, Scan step “trial” framing, **`Icons.photo_camera`** on Scan where applicable.

---

## 4. Theme and dashboard polish

**Files:** **`lib/core/theme.dart`**, **`lib/screens/main_dashboard_screen.dart`**, **`lib/core/navigation_guide_content.dart`**

- Dark mode **primary green** brightened for readability; **`ColorScheme`** / app bar / FAB / elevated buttons aligned.
- Dashboard chart accent follows **`Theme.of(context).colorScheme.primary`**.
- Guide Scan slide / FAB uses **camera** icon (**`Icons.photo_camera`**) instead of a generic scanner icon where updated.

---

## 5. Lint: `BuildContext` across async gaps

**File:** **`lib/screens/permission_screens.dart`**

- After **`await picked.readAsBytes()`** / **`await file.readAsBytes()`**, insert **`if (!mounted) return;`** before **`context.read<AppState>()`** and **`runInferenceWithProgressUi(context: context, …)`**.
- Remove stale **`rootContext`** captures that still tripped **`use_build_context_synchronously`**.
- After **`await runInferenceWithProgressUi`**, **`if (!mounted) return;`** before assigning detection results.

---

## 6. Android: Java 21 and Gradle JDK

**Symptom:** **`error: invalid source release: 21`** on **`:app:compileDebugJavaWithJavac`**.

**Cause:** **`android/app/build.gradle.kts`** targets **Java 21**, but the **JDK running Gradle / javac** was older (e.g. 17).

**Mitigations applied (this machine):**

| Step | Detail |
|------|--------|
| **JDK install** | **`winget install Microsoft.OpenJDK.21`** → e.g. **`C:\Program Files\Microsoft\jdk-21.0.10.7-hotspot`**. |
| **`android/gradle.properties`** | **`org.gradle.java.home=C:/Program Files/Microsoft/jdk-21.0.10.7-hotspot`** — **required**; Gradle does **not** read **`org.gradle.java.home`** from **`local.properties`**. |
| **Flutter** | **`flutter config --jdk-dir="C:\Program Files\Microsoft\jdk-21.0.10.7-hotspot"`**. |
| **Daemon** | **`android\gradlew.bat --stop`** after changing JDK so the next build picks up the new JVM. |

**Optional duplicate:** **`android/local.properties`** may still list **`org.gradle.java.home`** for human documentation; **effective** setting for Gradle is **`gradle.properties`**.

**Other developers:** Install JDK 21, update **`org.gradle.java.home`**, or remove the line and set **`JAVA_HOME`**.

---

## 7. IDE / analysis environment

| Item | Path / action |
|------|----------------|
| **Flutter SDK** | **`.vscode/settings.json`** — **`dart.flutterSdkPath`** (e.g. **`D:/flutter/flutter`**) so **`package:flutter/...`** resolves in the analyzer. |
| **Dependencies** | **`flutter pub get`** at repo root. |

---

## 8. Key paths — 12–13 April 2026

| Area | Paths |
|------|--------|
| Inference + isolate | `lib/services/inference_service.dart` |
| Progress UI | `lib/widgets/inference_progress_dialog.dart` |
| Photo flow + retake + no-detection copy | `lib/screens/permission_screens.dart` |
| Constants + presets | `lib/core/constants.dart`, `lib/core/config.dart` |
| App bootstrap + prefs | `lib/main.dart`, `lib/core/app_state.dart` |
| Nav guide host + prefs + intro | `lib/widgets/navigation_guide_host.dart`, `lib/core/navigation_guide_prefs.dart`, `lib/screens/intro_flow_screen.dart`, `lib/widgets/unlock_gate.dart` |
| Theme + dashboard + guide copy | `lib/core/theme.dart`, `lib/screens/main_dashboard_screen.dart`, `lib/core/navigation_guide_content.dart`, `lib/widgets/spotlight_navigation_guide_overlay.dart` |
| Android JDK | `android/app/build.gradle.kts`, `android/gradle.properties`, `android/local.properties` (optional mirror) |
| Editor | `.vscode/settings.json` |

---

## 9. Command cheat sheet

```powershell
Set-Location D:\PINE
flutter pub get
flutter analyze
flutter run -d <deviceId> --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

After changing **JDK** or **`org.gradle.java.home`**:

```powershell
Set-Location D:\PINE\android
.\gradlew.bat --stop
```

---

## 10. Limitations and follow-ups

- **Navigation guide:** One-shot-per-process dedupe may interact with **“show each session”** prefs in edge cases (same process, multiple unlocks); confirm product intent if QA reports it.
- **`org.gradle.java.home` in repo:** **`android/gradle.properties`** now contains a **machine-specific** path; CI or other laptops must override or remove that line.
- **Secrets in shell history:** Prefer env files or local scripts not committed to git for **`SUPABASE_ANON_KEY`** in **`flutter run`** arguments.
- **Feedback form:** **`feedback_form_screen.dart`** may still carry a **TODO** for the published Apps Script URL (unchanged in this log’s scope).

---

*End of April 12–13 work log. Fold into **`docs/RECENT_WORK_LOG.md`** Part I date range when you consolidate.*
