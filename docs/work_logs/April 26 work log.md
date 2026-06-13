# Work log — 26 April 2026

Supplement to **`docs/RECENT_WORK_LOG.md`**. Summarizes work from the **Cursor session** around **YOLO26 / mealybug retrain**, **TFLite export and app integration**, **Windows release builds**, and **Android NDK repair**. Reconcile exact commit dates with **`git log`** after you commit.

**Stack reminder:** **Supabase** with compile-time **`SUPABASE_URL`** / **`SUPABASE_ANON_KEY`** (prefer **`--dart-define-from-file`** via **`scripts/run_debug.ps1`** or **`scripts/build_release_auto_version.ps1`** on Windows; see **`RUN.md`**). On-device model: **Ultralytics YOLO26** exported to **TFLite** (we ship **float32-input** when needed for device compatibility; float16-input can fail on some phones). Training entrypoint **`scripts/retrain_yolo.py`**.

---

## Handoff for another agent

| Area | What to know |
|------|----------------|
| **TFLite copy bug** | **`scripts/retrain_yolo.py`** previously copied **`best_saved_model/best_float16.tflite`** into **`weights/best_float16.tflite`** only when the destination was missing, so **`weights/`** could stay **stale** (e.g. wrong FlatBuffer shape) while the nested export was correct. **Fix:** when the nested file exists, **always** **`shutil.copy2`** into **`weights/`**. |
| **ONNX slimming** | **`onnxslim`** was installed in the training venv so export runs can slim ONNX before conversion (check export logs for onnxslim). |
| **`inspect_tflite.py`** | Emits a **stderr warning** when subgraph output looks non-YOLO but tensors suggest a **TopK-style** path (e.g. mentions **`300`**). |
| **Release build script** | **`scripts/build_release_auto_version.ps1`**: **PowerShell parse** issues addressed (avoid Unicode **em dash** in script strings; APK path **`Write-Host`** uses **`('…' -f (Join-Path …))`**). After **`flutter build apk`** / **`flutter build appbundle`**, the script now checks **`$LASTEXITCODE`** and **throws** on failure so it does not print **“Build complete”** or APK/AAB paths after a failed Gradle step. |
| **Android NDK `CXX1101`** | Error: **`NDK at …\ndk\28.2.13676358 did not have a source.properties file`** (malformed or partial NDK). **Remediation:** delete that **`ndk\28.2.13676358`** directory (or reinstall **NDK (Side by side)** in Android Studio SDK Manager), then rebuild so AGP/SDK manager can fetch a clean tree. |
| **Flutter on Windows** | **Symlink support:** “Building with plugins requires symlink support” → enable **Developer Mode** (Windows Settings → For developers). **Execution policy:** run scripts with **`RemoteSigned`** (CurrentUser) or **`Bypass`** for one-off runs. |
| **Model I/O sanity** | Export-side **ONNX** **`output0`** shape observed as **`[1, 300, 6]`** for the mealybug head; ship the exported **`.tflite`** to **`assets/model/best.tflite`** after verifying shapes match app expectations (**float32 I/O**). |
| **Secrets** | Avoid pasting **Supabase anon JWT** into shell history; prefer **env vars** or **define-from-file** only on the build machine; rotate if a key was logged in a shared terminal. |

---

## 1. Training pipeline and TFLite export

- **`scripts/retrain_yolo.py`:** Fixed **`weights/best_float16.tflite`** mirroring so successful exports under **`…/weights/best_saved_model/`** always refresh the top-level **`weights/`** copy.
- **Export chain:** Continued use of **ONNX → SavedModel → TFLite** with **`onnxslim`** available in the venv where applicable.
- **`scripts/inspect_tflite.py`:** Warning path for ambiguous outputs aligned with **TopK / 300** detection vocabulary.

---

## 2. Release automation and Android build

- **`scripts/build_release_auto_version.ps1`:** Windows-safe quoting and comments; **exit-code checks** after **`flutter`** so failures surface clearly.
- **Gradle / NDK:** Resolved **`[CXX1101]`** by removing the broken NDK folder under **`%LOCALAPPDATA%\Android\sdk\ndk\28.2.13676358`** so the next build can re-download a valid NDK.
- **Note:** If **`assembleRelease`** failed after **`-Major`** (or similar), **`pubspec.yaml`** may already show a higher **version** / **versionCode**; confirm intent before tagging or shipping.

---

## 3. App asset and verification

- **Bundled model:** Copy verified **`best_float32.tflite`** (or `best_float16.tflite` if your device supports it) to **`assets/model/best.tflite`** after export validation (shape **`[1, 300, 6]`** output consistent with the YOLO26 app parser).

### App UX / presentation updates (results)

- **Detections list UX:** Results screen now defaults to **top 5** detections (by confidence), with a tap-to-expand **“Show all / Collapse”** header and a “+N more detections” hint when applicable.
- **Live sensitivity control:** Added a **Detection sensitivity** slider on the results screen (and settings), triggering **re-analysis** and updating overlays/lists live.
- **Removed toggle:** The coarse **“Detection accuracy mode”** toggle was removed from settings in favor of the sensitivity slider.

---

## 4. Follow-ups (optional)

- Rerun **`scripts/build_release_auto_version.ps1`** (or **`flutter build apk --release`**) after NDK repair; confirm **`pubspec`** version matches release intent.
- Resume or finish **GPU training** scripts (e.g. chunked **50 → 100** epochs) if a longer run was interrupted; align **`classLabels`** / **`data.yaml`** with shipped TFLite.
- **`docs/RECENT_WORK_LOG.md`:** Add a one-line pointer to this file under supplements if you maintain that index.
