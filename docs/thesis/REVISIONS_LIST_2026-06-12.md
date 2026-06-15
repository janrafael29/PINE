# REVISIONS LIST

**AS OF JUNE 12, 2026 — PROGRESS REPRESENTATION**  
**App implementation updated:** June 13, 2026

**Project:** PINYA-PIC  
**Accounts (live test):** DA `morgajanrafael1793@gmail.com` (admin) · Farmer `morillo3580225@gmail.com`  
**Supabase:** `expert_responses` + `farm_insights` migration applied  

**Legend:** ✅ Done · 🟡 Partial · ⬜ Not started · 📄 Paper only · 📱 App only

---

## I. System Reframing

| Revision description | Page # (in paper) | Progress |
|---------------------|-------------------|----------|
| Reframe app as **assistive middleware / detection collector**: Farmer upload → detect → auto-report → consolidate for DA/OMAG → DA/OMAG strategies → feedback to farmers | Ch I, Abstract | ✅ **Pasted in Word** (June 13–14) · optional polish: UAT reframe (`THESIS_UAT_REFRAME_PASTE.md`), Figure 4, 640→1280 |
| Flow implemented in software (not only documentation) | Ch III | ✅ **App + Supabase** — per-upload `detections` row, DA superuser, `expert_responses` reply loop |
| Check: does DA/OMAG-POL already have an existing reporting system to plug into? | Ch III / Limitations | ✅ **Researched** — No dedicated OMAG-POL reporting API/module in codebase. **PineSight Admin** + mobile admin mode **is** the authority-facing reporting surface. Manual SQL export exists for statisticians. Recommend **integration as future work** if DA adopts a formal platform later. |

---

## II. App Features

### Farmer side (keep as-is)

| Revision description | Page # | Progress |
|---------------------|--------|----------|
| Role and UX stays the same | User manual / Ch III | ✅ Unchanged scan → result → save flow |
| **Per-upload reporting** — auto-report immediately after detection | Ch III | ✅ `detection_service.dart` + `cloud_sync_service.dart` |
| Duplicates OK (own farm) | Ch III | ✅ One `detections` row per upload by design |

### DA / OMAG super user (new features)

| Revision description | Page # | Progress |
|---------------------|--------|----------|
| **Analytics dashboard** — farms with most sightings, totals, trends | Ch III / Fig. | ✅ PineSight Admin → **Analytics** drawer (positive/negative counts, 7d/30d, top farms, Chart.js trend) |
| **Farm and owner information** per submission | Ch III | ✅ Reports table: field name + farmer profile; Analytics: owner column |
| **Strategy/remedy input** — DA/OMAG per detection or farm | Ch III | ✅ Per detection: web **Reports** + mobile admin reply → `expert_responses`. 🟡 Per farm: web **Fields** → **DA farm insight** → `farm_insights` (DA can save; **farmer cannot read on mobile yet**) |
| **Expert feedback loop** on consolidated captures | Ch III | ✅ Farmer sees **Expert advice from DA/OMAG** on capture detail (`captured_photo_detail_screen.dart`) |
| View **all accredited farmers' reports** | Ch III | ✅ JWT roles: **`admin`** (full) + **`da`** (staff) · web PineSight Admin + mobile staff mode |
| **DA access approval** — farmer/staff register, admin approves | Ch III | ✅ `da_access_requests` · Register role picker · Approve on web **Users** or mobile |
| **Staff mobile UX** — no camera; review-only | Ch III | ✅ Center nav = DA requests (admin) or Farmer reports (DA) · red badges |
| **Mobile analytics** (Diagnose tab for staff) | Ch III / Fig. | ✅ Donut, line trend (7D/1M/1Y), top-5 bar + table · mirrors web Analytics |
| **Pending reply** queue (positive, no DA answer yet) | Ch III | ✅ Reports filter: **Pending reply** |
| Pilot / live test with real accounts | Ch III / Ch IV | ✅ **Signed off** — smoke test + video demo (June 13–14); see `SMOKE_TEST_2026-06-13.md` |

---

## III. Data Visualization

