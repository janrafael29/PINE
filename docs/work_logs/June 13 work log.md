# Work log — 13 June 2026

Supplement to **`docs/RECENT_WORK_LOG.md`**. This entry covers **farmer Diagnose chart fixes**, **mobile/web farmer-reports parity**, **field-grouped DA review UI**, and **multi-user performance** (Realtime patches, lazy field loading, stale-while-revalidate badges).

**Stack reminder:** Flutter (Android), Supabase (Auth / Postgres / Storage / Realtime), PineSight Admin web (Netlify static deploy).

**Related thesis docs:** [`docs/thesis/PANEL_APP_PROGRESS_REPORT_2026-06-13.md`](../thesis/PANEL_APP_PROGRESS_REPORT_2026-06-13.md)

---

## 1) Farmer Diagnose — “Total pests count” chart fixes

**Problems reported:**
- Y-axis labels were **inverted** (0 at top, max at bottom) while the line used correct math — badge and grid disagreed.
- Chart did **not refresh** after a new scan (Relied on Supabase stream; ignored local SQLite captures).
- Line looked **jagged** with an odd dip between days (raw Catmull-Rom overshoot).

**Fixes:**
- **`_RealLineChartPainter`:** Y-axis labels now use `yValue = rangeY * t` (0 at bottom, max at top).
- **`_DiagnoseTab`:** Watches `AppState.capturedPhotosRevision`; `FutureBuilder` keyed on revision reloads local stats after each save.
- **Offline-first stats:** `DashboardStatsCalculator.farmerWeeklyStats()` prefers local `captured_photo` rows when the farmer has data this week; falls back to remote `detections` only when local is empty.
- **Smooth line:** Replaced hand-rolled cubic segments with **`buildMonotonicSmoothLinePath`** / **`buildMonotonicSmoothAreaPath`** from `lib/utils/smooth_line_chart_path.dart`.

**Files:**
- `lib/screens/main_dashboard_screen.dart`
- `lib/services/dashboard_stats_service.dart`
- `lib/utils/smooth_line_chart_path.dart` (reused)

---

## 2) Mobile vs web — pending farmer reports count mismatch (268 vs 784)

**Cause:** Mobile `AdminReportsService` used **`limit: 300`** on the detections query; web admin uses **`DETECTIONS_LIMIT = 2500`** in `admin/app.js`. Mobile only counted pending replies among the 300 most recent rows.

**Fixes:**
- Added **`kAdminReportsDetectionLimit = 2500`** (matches web).
- Applied to `fetchReports`, `countPendingReplyReports`, and `fetchPositiveReports`.
- **Batched** `expert_responses` lookups in chunks of 150 to avoid PostgREST `in` filter size limits.

**Files:**
- `lib/services/admin_reports_service.dart`
- `lib/services/staff_nav_badges_service.dart` (badge count uses same service)

---

## 3) Farmer reports — grouped by field (mobile + web)

**Request:** Instead of a flat list of every capture, show **fields first**, then **expand a field** to review images and write DA/OMAG advice — easier when hundreds of reports are pending.

**Mobile (`AdminReportsScreen`):**
- Added **`AdminReportFieldGroup`** and **`groupAdminReportsByField()`** in `admin_reports_service.dart`.
- Top summary: **Fields · Captures · Pending**.
- Collapsible **`PineCard`** per field; nested capture tiles inside; tap capture → existing detail + advice flow.
- Fields sorted by pending count, then latest capture date.

**Web (Reports drawer):**
- **`groupDetectionsByField()`** + **`buildReportFieldGroupHtml()`** accordion.
- Summary stats: **Fields · Captures · Positive · Pending reply** (replaces old “Showing” label).
- Click field header to expand/collapse; advice forms remain per capture inside.

**Deploy:** Production Netlify deploy completed earlier in the session (`celadon-mochi-48bf70.netlify.app`). Re-deploy after §4 changes if not yet pushed from this machine.

**Files:**
- `lib/screens/admin_reports_screen.dart`
- `lib/services/admin_reports_service.dart`
- `admin/app.js`
- `admin/styles.css`

---

## 4) Multi-user performance — Tier 1 algorithms

**Goal:** Smoother concurrent use when multiple farmers scan and multiple DA staff review on mobile + web (less full-reload lag).

### Web admin

