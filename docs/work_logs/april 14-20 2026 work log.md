# Work log — 14–20 April 2026

Supplement to **`docs/RECENT_WORK_LOG.md`** and the single-day **`docs/work_logs/april 10 work log.md`**. This entry summarizes work captured in the **Cursor session** and **working tree** for **14–20 April 2026** (calendar window ending **Monday 20 April 2026**). **§9** captures **More-tab** placeholder wiring, disease list cleanup, **PineSight** theme, and **logo.png** splash + launcher. Reconcile exact commit dates with **`git log`** after you commit.

**Stack reminder:** **Supabase** with **`SUPABASE_URL`** and **`SUPABASE_ANON_KEY`** at compile time (`String.fromEnvironment` / `--dart-define` or **`--dart-define-from-file`**; prefer **`scripts/run_debug.ps1`** on Windows). Display name **PINYA-PIC**. ML defaults: **YOLO26n** + **`scripts/retrain_yolo.py`** (see **`RUN.md`**).

---

## Handoff for another agent

| Area | What to know |
|------|----------------|
| **Auth copy vs behavior** | Login/register are **email + password**. Forgot-password flow now calls **`resetPasswordForEmail`**; FAQ and profile strings were aligned so they no longer describe SMS-only auth. |
| **Feedback endpoint** | **`FeedbackFormScreen`** sends **POST + JSON** (`name`, `email`, `message`). A Google Apps Script backing the sheet must implement **`doPost`** and **`JSON.parse(e.postData.contents)`** — GET query submission was removed to avoid PII in URLs. |
| **Windows debug / Supabase** | **`scripts/run_debug.ps1`** writes a temp JSON file and passes **`--dart-define-from-file`** so long keys are not mangled by **`--dart-define=...`** through Gradle. The script validates a JWT **`ref`** vs `{ref}.supabase.co` (and supports newer `sb_publishable_...` keys). **Network probing** of `GET …/rest/v1/` is now **opt-in** (it can false-fail on valid keys); see `RUN.md` for `-TestSupabaseOnline` / `-StrictSupabaseProbe`. |
| **Agent bundle zip** | **`scripts/make_agent_bundle.ps1`** excludes Android **`.cxx`**, **`.kotlin`**, **`.idea`**, **`local.properties`**, crash logs, calibration **`.npy`**, Flutter **`flutter*.log`**, and discovers **`_bz_*`** staging leftovers **before** creating the new staging dir so logs stay clear. |
| **More tab / disease UX** | Placeholder images under **`assets/placeholder_pics/`** resolved by **title = filename stem** (see **`lib/core/more_tab_images.dart`** + **`AssetManifestCache`**). **Machete Disease** and **Pineapple Soft Rot** removed from More carousel and **`DiseaseInfoScreen`**; fruit-by-category list no longer links Black Rot / Soft Rot to the old detail factories. **Mealybug** content kept as **`DiseaseDetailScreen.mealybugWilt()`** (title *Mealybug Infestation*). |
| **Theme & branding** | **`lib/core/theme.dart`** remapped to PineSight-style palette (**`#76944C`**, **`#C8D886`**, **`#FBF5DB`**, **`#FFD21F`**, **`#C0B6AC`**, navy **`#2E3141`**) with Material 3 button/input/chip themes. Dashboard bottom nav: light bar + **olive circle** on selected tab. Splash uses **`assets/placeholder_pics/logo.png`**; Android launcher icons are generated via **`flutter_launcher_icons`** in **`pubspec.yaml`** and should use a padded transparent foreground (now **`assets/placeholder_pics/logo_foreground_fit.png`**) to avoid adaptive mask cropping. |

---

## 1. Repository / Flutter resolution

- **`.gitignore`:** Added **`!pubspec.lock`** so the app lockfile can be tracked (previously **`*.lock`** ignored it), improving reproducible **`flutter pub get`** after clone.
- **`pubspec.lock`:** Intended to be committed with the above change.
- **Analyzer “URI does not exist” mass errors:** Addressed by resolving packages (**`flutter pub get`**) and correct Flutter SDK selection; dependencies were already listed in **`pubspec.yaml`**.

---

## 2. Auth UX, FAQ, profile, and password reset

**Problem:** Help text and screens still described **SMS / no password** while the app used **email + password** (`signInWithPassword`, `signUp`).

