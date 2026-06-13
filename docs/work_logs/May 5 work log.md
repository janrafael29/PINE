# Work log — 5 May 2026

Supplement to **`docs/RECENT_WORK_LOG.md`**. This entry captures the **May 5, 2026** work focused on **auth screen keyboard UX** and a **camera capture quality** tweak to improve real-device detection reliability (especially on older phones).

**Stack reminder:** Flutter (Android). Supabase compile-time defines passed via `scripts/run_debug.ps1`. On-device detection is YOLO→TFLite shipped as `assets/model/best.tflite`.

---

## 1) Login + Register: keyboard-safe layout and dismissal

Problem observed:
- When typing, the **keyboard partially covered** the lower input fields (especially password).
- Tapping outside the inputs did **not consistently dismiss** the keyboard (register screen).

Fixes:
- **Keyboard-safe scroll padding**:
  - Added bottom padding using `MediaQuery.viewInsets.bottom` so the scroll view accounts for the keyboard height.
  - Reduced some top spacing when keyboard is open so the form sits higher.
  - Added `scrollPadding` to text fields so focused fields remain visible.
- **Dismiss keyboard when tapping outside**:
  - Wrapped screen bodies in a `GestureDetector` that unfocuses the current field on tap.
  - Enabled dismiss-on-drag via `ScrollViewKeyboardDismissBehavior.onDrag`.
  - Register screen was adjusted to ensure the gesture area covers the full screen (not just the scroll content height).

Files:
- `lib/screens/login_screen.dart`
- `lib/screens/register_screen.dart`

---

## 2) Camera capture tweak: maximize clarity for tiny pests

Observation:
- Detection was **accurate on clear still photos**, but frequently missed during “camera capture” flow on-device.

Likely cause:
- Captured images were being saved with **compression** (`imageQuality: 85`), which can soften tiny details.

Fix:
- Updated the camera capture path to prefer **rear camera** and **maximum JPEG quality**:
  - `preferredCameraDevice: CameraDevice.rear`
  - `imageQuality: 100`

File:
- `lib/screens/permission_screens.dart`

Notes:
- This app’s “Camera” flow uses `image_picker` (system camera UI), not a real-time frame stream. Improving capture quality is the lowest-risk way to improve small-object recall without changing model code.

---

## 3) Verification

- `flutter analyze` → **No issues found**

---

*End of work log — 5 May 2026.*