| Revision description | Page # | Progress |
|---------------------|--------|----------|
| Map → **heatmap** (zoom-aware) | Ch III / Fig. | ✅ Mobile + admin: zoom **&lt; 18** (mobile) / **&lt; 15** (web) = field heatmap; zoomed in = positive pins |
| Zoomed out: **field-level heatmap only** (no per-image pins) | Fig. | ✅ Implemented |
| Zoomed in: drill down to individual detections | Fig. | ✅ Positive pins only |
| **Geotagging** on reports | Ch III | ✅ GPS/EXIF/manual; visible on capture detail |
| **Totals** (positive/negative, trends) | Ch III / Fig. | ✅ Analytics drawer |
| **Positive detection rule** (Ma'am Jan): mealybugs actually detected | Ch III | ✅ Confirmed tier ≥ 0.25; `has_mealybugs` / count &gt; 0 |
| Zero-mealybug → **excluded from map/visualization** | Ch III | ✅ `detectionRowIsPositive` filter on maps/analytics |
| Zero-mealybug → **still in table/report log** | Ch III | ✅ History + admin Reports show all; Positive/Negative badges |
| Visualization **limited to positive only** | Ch III | ✅ |

---

## IV. Reporting System

| Revision description | Page # | Progress |
|---------------------|--------|----------|
| Reports **auto-submit** to authorized recipient (DA/OMAG) | Ch III | ✅ Cloud sync on save → `detections` |
| Super user sees **consolidated view** across all farmers | Ch III | ✅ PineSight Admin + mobile admin |
| Reports basis for **DA/OMAG mitigation strategies** returned to farmers | Ch III | ✅ `expert_responses` workflow |
| Formal **PDF/CSV** report export for DA | Ch III / Reco | ⬜ Not built (manual SQL export only) — **Phase 2** |
| Plug-in to external OMAG-POL system | Ch V Reco | ⬜ No external system found — recommend future integration |

---

## V. Model (Leave As-Is, But Justify)

| Revision description | Page # | Progress |
|---------------------|--------|----------|
| **Do not retrain** or rebuild model for this revision cycle | Ch IV | ✅ No model work in June 12 app sprint; v16 remains shipped |
| **Explain why** model is designed as it is (YOLO26s v16) | Ch IV | 🟡 Documented in repo (`MODEL_PERFORMANCE_ALL_VERSIONS.md`, middleware doc) · ⬜ **Not in Word thesis yet** |
| **Do not claim** deployment-ready | Abstract, Ch V | 🟡 App advisory safe · ⬜ **Thesis wording audit pending** |
| Openly discuss **low metrics**; honest improvement possible | Ch IV Discussion | 🟡 `PANEL_STATUS_REPORT_2026-06-11.md` · ⬜ **Paper** |
| Literature: **justify recall** priority | Ch II / IV | 🟡 `LITERATURE_mAP_70_78_BAND.md` · ⬜ **Paper** |
| Better annotation / validation → **recommendations**, not rework | Ch V | 🟡 Paste block ready · ⬜ **Paper** |

---

## VI. Documentation Updates

| Revision description | Page # | Progress |
|---------------------|--------|----------|
| Update **objectives** to match middleware / detection collector scope | Ch I | ⬜ **Paper** — paste from `THESIS_PASTE_BLOCKS.md` |
| **APA 7th** on figures and tables (not only references) | All chapters | ⬜ **Paper** — guide: `APA7_THESIS_FORMATTING.md` |
| Indicate **pilot testing** of the app (Genamae note) | Ch III / IV | ⬜ **Paper** — 🟡 App ready to pilot; write-up not done |
| System architecture updated | Ch III | 🟡 `SYSTEM_ARCHITECTURE.md` updated · ⬜ thesis diagram/section |

---

## VII. Chapter IV: Results and Discussion

| Revision description | Page # | Progress |
|---------------------|--------|----------|
| Results from **expert testing** (DA/OMAG) | Ch IV | 🟡 Infrastructure ready (DA reply, analytics) · ⬜ **Formal expert test session + write-up** |
| **Insights contributed by DA** | Ch IV | 🟡 DA can save per-capture advice + farm insight in admin · ⬜ **Documented insights in thesis** |
| Honest **model performance**, limitations, improvement areas | Ch IV | 🟡 Metrics in repo (v16 73.3% / 64.7% recall vs targets) · ⬜ **Paper** |
| v20–v22 revision cycle results (did not beat v16) | Ch IV | 🟡 `PANEL_STATUS_REPORT_2026-06-11.md` · ⬜ **Paper** |

---

## VIII. Chapter V: Recommendations

| Revision description | Page # | Progress |
|---------------------|--------|----------|
| Recommend **ongoing consultation** with domain experts | Ch V | ⬜ **Paper** — block in `THESIS_PASTE_BLOCKS.md` |
| Recommend **new features** as future work (analytics, strategy input, heatmap, etc.) | Ch V | 🟡 Features **built**; ⬜ **listed in thesis recommendations** |
| Recommend **better annotation** pipelines and stronger validation | Ch V | ⬜ **Paper** |
| Recommend **model improvements** grounded in recall literature | Ch V | ⬜ **Paper** |
| Recommend **OMAG-POL integration** if formal reporting platform emerges | Ch V | ⬜ **Paper** |

---

## Quick Action Checklist

| Action | Type | Progress |
|--------|------|----------|
| Reframe documentation around detection collector / assistive middleware | 📄 | 🟡 Repo docs ✅ · Word thesis ⬜ |
| Update objectives | 📄 | ⬜ |
| Add **pilot testing** section | 📄 | ⬜ (app ready; write after device test) |
| Add DA super-admin features (analytics, strategy input, farm rankings, owner info) | 📱 | ✅ |
| Convert map to **zoom-aware heatmap** | 📱 | ✅ |
| Filter visualization to **positive only** (zero → table only) | 📱 | ✅ |
| **Auto-submit** report after each detection (per-upload, duplicates OK) | 📱 | ✅ |
| Add DA **strategy-input** + **feedback loop** to farmers | 📱 | ✅ |
| Rewrite **model justification** (not deployment-ready, low metrics honest) | 📄 | ⬜ |
| Apply **APA 7th** to all figures | 📄 | ⬜ |
| Expand **recommendations** (features + expert consultation + model directions) | 📄 | ⬜ |
| Check if DA/OMAG-POL has existing reporting system to integrate | 📄/📱 | ✅ Researched — use PineSight Admin; external integration = future reco |

---

## Panel notes mapping (Morillo / Morga / Bacay)

| Source | Item | App | Paper |
|--------|------|-----|-------|
| Ma'am Jan 1–2 | Map positive mealybug instances; DA sees all reports | ✅ | ⬜ |
| Ma'am Jan 5–6 | OMAG strategies; super user analytics + owner info | ✅ | ⬜ |
| Ma'am Jan 7–8 | Zero ≠ positive on map; positive-only viz | ✅ | ⬜ |
| Ma'am Jan 9 | Discuss low metrics | — | ⬜ |
| Ma'am Jan 10–12 | Super user DA features; geotag + totals | ✅ | ⬜ |
| Ma'am Jan 13 | DA contributes insights | 🟡 | ⬜ |
| Ma'am Jan 14 | Farmer as-is | ✅ | — |
| Ma'am Jan 15–16 | Recall literature; APA 7 figures | — | ⬜ |
| Ma'am Jan 17–19 | Auto-submit; per upload; expert advice | ✅ | ⬜ |
| Ma'am Jan 20–22 | Expert testing; insights; consultation reco | 🟡 | ⬜ |
| Sir Jude | Detection collector + mediation loop | ✅ | ⬜ |
| Sir Jude | Analytics/report to authorities; remedies to farmers | ✅ | ⬜ |
| Sir Jude | Better annotation/validation → recommendations | — | ⬜ |
| Morga | Middleware, collector, don't claim deploy-ready | 🟡 | ⬜ |
| Morga | Check OMAG reporting system | ✅ researched | ⬜ |
| Bacay | Pilot testing indicated | 🟡 | ⬜ |
| Bacay | DA superadmin; more features; visualization | ✅ | ⬜ |
| Bacay | Leave model; recommendations; update objectives | 🟡/⬜ | ⬜ |

---

## Summary scorecard (June 13, 2026)

| Area | App (📱) | Paper (📄) |
|------|----------|------------|
| **I. System reframing** | ✅ Implemented | ⬜ Not pasted |
| **II. App features** | ✅ ~95% (farm insight read on farmer app = gap) | ⬜ |
| **III. Data visualization** | ✅ Complete | ⬜ Figures/captions |
| **IV. Reporting system** | ✅ Core complete (no PDF/export) | ⬜ |
| **V. Model justify** | ✅ Left as-is | 🟡 Ch V sections drafted in Word (5.0–5.1.3 per team) · ⬜ final audit |
| **VI. Documentation** | 🟡 Repo updated | ⬜ Word thesis |
| **VII. Chapter IV** | 🟡 Ready to test | ⬜ Not written |
| **VIII. Chapter V** | — | 🟡 Partial (5.0–5.1.3 linked) · ⬜ finalize |

**Phase 1 (app checkpoint):** Core panel app requirements **achieved** (see **Section IX** below).  
**Phase 2 (after feedback):** Farmer farm-insights view, PDF export, date filters, chat, formal pilot write-up, thesis paste.

---

## Phase 2 backlog (intentionally deferred)

- Farmer reads `farm_insights` on field screen  
- Date-range filter on Reports  
- PDF/CSV export from admin  
- In-app chat / AI  
- Push notification when DA replies  
- Separate OMAG vs DA roles  
- External OMAG-POL system integration  
- Model retraining  

---

## Key repo files

| Purpose | Path |
|---------|------|
| This list | `docs/thesis/REVISIONS_LIST_2026-06-12.md` |
| App progress report (plain language) | `docs/thesis/PANEL_APP_PROGRESS_REPORT_2026-06-13.md` |
| Feature checklist | `docs/thesis/PANEL_FEATURE_CHECKLIST.md` |
| DA account setup | `docs/thesis/DA_SUPERUSER_SETUP.md` |
| Paper paste blocks (when ready) | `docs/thesis/THESIS_PASTE_BLOCKS.md` |
| Middleware framing | `docs/thesis/DETECTION_COLLECTOR_MIDDLEWARE.md` |

---

## IX. App Implementation Changes (Software — June 12–13, 2026)

**Live admin web:** https://celadon-mochi-48bf70.netlify.app  
**Model in app:** YOLO26s v16 TFLite @ 0.25 — **not retrained** in this sprint.

| Revision description | Progress | Comment / evidence |
|---------------------|----------|-------------------|
| **Middleware loop in software:** Farmer upload → on-device detect → auto-report to cloud → DA/OMAG consolidated view → strategy/remedy input → feedback returned to farmer on capture detail | ✅ Done | `detection_service.dart`, `cloud_sync_service.dart`, `expert_responses`, `captured_photo_detail_screen.dart` |
| **No external OMAG-POL reporting API found** — PineSight Admin + mobile staff mode serve as the authority reporting surface; external integration recommended for future work | ✅ Researched | Section I note · `PANEL_APP_PROGRESS_REPORT_2026-06-13.md` |
| **Farmer role and UX unchanged** — Scan → field → analyze → save; bottom nav and capture flow preserved | ✅ Done | Farmer JWT scope unchanged |
| **Per-upload reporting** — every image submission auto-generates one cloud report immediately after detection | ✅ Done | One `detections` row per save |
| **Duplicates allowed** — multiple uploads per farm are logged separately | ✅ Done | By design |
| **Positive / Negative badges** on capture history and report lists | ✅ Done | `detection_report_status.dart`, `capture_activity_card.dart` |
| **Farmer reads Expert advice from DA/OMAG** after staff replies | ✅ Done | `captured_photo_detail_screen.dart`, `expert_feedback_service.dart` |
| **Three roles:** Farmer · DA staff (`da` JWT) · Full admin (`admin` JWT) | ✅ Done | `admin_session.dart` |
| **Registration role picker** — Farmer vs DA/OMAG/LGU staff at sign-up | ✅ Done | `register_screen.dart`, `profiles.account_intent` |
| **DA access request + approval workflow** — staff apply; full admin approves/rejects on web or mobile | ✅ Done | `da_access_requests` table · web **Users** · mobile **DA access requests** |
| **Staff mobile: no camera** — center nav opens staff queue (DA requests for admin, Farmer reports for DA) | ✅ Done | `main_dashboard_screen.dart` (June 13) |
| **Red notification badges** — pending DA requests, pending farmer reports, farmer DA approval/rejection | ✅ Done | `staff_nav_badges_service.dart` |
| **Staff home dashboard** — quick links to DA requests and Farmer reports (no duplicate cards on More tab) | ✅ Done | `_StaffHomePanel` · removed from `_MoreTab` |
| **Staff home map preview** — org-wide positive sightings map on Home (Open → full map) | ✅ Done | `home_map_preview_section.dart` |
| **View all accredited farmers' reports** — org-wide for JWT staff on web and mobile | ✅ Done | PineSight Admin **Reports** · `admin_reports_screen.dart` |
| **Pending reply queue** — positive detections with no DA advice yet | ✅ Done | Filter on web + mobile |
| **Strategy/remedy input per detection** — DA/OMAG writes recommended actions; saved to cloud | ✅ Done | Web Reports inline save · mobile staff on capture detail → `expert_responses` |
| **Strategy/remedy per farm (field-level insight)** — DA can save note per field on web | 🟡 Partial | Web **Fields** → `farm_insights` · **Farmer cannot read on mobile yet** |
| **Analytics dashboard (web)** — positive/negative totals, 7d/30d, donut, 30-day line trend, top farms bar/table | ✅ Done | PineSight Admin → **Analytics** drawer |
| **Analytics dashboard (mobile staff)** — on **Diagnose** tab: 2×2 KPI grid, donut, line trend **7D / 1M / 1Y**, top **5** horizontal bar, top **5** table with Map button | ✅ Done | `staff_analytics_panel.dart`, `staff_analytics_charts.dart` (June 13) |
| **Farm and owner information** on reports and analytics | ✅ Done | Join `fields` + `profiles` |
| **Positive detection rule** — mealybugs detected (`count > 0` / `has_mealybugs`); confirmed tier ≥ 0.25 | ✅ Done | `detection_report_status.dart` |
| **Zero-mealybug uploads excluded from map and analytics visualization** | ✅ Done | `detectionRowIsPositive` filter |
| **Zero-mealybug uploads still appear in table/report log and history** | ✅ Done | All uploads in Reports + capture lists with Negative badge |
| **Map → zoom-aware heatmap** — zoomed out: field-level heatmap; zoomed in: individual positive pins only | ✅ Done | Mobile (`detections_map_screen.dart`) + web (`admin/app.js`) |
| **Geotagging** on submissions (GPS / EXIF / manual) | ✅ Done | Visible on reports and map |
| **Reports auto-submit to cloud** on each farmer save | ✅ Done | Supabase `detections` + storage |
| **Consolidated super-user view** across all farmers | ✅ Done | Web + mobile staff JWT |
| **Reports basis for DA/OMAG mitigation** returned to farmers | ✅ Done | Expert advice loop |
| **Model not retrained** — v16 remains shipped on-device model | ✅ Done | No training work in app sprint |
| **App does not claim deployment-ready** — cautious advisory copy on scan results | ✅ Done | `detection_advisory_messages.dart` |
| **PDF/CSV export from admin UI** | ⬜ Not built | Manual SQL export only — Phase 2 |
| **In-app chat or AI expert assistant** | ⬜ Not built | Panel suggested as future work |
| **Push notification when DA replies** | ⬜ Not built | Notifications screen placeholder |
| **Debug demo account switcher** — save email/password per role on device for testing (debug builds only, not shipped) | ✅ Done | `demo_account_switcher.dart` (June 13) |

### IX-A. June 12–13 sprint timeline (app only)

| Date | Revision description | Progress |
|------|---------------------|----------|
| Jun 12 | Positive/negative split; web **Reports** + **Analytics**; expert advice loop; heatmap + zoom pins; Supabase `expert_responses` + `farm_insights` | ✅ Done |
| Jun 13 | Registration + DA approval; staff UX (no camera, badges, home dashboard); staff map on Home; mobile Analytics on Diagnose; remove More-tab duplicates; demo switcher | ✅ Done |

### IX-B. App vs paper — what still needs writing (not code)

| Revision description | Progress |
|---------------------|----------|
| Paste middleware framing, objectives, pilot testing into Word thesis | ✅ Done (June 13–14) |
| APA 7th on all figures and tables | 🟡 Mostly done — spot-check captions per `THESIS_FIGURES_TABLES_ERRATA.md` |
| Ch IV — expert testing results, DA insights, honest model metrics | ✅ Done |
| Ch V — recommendations (expert consultation, annotation, model, OMAG integration) | ✅ Done |

**Detailed reports:** [`PANEL_APP_PROGRESS_REPORT_2026-06-13.md`](PANEL_APP_PROGRESS_REPORT_2026-06-13.md) · [`APP_IMPLEMENTATION_REPORT_2026-06-12.md`](APP_IMPLEMENTATION_REPORT_2026-06-12.md)