**Changes (Dart):**

| File | Change |
|------|--------|
| **`lib/screens/forgot_password_screen.dart`** | Replaced static “SMS help” with **`resetPasswordForEmail`**, email field, loading/error handling. Introduced **`ForgotPasswordRouteArgs`** for optional prefill. |
| **`lib/main.dart`** | **`/forgot-password`** route reads **`ForgotPasswordRouteArgs`** and passes **`prefillEmail`**. |
| **`lib/screens/login_screen.dart`** | “Forgot password?” navigates with **`ForgotPasswordRouteArgs(email: …)`**. |
| **`lib/screens/faq_screen.dart`** | Sign-up and forgot-password answers updated for email/password and reset link flow. |
| **`lib/screens/profile_screen.dart`** | Footnote updated: email/password sign-in; optional phone for profile only. |

---

## 3. Feedback form (privacy + contract)

**File:** **`lib/screens/feedback_form_screen.dart`**

- Submissions use **`http.post`** with **`Content-Type: application/json`** and **`jsonEncode({ name, email, message })`** instead of **`http.get`** with query parameters.
- Comment updated: Apps Script should use **`doPost`** + JSON body (not GET query params).

---

## 4. `scripts/run_debug.ps1` (Supabase on Windows)

- **Problem:** **`Invalid API key`** when JWT was passed as long **`--dart-define=SUPABASE_ANON_KEY=…`** (shell/Gradle truncation or corruption).
- **Mitigation:** Write UTF-8 JSON under **`%TEMP%`** with **`SUPABASE_URL`** and **`SUPABASE_ANON_KEY`**, pass **`--dart-define-from-file=…`**, delete temp file in **`finally`**.
- **Validation:** Decode JWT payload (middle segment), compare **`ref`** to host **`{ref}.supabase.co`**; optional **`role`** warning if not **`anon`**.
- **Online probe (historical):** Early versions did a blocking probe to **`GET {SUPABASE_URL}/rest/v1/`** and exited on **401/403**. This was later changed to **opt-in** because some valid keys returned 401/403 depending on header mode and project settings.
- **Logging:** Gray line with host and anon key **length** (not the secret).

**Docs:** **`RUN.md`** updated to recommend **`run_debug.ps1`** / **`--dart-define-from-file`** on Windows for JWT-heavy defines.

---

## 5. `scripts/make_agent_bundle.ps1` (slim agent zip)

**Goal:** **`PINE-agent-bundle.zip`** should not include NDK caches, machine secrets, or huge ephemeral trees.

**Directory excludes added (robocopy `/XD`):**

- **`android\app\.cxx`**, **`android\app\.externalNativeBuild`**, **`android\.kotlin`**
- **`.idea`**

**File excludes (`/XF`):** **`local.properties`**, **`hs_err_pid*.log`**, **`replay_pid*.log`**, **`*.hprof`**, **`calibration_image_sample_data*.npy`**, **`flutter*.log`**

**Staging logic:** Enumerate existing **`_bz_*`** directories under the project **before** **`New-Item`** creates the new staging folder; after creating staging, add the **staging folder leaf name** to **`/XD`** so the empty staging directory is not copied into the archive. Avoids misleading “excluding leftover” lines for the brand-new **`_bz_…`** name.

**Observed result (example run):** ~**62 MB** archive, **~4.2k** items (vs much larger bundles that previously contained **`.cxx`** and **`windows\flutter\ephemeral`** plugin examples).

---

## 6. Advisory / documentation only (no code in this period)

Discussed in session but **not** implemented as repo changes here:

- **Geocoding APIs** catalog: which kinds help field GPS vs IP geolocation (latter not for capture tagging).
- **BLASTBufferQueue** Android log spam: graphics buffer queue noise; not app logic errors.
- **Navigation guide:** Runs **after** sign-in (and device unlock if enabled); **`SharedPreferences`** **`nav_guide_*`**; manual replay under **Settings → View app navigation guide**.
- **Model accuracy vs dataset size:** Guidance to swap **`assets/model/best.tflite`** and tune thresholds; training quality vs image count.
- **`PINE-agent-bundle.zip` inventory:** Described typical contents pre-slimming.

---

## 7. Files touched (checklist)

Use **`git status`** / **`git diff`** for the authoritative list. Expected highlights:

**Earlier in this window (§1–6):**

