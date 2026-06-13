# PINYA-PIC — App Implementation Report

**Date:** June 12, 2026  
**Scope:** Panel revision sprint — detection collector / DA mediation features  
**Related:** [`REVISIONS_LIST_2026-06-12.md`](REVISIONS_LIST_2026-06-12.md) · [`PANEL_FEATURE_CHECKLIST.md`](PANEL_FEATURE_CHECKLIST.md)

---

## Executive summary

Following panel feedback (Ma'am Jan, Sir Jude, researchers Morillo / Morga / Bacay), PINYA-PIC was updated from a farmer-only diagnostic tool into a **mealybug detection collector and assistive middleware** that:

1. **Auto-reports** every farmer upload to Supabase (one row per scan).
2. **Separates positive vs negative** detections — only positives appear on maps and analytics.
3. **Replaces pin-only maps** with **zoom-aware field heatmaps** (zoomed out) and individual pins (zoomed in).
4. Gives **DA/OMAG superusers** a consolidated **Reports** view, **Analytics** dashboard, and **strategy/remedy input** that flows back to farmers.
5. **Leaves the ML model unchanged** (YOLO26s v16 TFLite) — no retraining in this sprint.

**Surfaces updated:** Flutter mobile app, PineSight Admin web console, Supabase schema (2 new tables).

**Model:** Not retrained. Shipped model remains `mealybug_v16_selffix` @ confidence threshold 0.25.

---

## System flow (after changes)

```
Farmer uploads image
    → On-device YOLO26 TFLite inference
    → Result saved locally + synced to Supabase `detections`
    → If positive (count > 0): appears on map heatmap + DA analytics
    → If negative: visible in history / Reports table only
    → DA/OMAG reviews Reports (web or mobile admin)
    → DA saves strategy/remedy → `expert_responses`
    → Farmer reads "Expert advice from DA/OMAG" on capture detail
```

---

## 1. Mobile app (Flutter)

### 1.1 Positive detection rule (Ma'am Jan)

**New utility:** `lib/utils/detection_report_status.dart`

| Function | Purpose |
|----------|---------|
| `detectionRowIsPositive()` | Supabase row: `has_mealybugs == true` or `count > 0` |
| `capturedPhotoRowIsPositive()` | Local SQLite row: `count > 0` |
| `detectionStatusLabel()` / `capturedPhotoStatusLabel()` | User-facing **Positive** / **Negative** (English or Filipino) |

This is the single source of truth for the positive-detection rule across map, lists, and badges.

### 1.2 Map & heatmap (`lib/screens/detections_map_screen.dart`)

| Behavior | Detail |
|----------|--------|
| **Positive-only map** | Stream filtered with `.where(detectionRowIsPositive)` before rendering |
| **Zoom threshold** | `_pinZoomThreshold = 15.0` |
| **Zoomed out (< 15)** | Field-level heatmap tint (positive sightings aggregated per field) |
| **Zoomed in (≥ 15)** | Individual positive detection pins |
| **Negative scans** | Excluded from map; empty-state copy notes they remain in history |
| **Geofences** | Field boundaries still shown regardless of detection count |
| **Grid toggle** | Optional heatmap grid layer retained |

Admin users see org-wide positive points; farmers see their own fields (existing JWT scoping unchanged).

### 1.3 Status badges in lists

**`lib/widgets/capture_activity_card.dart`**

- Each capture card shows a **Positive** (red) or **Negative** (green) chip alongside confirmed count, confidence %, and time.
- Filipino labels: *Positibo* / *Negatibo* when app language is set accordingly.

### 1.4 DA expert feedback — mobile (`lib/screens/captured_photo_detail_screen.dart`)

**New service:** `lib/services/expert_feedback_service.dart`

| Role | UI |
|------|-----|
| **Farmer** | Read-only card: **Expert advice from DA/OMAG** (strategy text + optional action type) |
| **Admin (JWT `admin: true`)** | Reply form on **positive** captures only: textarea + action dropdown (monitor / treat / rescan / other) + Save |

Uses Supabase `expert_responses` with upsert on `detection_id`.

### 1.5 Farmer flow — intentionally unchanged

| Item | Status |
|------|--------|
| Scan → choose field → analyze → save | Unchanged |
| Per-upload auto-sync to cloud | Unchanged (existing `detection_service.dart` + `cloud_sync_service.dart`) |
| Duplicate uploads per farm | Allowed — one `detections` row per scan |
| Safe advisory copy | Unchanged — "possible mealybug", verify visually |
| Geotagging (GPS / EXIF / manual) | Unchanged |
| Offline-first save + upload queue | Unchanged |

### 1.6 Admin mode on mobile

Existing **Admin • all farms** mode (`lib/core/admin_session.dart`, `main_dashboard_screen.dart`) continues to work for JWT admins — org-wide detections, map, and DA reply on capture detail.

---

## 2. PineSight Admin (web)

**Files:** `admin/index.html`, `admin/app.js`, `admin/styles.css`

### 2.1 Navigation & naming

| Before | After |
|--------|-------|
| Captures drawer (informal) | **Reports** sidebar button |
| — | New **Analytics** sidebar button |

### 2.2 Positive / negative helpers (`admin/app.js`)

Mirrors mobile logic:

- `detectionIsPositive(d)` — same rule as `detectionRowIsPositive`
- `positiveDetections(list)` — filter helper
- `positiveCountByFieldId()` — field aggregation for heatmap
- `detectionStatusBadgeHtml(d)` — HTML badge for table rows

### 2.3 Reports drawer (formerly captures list)

| Feature | Detail |
|---------|--------|
| **All uploads shown** | Positive and negative rows in table |
| **Status column** | Positive / Negative badges |
| **Filters** | All · Positive only · **Pending reply** (positive, no DA advice yet) |
| **Columns** | Status, date, field/farmer, count, image, map link, **DA advice** |
| **DA advice inline** | Textarea + Save per positive row → `expert_responses` |
| **Copy** | "Positive sightings feed the outbreak map; negatives stay in this table only." |

### 2.4 Analytics drawer (new)

| Metric / widget | Detail |
|-----------------|--------|
| Total positive reports | All-time count |
| Total negative scans | Separate stat |
| Positive (7 days) | Rolling window |
| Positive (30 days) | Rolling window |
| **7-day trend chart** | Chart.js bar chart (positive reports per day) |
| **Top farms table** | Field name, owner, positive count, last sighting, **View on map** button |

Analytics counts use **positive detections only** for map-related stats; negative count is reported separately for transparency.

### 2.5 Map (admin)

| Behavior | Detail |
|----------|--------|
| `MAP_PIN_ZOOM_THRESHOLD = 15` | Same as mobile |
| Zoomed out | Field fill heatmap colored by positive sighting density (`heatRgbForSeverity`) |
| Zoomed in | Positive detection pins only |
| Sidebar scope label | Shows positive vs total counts where applicable |

Negative detections never render as map markers.

### 2.6 Fields drawer — DA farm insight (new)

| Feature | Detail |
|---------|--------|
| **DA farm insight** section | Select field → textarea → Save |
| Storage | Supabase `farm_insights` (latest insight per field loaded on field change) |
| Farmer visibility | RLS allows farmers to read own-field insights, but **mobile UI not built yet** — admin note says "future app update" |

### 2.7 Styles (`admin/styles.css`)

New CSS classes:

- `.pine-badge`, `.pine-badge--positive`, `.pine-badge--negative`
- `.pine-analytics-grid`, `.pine-analytics-stat`
- Capture filter row styling

---

## 3. Backend / Supabase

### 3.1 New migration

**File:** `supabase/migrations/20260612100000_expert_feedback.sql`  
**Applied:** Live project `https://sjdcnkendlgqbxxjdqml.supabase.co`

#### Table: `expert_responses`

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid | PK |
| `detection_id` | uuid | FK → `detections`, **unique** (one reply per report) |
| `author_id` | uuid | FK → auth.users (DA admin) |
| `strategy_text` | text | Required — treatment / monitoring advice |
| `action_type` | text | Optional — monitor, treat, rescan, etc. |
| `created_at` / `updated_at` | timestamptz | Audit |

#### Table: `farm_insights`

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid | PK |
| `field_id` | uuid | FK → `fields` |
| `author_id` | uuid | DA admin |
| `insight_text` | text | Farm-level guidance |
| `created_at` | timestamptz | Audit |

#### Row Level Security (RLS)

| Policy | Who |
|--------|-----|
| Farmers **SELECT** `expert_responses` | Own detections only |
| Farmers **SELECT** `farm_insights` | Own fields only |
| JWT **staff** (`da` or `admin`) | Insert/update own `expert_responses` |
| JWT **full admin** (`admin: true`) | Full CRUD on `expert_responses`, `farm_insights` |

### 3.2 Role separation & DA approval (June 12–13, 2026)

**Migrations:**

| File | Purpose |
|------|---------|
| `20260612120000_da_staff_jwt_role.sql` | `jwt_is_da_staff()`, `jwt_is_staff()`; DA read policies; staff expert write |
| `20260612140000_da_access_requests.sql` | `da_access_requests` table + RLS |

**Edge function:** `pine-admin-review-da-request` — full admin approves/rejects; approve sets `app_metadata.da: true`.

**Three roles:**

| Role | JWT | Mobile | PineSight Admin web |
|------|-----|--------|---------------------|
| Farmer | none | Own fields | Not authorized |
| DA / OMAG | `da: true` | DA • all farms, Farmer reports | PineSight DA — Reports, Analytics, read-only map |
| Full admin | `admin: true` | Admin • all farms | Users, Fields, bulk tools + all DA views |

**Approval workflow:**

1. Farmer registers → **More → DA / OMAG access → Request DA access**
2. Full admin → **Users** drawer (web) **or** **More → DA access requests** (mobile) → **Approve DA**
3. User signs out/in → DA JWT active

**App files:** `lib/core/admin_session.dart`, `lib/widgets/da_access_request_card.dart`, `lib/widgets/da_access_request_admin_card.dart`, `admin/app.js` role gating.

### 3.3 Existing tables — no schema change

`detections`, `fields`, `profiles` — unchanged. Positive/negative distinction uses existing `has_mealybugs` and `count` columns set at save time.

### 3.4 Test accounts

Documented in [`DA_SUPERUSER_SETUP.md`](DA_SUPERUSER_SETUP.md):

| Role | Email | JWT |
|------|-------|-----|
| Full admin | `morgajanrafael1793@gmail.com` | `admin: true` |
| DA (after approval) | `rgist45@gmail.com` | `da: true` (after approve) |
| Farmer test | `morillo3580225@gmail.com` | none |

**Important:** Sign out and sign in after role changes so JWT refreshes.

---

## 4. What was NOT changed

| Area | Reason |
|------|--------|
| **ML model / TFLite weights** | Panel: leave model as-is; justify in thesis |
| **Inference pipeline** | v16 @ conf 0.25, two-tier UI (confirmed + manual-check) |
| **Farmer onboarding / scan UX** | Panel: farmer side stays as-is |
| **Chat / AI / push notifications** | Deferred to Phase 2 |
| **PDF/CSV export** | Deferred — manual SQL export still available |
| **Separate Farmer / DA / Admin roles** | Implemented June 12–13 — JWT + approval workflow |
| **External OMAG-POL reporting integration** | No external system found; PineSight Admin is the authority tool |

---

## 5. Known gaps (Phase 2)

| Gap | Impact |
|-----|--------|
| Farmer mobile UI for `farm_insights` | DA can save farm-level advice; farmer cannot read it in app yet |
| Formal end-to-end device test sign-off | Accounts configured; live walkthrough pending |
| Date-range filters on Reports / Analytics | All-time + 7d/30d stats only |
| PDF/CSV report export from admin UI | Manual export only |
| In-app chat farmer ↔ DA | Not built |
| Push notification when DA replies | Placeholder screen only |

---

## 6. OMAG-POL existing reporting system

**Finding:** No dedicated OMAG-POL reporting API or module exists in this codebase. PineSight Admin serves as the consolidated reporting surface for DA/OMAG. If a formal provincial platform is adopted later, integration is a **future recommendation** — not implemented in this sprint.

---

## 7. How to test (15-minute walkthrough)

See [`DA_SUPERUSER_SETUP.md`](DA_SUPERUSER_SETUP.md).

1. **Farmer** (`morillo3580225@gmail.com`): scan on field **Angelei** → save (try one positive and one negative if possible).
2. **DA web** (`morgajanrafael1793@gmail.com`): PineSight Admin → **Reports** → confirm both uploads appear; only positive on map.
3. **DA web:** **Pending reply** filter → enter advice on positive capture → Save.
4. **Farmer mobile:** Open same capture → **Expert advice from DA/OMAG** card visible.
5. **DA web:** **Analytics** → verify counts, 7-day chart, top farms.
6. **Map:** Zoom out → field heatmap; zoom in → positive pins only.
7. **DA web:** **Fields** → **DA farm insight** → save note for a field.

---

## 8. Files created or modified

### New files

| Path | Purpose |
|------|---------|
| `lib/utils/detection_report_status.dart` | Positive/negative helpers |
| `lib/services/expert_feedback_service.dart` | DA reply CRUD |
| `supabase/migrations/20260612100000_expert_feedback.sql` | DB schema + RLS |

### Modified — mobile

| Path | Change |
|------|--------|
| `lib/screens/detections_map_screen.dart` | Positive filter, zoom heatmap vs pins |
| `lib/screens/captured_photo_detail_screen.dart` | Expert advice display + admin reply form |
| `lib/widgets/capture_activity_card.dart` | Positive/Negative badges |

### Modified — admin web

| Path | Change |
|------|--------|
| `admin/index.html` | Reports + Analytics nav buttons |
| `admin/app.js` | Positive helpers, Reports filters, Analytics drawer, map heatmap, farm insights, expert_responses load/save |
| `admin/styles.css` | Badges, analytics grid |

### Documentation (supporting, not app code)

| Path | Purpose |
|------|---------|
| `docs/thesis/DETECTION_COLLECTOR_MIDDLEWARE.md` | Middleware framing |
| `docs/thesis/DA_SUPERUSER_SETUP.md` | Account setup + test flow |
| `docs/thesis/THESIS_PASTE_BLOCKS.md` | Thesis text blocks (paper not updated yet) |
| `docs/thesis/REVISIONS_LIST_2026-06-12.md` | Panel revisions progress tracker |
| `docs/thesis/SYSTEM_ARCHITECTURE.md` | Updated architecture narrative |

---

## 9. Definitions (panel-aligned)

| Term | Definition in app |
|------|-------------------|
| **Positive detection** | Mealybug confirmed at confidence ≥ **0.25** (`count > 0`, `has_mealybugs == true`) |
| **Negative detection** | Zero confirmed mealybugs |
| **Map / heatmap / analytics** | **Positive only** |
| **History / Reports table** | **All uploads** (positive + negative) |
| **Middleware** | Collects and routes sightings — does not replace DA/OMAG diagnosis |

---

## 10. Summary table

| Panel requirement | Implementation | Surface |
|-------------------|----------------|---------|
| Detection collector / auto-report | Per-upload Supabase sync | Mobile |
| Positive-only visualization | Map + analytics filter | Mobile + Admin |
| Heatmap zoomed out, pins zoomed in | Threshold 15 | Mobile + Admin |
| DA sees all farmers' reports | JWT admin + Reports drawer | Admin web + mobile admin |
| Analytics (totals, trends, top farms) | Analytics drawer + Chart.js | Admin web |
| DA strategy/remedy input | `expert_responses` | Admin web + mobile admin |
| Farmer feedback loop | Expert advice card | Mobile |
| Farm owner info on reports | Field + profile join | Admin Reports + Analytics |
| Farmer UX unchanged | No scan flow changes | Mobile |
| Model left as-is | v16 TFLite, no retrain | — |

**Overall app checkpoint:** Core panel features implemented (~90%). Remaining work is mostly Phase 2 polish (farmer farm-insights UI, exports, date filters) and thesis documentation.
