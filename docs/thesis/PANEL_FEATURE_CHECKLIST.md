# Panel Feature & Thesis Checklist

**Project:** PINYA-PIC Mealybug Detection Collector & Decision-Support Middleware  
**Created:** June 12, 2026  
**Last updated:** June 13, 2026  

Use this file to track defense prep, app features, and thesis updates. Mark items `[x]` when done.

**Legend**

| Symbol | Meaning |
|--------|---------|
| `[ ]` | Not started |
| `[~]` | In progress |
| `[x]` | Done |
| **P0** | Do before panel / highest impact |
| **P1** | Important for defense story |
| **P2** | Stretch / post-defense |

---

## Quick status summary

| Area | Done | In progress | Not started |
|------|------|-------------|-------------|
| Core detection & sync | — | — | — |
| Visualization (map / heatmap) | — | — | — |
| DA / OMAG mediation | — | — | — |
| Analytics dashboard | — | — | — |
| Communication (chat / AI) | — | — | — |
| Model honesty & metrics docs | — | — | — |
| Thesis & APA 7 formatting | — | — | — |

*Update the table counts as you check items below.*

---

## A. Positioning & messaging (thesis + defense)

| # | Task | Priority | Status | Notes / file |
|---|------|----------|--------|--------------|
| A1 | Reframe system as **detection collector + decision-support middleware** (not standalone diagnostic) | P0 | [x] | `DETECTION_COLLECTOR_MIDDLEWARE.md` |
| A2 | State clearly: **model is NOT deployment-ready** | P0 | [x] | `PANEL_STATUS_REPORT_2026-06-11.md` |
| A3 | Define **positive detection** in thesis: confirmed tier ≥ 0.25, mealybug only | P0 | [x] | `detection_report_status.dart` |
| A4 | Define **negative detection**: logged in table, excluded from map/analytics | P0 | [x] | Map filter implemented |
| A5 | Explain **why v16** remains shipped model (v20–v22 did not beat it) | P0 | [ ] | `MODEL_PERFORMANCE_ALL_VERSIONS.md` |
| A6 | One-paragraph **panel positioning statement** finalized | P0 | [ ] | Chapter I / abstract |
| A7 | Add **limitations** section: recall, mAP@0.5:0.95, resolution mismatch, label noise | P0 | [ ] | Chapter IV–V |
| A8 | Literature: **justify recall priority** in pest scouting | P1 | [ ] | `LITERATURE_mAP_70_78_BAND.md` |
| A9 | Recommend **expert consultation** (DA/OMAG) before treatment | P0 | [ ] | Chapter V recommendations |
| A10 | Include **new features** in recommendations chapter | P1 | [ ] | Collector, analytics, DA feedback |

---

## B. Detection logic & farmer flow

| # | Task | Priority | Status | Notes / file |
|---|------|----------|--------|--------------|
| B1 | On-device inference (YOLO26 TFLite v16) | P0 | [x] | `inference_service.dart` |
| B2 | Two-tier UI: confirmed (≥0.25) + manual-check (0.12–0.24) | P0 | [x] | `detection_tiers.dart` |
| B3 | Only **mealybugs** detected (single class) | P0 | [x] | Model + labels |
| B4 | Geotag on save (GPS / EXIF / manual) | P0 | [x] | `geo_service.dart` |
| B5 | **Auto-submit report** per upload (sync to Supabase) | P0 | [x] | `detection_service.dart`, `cloud_sync_service.dart` |
| B6 | Set `has_mealybugs` from confirmed count (`count > 0`) | P0 | [x] | `detection_service.dart` |
| B7 | Safe advisory copy (“possible” / “verify visually”) | P0 | [x] | `detection_advisory_messages.dart` |
| B8 | Farmer UX unchanged (scan → result → save) | P0 | [x] | `scan_flow.dart` |
| B9 | Allow duplicate reports per farm (per-upload logging) | P0 | [x] | By design — one row per scan |
| B10 | Negative uploads visible in **history / table** | P0 | [x] | All uploads in lists; map positive-only |