- **`.gitignore`**, **`pubspec.lock`** (if committed)
- **`lib/screens/forgot_password_screen.dart`**, **`lib/main.dart`**, **`lib/screens/login_screen.dart`**, **`lib/screens/faq_screen.dart`**, **`lib/screens/profile_screen.dart`**, **`lib/screens/feedback_form_screen.dart`**
- **`scripts/run_debug.ps1`**, **`scripts/make_agent_bundle.ps1`**
- **`RUN.md`**

**§9 (UI / theme / branding, ≈20 Apr):**

- **`lib/core/more_tab_images.dart`**, **`lib/core/theme.dart`**
- **`lib/screens/main_dashboard_screen.dart`**, **`lib/screens/splash_screen.dart`**, **`lib/screens/disease_detail_screen.dart`**, **`lib/screens/disease_info_screen.dart`**, **`lib/screens/disease_by_category_screen.dart`**
- **`pubspec.yaml`**, **`pubspec.lock`** (if **`flutter_launcher_icons`** committed)
- **`assets/placeholder_pics/`** (e.g. **`logo.png`**, More-tab images, **`README.txt`**)
- **`assets/branding/README.txt`**
- **`android/app/src/main/res/`** ( **`values/colors.xml`**, **`drawable/launch_background.xml`**, **`drawable-v21/launch_background.xml`**, **`mipmap-*`**, **`mipmap-anydpi-v26`** after icon generation)

- **`docs/work_logs/april 14-20 2026 work log.md`** (this file), **`docs/RECENT_WORK_LOG.md`**

---

## 8. Follow-ups (optional)

- **Supabase / Apps Script:** Deploy **`doPost`** handler for feedback if not already done.
- **Model versioning:** Name and document **`best.tflite`** variants (e.g. 1.5k vs 5k training) beside **`assets/model/`** or in the training repo.

---

## 9. More tab placeholders, disease cleanup, PineSight theme, logo & launcher (≈20 Apr 2026)

**More tab (`lib/screens/main_dashboard_screen.dart`):** **`FutureBuilder`** + **`AssetManifestCache.ensure`** (`lib/core/more_tab_images.dart`) loads **`AssetManifest.json`** once; **`moreTabImageForTitle`** picks **`assets/placeholder_pics/<title>.{png,jpg,jpeg,webp}`** when that key exists. **`_InfoCard`**, **`_DiseaseCard`**, **`_ExploreCard`** show optional top thumbnails. **Machete Disease** carousel tile removed.

**Disease screens:** **`lib/screens/disease_detail_screen.dart`** — removed **`machete()`** / **`softRot()`**; added **`mealybugWilt()`**; detail hero image uses same manifest resolver on **`title`**. **`lib/screens/disease_info_screen.dart`** — dropped Machete and Pineapple Soft Rot from **`_diseases`** and routing. **`lib/screens/disease_by_category_screen.dart`** — fruit category copy trimmed; only **Fruit Cracking** (no detail screen); removed Black Rot / Soft Rot rows; pests row uses **`mealybugWilt()`**.

**Theme (`lib/core/theme.dart`):** New constants (**`olive`**, **`paleLime`**, **`cream`**, **`accentYellow`**, **`taupe`**, **`navy`**), typography (**`textHeading`**, **`textBody`**, **`textSubtle`**); **`primaryGreen`** / **`secondaryGreen`** alias to palette for existing **`AppTheme.primaryGreen`** call sites; **`mainContentGradient`** and **`AppBackground`** updated; extension **`pineProfileCream`** / **`pineTextSubtle`**.

**Branding:** **`lib/screens/splash_screen.dart`** — **`Image.asset`** → **`assets/placeholder_pics/logo.png`** with CustomPaint fallback. **`pubspec.yaml`** — **`dev_dependencies`**: **`flutter_launcher_icons`**; icon `image_path` / adaptive foreground should point to **`assets/placeholder_pics/logo_foreground_fit.png`** (transparent + padded) to avoid Android adaptive icon cropping; regenerate icons after replacing the logo. **`android/.../values/colors.xml`** — **`splash_background`**, **`ic_launcher_background`**; **`drawable` / `drawable-v21` / `launch_background.xml`** — cream + centered **`@mipmap/ic_launcher`**.

**Regenerate launcher after logo change:** `dart run flutter_launcher_icons` from repo root.