| Change | Behavior |
|--------|----------|
| **Debounced Realtime patches** | Subscribe to `detections` + `expert_responses`; merge into in-memory cache; UI refresh debounced **400 ms** (`scheduleDashboardUiRefresh`). |
| **Lazy field loading** | Reports drawer renders field headers from cache; **captures fetch on first expand** per field (`loadFieldDetectionsForGroup`, limit 200); “Loading captures…” state. |
| **Save advice** | Still patches `cacheExpertResponses` + `renderDrawer()` — no full `loadDashboard()` on each save. |

**Files:** `admin/app.js`, `admin/styles.css` (`.pine-report-field-loading`)

### Mobile

| Change | Behavior |
|--------|----------|
| **Stale-while-revalidate badges** | `StaffNavBadgesService` caches last snapshot; dashboard shows cached counts immediately, then refreshes from network. |

**Files:** `lib/services/staff_nav_badges_service.dart`, `lib/screens/main_dashboard_screen.dart`

### Database

- Migration **`20260613180000_enable_realtime_expert_responses.sql`** — adds `expert_responses` to `supabase_realtime` publication so web admins see each other’s advice saves live.

---

## 5) UI polish (same sprint — reference)

Earlier in the 12–13 June UI pass (documented in thesis progress report):

- **`PineCard`**, **`AppScaffold`**, branded bottom sheets, pill bottom nav, dark-mode white text.
- Staff **`StaffAnalyticsPanel`** responsive charts; field history Filipino strings + smooth chart.
- AppScaffold migration on permission/scan, disease, feedback, farm details, onboarding screens.

See **`docs/thesis/PANEL_APP_PROGRESS_REPORT_2026-06-13.md`** for panel-facing summary.

---

## 6) Three-role UI verification (snapshot)

| Role | Home | Diagnose / Reports | Notes |
|------|------|-------------------|--------|
| **Farmer** | Stats + saved images | Diagnose tab + pest chart (**fixed §1**) | Local-first weekly stats |
| **DA staff** | Staff dashboard tiles | `StaffAnalyticsPanel` + **Farmer reports** (field groups §3) | Pending badge aligned with web §2 |
| **Full admin** | + DA access requests | Same as DA + all-report filters | Web Reports drawer grouped §3 |

**Secondary screens** still on legacy flat-green `AppBar` (optional follow-up): field selection, assign field, profile, location selector, navigation guide.

---

## 7) How to verify

**Mobile (debug device):**
```powershell
.\scripts\run_debug.ps1 -Device <id> -SupabaseUrl "..." -SupabaseAnonKey "..."
```
Hot restart **`R`** after Dart changes.

| Check | Steps |
|-------|--------|
| Pest chart | Farmer → Diagnose → scan → chart updates; Y-axis 0 at bottom; smooth line |
| Pending count | DA login → Home “Farmer reports” should match web **Pending reply** (~784 band) |
| Field groups | DA → Farmer reports → collapsed fields → expand → captures list |
| SWR badges | Staff home badge appears instantly; updates after background refresh |

**Web admin:**
```powershell
.\scripts\deploy_admin_web.ps1 -Target netlify -Prod
```
Hard refresh (**Ctrl+Shift+R**) → Reports drawer → field accordion + lazy load on expand; two browser tabs should sync advice within ~1 s (Realtime §4).

---

## 8) Static analysis

**Verified:** `dart analyze` clean on touched Dart paths (`main_dashboard_screen.dart`, `admin_reports_service.dart`, `dashboard_stats_service.dart`, `staff_nav_badges_service.dart`).

---

## 9) Follow-ups

**Done (June 13–14):**
- Netlify production deploy — live at https://celadon-mochi-48bf70.netlify.app (single-session web admin, field-grouped reports, Realtime patches). Deploy script handles Netlify credit-limit fallback (draft → `restoreSiteDeploy`).
- Smoke test + video demo + revisions list to Sir Khil — team sign-off (manual checklist in `SMOKE_TEST_2026-06-13.md`).
- Thesis paste — middleware framing, limitations, objectives, Ch IV–V largely applied in Word (see panel compliance review in chat); optional polish: Figure 4, 640→1280 wording, UAT reframe (`THESIS_UAT_REFRAME_PASTE.md`), APA 7 captions.

**Optional (post-defense):**
- **Expand all / Collapse all** on field groups; mobile lazy per-field fetch.
- Migrate remaining secondary screens to `AppScaffold`.

---

*End of work log — 13 June 2026 (§9 updated 14 June 2026).*