---

## C. Map & data visualization

| # | Task | Priority | Status | Notes / file |
|---|------|----------|--------|--------------|
| C1 | **Map shows positive detections only** (`has_mealybugs == true`) | P0 | [x] | `detections_map_screen.dart` |
| C2 | **Heatmap when zoomed out** (no per-image pins) | P0 | [x] | Field heatmap zoom < 15 |
| C3 | **Pins when zoomed in** (individual positive sightings) | P0 | [x] | `detections_map_screen.dart` |
| C4 | Mobile heatmap grid toggle (“Grid”) | P1 | [x] | `_buildHeatmapGrid()` |
| C5 | Admin map: positive-only filter | P0 | [x] | `admin/app.js` |
| C6 | Admin map: heatmap layer (Leaflet.heat or grid) | P1 | [x] | Field fill heatmap |
| C7 | Admin map: zoom-based heatmap vs pins | P1 | [x] | Match mobile behavior |
| C8 | Field geofence boundaries on map | P0 | [x] | Mobile + admin |
| C9 | Geotagging visible in report detail (lat/lng, field name) | P1 | [x] | Capture detail screens |
| C10 | Table/list: show **all** uploads (positive + negative) | P0 | [x] | `captured_photos_screen.dart`, admin Reports |

---

## D. DA / OMAG super user & mediation

| # | Task | Priority | Status | Notes / file |
|---|------|----------|--------|--------------|
| D1 | Admin JWT role (`app_metadata.admin = true`) | P0 | [x] | `admin_session.dart`, RLS migrations |
| D2 | PineSight Admin: view all users, fields, captures | P0 | [x] | `admin/` |
| D3 | Mobile admin: “Admin • all farms” mode | P1 | [x] | `main_dashboard_screen.dart` |
| D4 | Separate **Farmer / DA / Admin** roles + DA approval workflow | P1 | [x] | `da` vs `admin` JWT; `da_access_requests`; approve on web **Users** or mobile **More** |
| D5 | DA **report queue**: positive detections pending review | P1 | [x] | Pending reply filter |
| D6 | DA **strategy / remedy input** per detection | P0 | [x] | `expert_responses` + admin/mobile |
| D7 | Farmer sees **DA feedback** on capture detail | P1 | [x] | `captured_photo_detail_screen.dart` |
| D8 | DA **universal insights** per farm or region | P1 | [x] | Fields drawer → DA farm insight |
| D9 | Formal **PDF/CSV report** export for DA/OMAG | P2 | [ ] | Not built; SQL export exists |
| D10 | Detection **verification workflow** (confirm/reject) | P2 | [ ] | Optional enhancement |

---

## E. Analytics dashboard (DA super user)

| # | Task | Priority | Status | Notes / file |
|---|------|----------|--------|--------------|
| E1 | Total **positive reports** (7d / 30d / all time) | P0 | [x] | Analytics drawer |
| E2 | Total negative reports (separate stat) | P1 | [x] | Analytics drawer |
| E3 | **Top farms** by mealybug sighting count | P0 | [x] | Analytics drawer |
| E4 | Farm owner name + field info on analytics | P1 | [x] | Join `profiles`, `fields` |
| E5 | **Daily / weekly trend** chart (positive count) | P0 | [x] | Chart.js 7-day bar |
| E6 | **Infestation rate** by field (farmer dashboard) | P1 | [x] | `dashboard_stats_service.dart` |
| E7 | Org-wide infestation / outbreak **heatmap** | P0 | [x] | Admin map field heatmap |
| E8 | Time-based filters (date range) | P1 | [ ] | Admin captures panel |
| E9 | Export analytics CSV from admin UI | P2 | [ ] | Manual SQL only today |

---

## M. Admin web UI/UX redesign

