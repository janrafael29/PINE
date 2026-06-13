# Work log — 9 May 2026

Supplement to **`docs/RECENT_WORK_LOG.md`**. This entry covers **detection map** behavior (zoom-scaled markers, field filter + fence/pin fitting, **`boundary_json` fallback**), **declared dependencies for Esri tile disk caching**, **captured-photos bulk select/assign** with **date-grouped lists** and **optional menu copy**, **dashboard field photo counts** merged with local captures, **sync/backfill and linking** fixes for uploads, **welcome / onboarding** (pill **Log in** CTA, terms copy, wrapping legal line), **forgot / reset password** (scroll + keyboard padding, readable **Auth** errors), **Farm Details** field preview from **gallery** as well as camera, **Profile** screen **editable email** via **`auth.updateUser`**, static analysis notes, and **Supabase RLS / schema** for the admin console.

**Stack reminder:** Flutter (Android). Supabase compile-time defines via `scripts/run_debug.ps1`. Maps use `flutter_map` 6.x. Esri imagery uses `CachedTileProvider` + `FileCacheStore` (`lib/core/esri_map_tile_cache.dart`, `lib/widgets/esri_imagery_tile_layer.dart`).

---

## 1) Detections Map: pin size follows zoom

**Goal:** Hex/pulse markers stay **readable when zoomed out** but **shrink when zoomed in** so nearby captures separate on screen and are easier to count.

**Implementation:**
- Track live zoom (`_mapLiveZoom`) from `MapOptions.onPositionChanged` (small threshold to limit rebuilds).
- Sync on first frame with `onMapReady` → `_mapController.camera.zoom` so initial size matches `initialZoom` (field vs all-detections branches differ).
- Pin pixel size from `_pinPixelSizeForZoom` (clamped); marker hit box from `_markerHitBoxForPinSize` for taps.

**File:**
- `lib/screens/detections_map_screen.dart`

**Related (same screen, same day):** Choosing a **field** in the map filter refreshes lands, fits the camera to **fence + visible pins** (with extra padding where needed), and when the polygon is missing locally, **`_tryFetchAndCacheBoundaryForSelectedField`** loads **`fields.boundary_json`** from Supabase once and caches it for fit and display.

---

## 2) Dependencies: map tile cache stack in `pubspec.yaml`

**Packages added** (also pulled transitives such as `dio`, `http_cache_core`, `dio_web_adapter`):
- `flutter_map_cache`
- `http_cache_file_store`
- `dio_cache_interceptor`

**Note:** App code already wires **`CachedTileProvider`** and **`FileCacheStore`** for Esri tiles; this step **declares** the versions in **`pubspec.yaml`** / lockfile so `dart pub get` resolves cleanly on fresh checkouts.

**Verification:**
- `dart pub get` — success
- `dart analyze lib` — success; **info-level** hints remain (see §11)

---

## 3) Supabase: admin JWT policies and field boundaries

**Migrations** (timestamps in filenames: `20250509…`):
- **`20250509100000_admin_jwt_select_policies.sql`** — RLS `select` on `profiles` and `fields` when JWT `app_metadata.admin` is true (dashboard admins).
- **`20250509200000_fields_boundary_and_admin_geo_updates.sql`** — `fields.boundary_json` (`jsonb`); admin `update` on `fields`; admin `select` / `update` on `detections` for boundary and coordinate corrections.

**Related:** Admin static site expects `window.PINE_ADMIN_CONFIG` in **`admin/config.js`** (see **`admin/config.example.js`**). Shared parsing for stored rings: **`DatabaseService.parseFieldsBoundaryJson`** (used by map and field flows).

---

## 4) Cloud sync and local DB: linking captures, grouped counts, upload backfill

**Goals:** Remote rows that match a device capture by **`local_image_path`** should **attach to the signed-in user**; pending upload queues should reflect captures that were never queued; field-level **photo counts** should include captures tied to a field even when **`user_id`** was still null on the row.

**Implementation (high level):**
- **`linkCapturedPhotoToRemoteUpload`** — match on **`local_image_path`** and **`(user_id IS NULL OR user_id = ?)`**, then set **`user_id`**.
- **`backfillPendingUploadsForUnsyncedCaptures`** — called from **`CloudSyncService`** before sync / pending counts so “nothing to sync” false negatives are reduced.
- **`countCapturedPhotosGroupedByFieldId`** (and related field capture queries) — treat **`user_id IS NULL OR user_id = ?`** consistently so stats match what the UI shows after assign.

**Files:**
- `lib/services/database_service.dart`
- `lib/services/cloud_sync_service.dart`

---

## 5) Dashboard: “Photos captured” merges Supabase fields with local counts

**Problem:** After assigning captures locally, grid cards could still show **0** if counts came only from cached remote field docs.

**Fix:** **`_mergeFieldDocsWithLocalCaptureCounts`** merges **`field_cache` / stream** documents with **`countCapturedPhotosGroupedByFieldId`** so displayed counts include **local `captured_photo`** rows. Listeners (e.g. **`capturedPhotosRevision`**) keep the fields grid / horizontal list in sync when captures change.