| # | Task | Priority | Status | Notes / file |
|---|------|----------|--------|--------------|
| M1 | Chart catalog mapped to admin data (Data-to-Viz) | P1 | [x] | `ADMIN_UI_REDESIGN.md` |
| M2 | Donut: positive vs negative proportion | P1 | [x] | Analytics drawer |
| M3 | Line: 30-day positive trend | P1 | [x] | Analytics drawer |
| M4 | Horizontal bar: top farms | P1 | [x] | Analytics drawer |
| M5 | Dashboard home (KPI + chart grid, not drawer-only) | P1 | [ ] | Phase 2 |
| M6 | Date range filter on analytics (7d/30d/90d) | P1 | [ ] | Phase 2 |
| M7 | Treemap or stacked bar: field share of positives | P2 | [ ] | Phase 2 |
| M8 | Bubble map layer on Leaflet | P2 | [ ] | Phase 2 |
| M9 | Full visual system refresh (tokens, motion, empty states) | P1 | [ ] | Phase 3 |
| M10 | Netlify deploy after admin UI changes | P0 | [~] | `ADMIN_WEB_DEPLOY.md` |

---

## F. Communication & expert advice

| # | Task | Priority | Status | Notes / file |
|---|------|----------|--------|--------------|
| F1 | Static post-scan **insights** (severity-based) | P1 | [x] | `insight_catalog.dart` |
| F2 | Email feedback link | P2 | [x] | `feedback_screen.dart` |
| F3 | Google Form feedback | P2 | [x] | `feedback_form_screen.dart` |
| F4 | **DA notes / expert advice** on positive captures | P0 | [x] | Web Reports + mobile admin |
| F5 | In-app **chat** farmer ↔ DA | P2 | [ ] | No `messages` table |
| F6 | **AI chat** (RAG on advisories + DA insights) | P2 | [ ] | Label as assistive only |
| F7 | Push notifications for DA response | P2 | [ ] | `notifications_screen.dart` is placeholder |

---

## G. Model performance & honesty (documentation)

| # | Task | Priority | Status | Notes / file |
|---|------|----------|--------|--------------|
| G1 | Locked corrected test metrics table (v16–v22) | P0 | [x] | `MODEL_PERFORMANCE_ALL_VERSIONS.md` |
| G2 | Panel targets vs actual (≥85% mAP, ≥80% recall) | P0 | [x] | `PANEL_STATUS_REPORT_2026-06-11.md` |
| G3 | Confusion cases (TP / FP / FN examples) | P0 | [x] | `CONFUSION_CASES_V16.md` |
| G4 | Explain **why low recall** (dataset, labels, small objects) | P0 | [ ] | Chapter IV discussion |
| G5 | Operational P/R at deploy conf **0.25** re-reported | P1 | [ ] | Threshold sweep artifact |
| G6 | Expert field validation @ 0.25 | P2 | [ ] | v13afix @ 0.30 only |
| G7 | Do **not** claim deployability in app store / thesis abstract | P0 | [ ] | Wording audit |
| G8 | v20–v22 revision cycle documented (effort + no gain) | P0 | [x] | Panel status report |

---

## H. Thesis & APA 7 formatting

| # | Task | Priority | Status | Notes / file |
|---|------|----------|--------|--------------|
| H1 | APA 7 reference list (author-date, DOI) | P0 | [ ] | Sample in `EXPLANATION_FOR_SIR_JUDE_MODEL_METRICS.md` |
| H2 | **Figure captions** APA 7 (*Figure X.* + title) | P0 | [ ] | All thesis figures |
| H3 | **Table captions** APA 7 (*Table X.* above table) | P0 | [ ] | `THESIS_FIGURES_TABLES_ERRATA.md` |
| H4 | Timestamps: **Month Day, Year** (e.g. June 12, 2026) | P0 | [ ] | Tables, logs, captions |
| H5 | Separate **legacy vs corrected** metric labels in tables | P0 | [ ] | Avoid conflating eval protocols |
| H6 | System architecture diagram updated (middleware framing) | P1 | [ ] | `SYSTEM_ARCHITECTURE.md` |
| H7 | Panel response letter / revision draft finalized | P0 | [ ] | `PANEL_REVISION_RESPONSE_DRAFT.md` |
| H8 | Chapter IV updated with v20–v22 results | P0 | [ ] | `THESIS_UPDATE_SEARCH_GUIDE.md` |
| H9 | Chapter V recommendations include collector + DA features | P1 | [ ] | New section |
| H10 | Table numbering matches school chapter convention | P1 | [ ] | Cross-check list of tables |