**File:**
- `lib/screens/main_dashboard_screen.dart`

---

## 6) Captured Pictures: bulk select, assign, date headers, optional Select… wording

**UX:** **Selection mode** with a **Select…** bottom sheet: **all visible** vs **only rows** still using the generic **Field** / empty label (**`_isUnassignedFieldLabel`**). **Assign to field** for the current selection. List built with **`_buildCaptureListRows`** / **`_CaptureListRow`** — section headers (**Today**, **Yesterday**, **Tomorrow**, or a full date) from capture **`created_at`**.

**Custom copy:** Optional English/Filipino title + subtitle for the “generic Field rows” option live in **`lib/core/captured_photos_select_labels.dart`**; **`captured_photos_screen.dart`** uses non-empty trimmed overrides via **`_capturedSelectUnassignedTitle`** / **`_capturedSelectUnassignedSubtitle`**, otherwise keeps the built-in strings.

**File:**
- `lib/screens/captured_photos_screen.dart`
- `lib/core/captured_photos_select_labels.dart`

---

## 7) Welcome screen: Log in pill, terms wording, legal text layout

**Goals:** Match **Get Started** with a clear secondary control for **Log in**; align consent copy with real actions; avoid horizontal **overflow** on narrow devices.

**Implementation:**
- **Already have an account? Log in** — **`OutlinedButton`**: same full-width pill geometry as **`FilledButton`** (height ~50, radius 25), **white** border + **white** label on the gradient (secondary vs solid primary).
- Consent line — **“By tapping next…”** replaced with **“By signing in or logging in, you are agreeing to…”**.
- **Terms / Privacy** — two **`Row`**s replaced with **`LayoutBuilder`** + **`Wrap`** (`WrapAlignment.center`, `runSpacing`) so long lines break instead of **RIGHT OVERFLOWED**.

**File:**
- `lib/screens/welcome_screen.dart`

---

## 8) Forgot / reset password: scroll, keyboard, SnackBar auth messages

**Problems:** **Forgot password** body used **`Column` + `Spacer`**, which **overflowed** when the keyboard was open or the viewport was short (**BOTTOM OVERFLOWED**). **`AuthException.message`** sometimes arrived as **JSON** (e.g. `unexpected_failure` / recovery email), which the app showed raw in a **SnackBar**.

**Implementation:**
- **`ForgotPasswordScreen`** — **`SingleChildScrollView`** with **`padding` bottom** including **`MediaQuery.viewInsetsOf(context).bottom`**; **`keyboardDismissBehavior: onDrag`**; removed **`Spacer`**, fixed gap before **Back to sign in**.
- **`authErrorMessageForUser(AuthException)`** in **`lib/core/auth_display_message.dart`** — parses JSON **`message`** when present; maps **recovery-email** failures to short guidance (SMTP / redirect URLs). Used from **`forgot_password_screen.dart`** and **`reset_password_screen.dart`**.

**Files:**
- `lib/screens/forgot_password_screen.dart`
- `lib/screens/reset_password_screen.dart`
- `lib/core/auth_display_message.dart`

**Ops note:** Reliable delivery still depends on **Supabase Authentication → Emails (e.g. custom SMTP)** and **allowed redirect URLs** (app uses **`pine://reset-password`** for **`resetPasswordForEmail`**).

---

## 9) Farm Details: field preview from gallery

**Goal:** When **adding a field** (**Farm Details**), users can set the preview image from the **gallery** as well as the **camera** (parity with **Edit Field**).

**Implementation:** **`_pickFieldPreview(ImageSource)`** centralizes **`ImagePicker.pickImage`** (quality **80**). Second **`OutlinedButton.icon`** — **`Icons.photo_library_outlined`**, labels **Pick from gallery** / **Pumili mula sa gallery**.

**File:**
- `lib/screens/farm_details_screen.dart`

---

## 10) Profile: user can change email

**Goal:** **Email** on the profile card is editable; updates **Supabase Auth** and **`profiles.email`**.

**Implementation:** Remove **`readOnly`** on the email **`TextField`**; validate trimmed address. On **Update**, if the value differs from **`currentUser.email`**, call **`auth.updateUser(UserAttributes(email: …))`**, then **`profiles` upsert** with **`display_name`**, **`email`**, **`phone`**. **`AuthException`** → **`authErrorMessageForUser`**. SnackBar notes **email confirmation** when the project requires it (dashboard **Auth** settings).

**File:**
- `lib/screens/profile_screen.dart`

---

## 11) Static analysis (informational)

`dart analyze lib` reported **no errors**; remaining **info** items (optional cleanup) may include:
- `lib/screens/captured_photos_screen.dart` — `use_build_context_synchronously` (guarded with **`mounted` / `context.mounted`** where updated)
- `lib/screens/permission_screens.dart` — same lint; `unnecessary_string_escapes` (two)

---

*End of work log — 9 May 2026 (updated same day: welcome + password-reset UX; later pass: farm preview gallery + profile email).*