---

## I. Panel guidance — original 8 items

| # | Panel item | Status | Evidence |
|---|------------|--------|----------|
| I1 | Improve recall (78–85%) | [ ] Not met | v16 recall 64.7%; document effort |
| I2 | Hard-case images (≥2,500 new) | [ ] Not done | 510 batch planned only |
| I3 | Annotation quality audit | [x] Done | DINO, consensus, v22 selffix |
| I4 | Field-realistic augmentation | [~] Partial | On v20–v22; shipped v16 predates |
| I5 | Higher training imgsz (800–1280) | [x] Done | All revision models @ 1280 |
| I6 | Compare YOLO26 n/s/m | [~] Partial | s + m done; n standalone not |
| I7 | Confusion cases (TP/FP/FN) | [x] Done | `CONFUSION_CASES_V16.md` |
| I8 | Advisory safeguards | [x] Done | App v17.0.0 |

---

## J. Suggested build order (for developers)

Work top to bottom; each step unlocks the next for the defense narrative.

1. [ ] **C1** — Map: positive-only filter (mobile)
2. [ ] **C2 + C3** — Zoom-based heatmap vs pins (mobile)
3. [ ] **C5 + C6** — Same rules on PineSight Admin
4. [ ] **E1 + E3 + E5 + E7** — Admin analytics dashboard
5. [ ] **D6 + D7** — DA strategy input + farmer sees feedback
6. [ ] **A1–A10, G4, H1–H10** — Thesis + defense docs in parallel
7. [ ] **F5 / F6** — Chat / AI (if time permits)

---

## K. Definition reference (do not change without panel alignment)

| Term | Definition |
|------|------------|
| **Positive detection** | Mealybug present AND model confirmed at confidence ≥ **0.25** |
| **Manual-check** | Confidence 0.12–0.24 — overlay hint only, **not counted** |
| **Negative detection** | Zero confirmed mealybugs (`count == 0`, `has_mealybugs == false`) |
| **Map / heatmap / outbreak analytics** | **Positive only** |
| **Tables / history / audit log** | **All uploads** (positive + negative) |
| **Middleware** | PINYA-PIC collects, filters, and routes sightings — does not replace DA/OMAG diagnosis |

---

## L. Key file paths

| Purpose | Path |
|---------|------|
| Panel status | `docs/thesis/PANEL_STATUS_REPORT_2026-06-11.md` |
| Model metrics | `docs/training/MODEL_PERFORMANCE_ALL_VERSIONS.md` |
| Thesis update guide | `docs/thesis/THESIS_UPDATE_SEARCH_GUIDE.md` |
| System architecture | `docs/thesis/SYSTEM_ARCHITECTURE.md` |
| Mobile map | `lib/screens/detections_map_screen.dart` |
| Admin console | `admin/app.js`, `admin/index.html` |
| Admin UI redesign plan | `docs/thesis/ADMIN_UI_REDESIGN.md` |
| Detection save / sync | `lib/services/detection_service.dart` |
| Detection tiers | `lib/utils/detection_tiers.dart` |
| Advisory messages | `lib/data/detection_advisory_messages.dart` |

---

## Change log

| Date | Change |
|------|--------|
| 2026-06-12 | Initial checklist from panel feedback (Ma'am Jan, Sir Jude) |
