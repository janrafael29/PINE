# REVISIONS LIST

**AS OF JUNE 12, 2026 — PROGRESS REPRESENTATION**

**Project:** PINYA-PIC  
**Accounts (live test):** DA `morgajanrafael1793@gmail.com` (admin) · Farmer `morillo3580225@gmail.com`  
**Supabase:** `expert_responses` + `farm_insights` migration applied  

**Legend:** ✅ Done · 🟡 Partial · ⬜ Not started · 📄 Paper only · 📱 App only

---

## I. System Reframing

| Revision description | Page # (in paper) | Progress |
|---------------------|-------------------|----------|
| Reframe app as **assistive middleware / detection collector**: Farmer upload → detect → auto-report → consolidate for DA/OMAG → DA/OMAG strategies → feedback to farmers | Ch I, Abstract | 🟡 **Docs ready** (`DETECTION_COLLECTOR_MIDDLEWARE.md`, `THESIS_PASTE_BLOCKS.md`) · ⬜ **Not yet pasted into Word thesis** |
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
| View **all accredited farmers' reports** | Ch III | ✅ JWT `admin: true` — `morgajanrafael1793@gmail.com` · web + mobile **Admin • all farms** |
| **Pending reply** queue (positive, no DA answer yet) | Ch III | ✅ Reports filter: **Pending reply** |
| Pilot / live test with real accounts | Ch III / Ch IV | 🟡 Accounts configured · ⬜ **End-to-end test on device not yet signed off** |

---

## III. Data Visualization

| Revision description | Page # | Progress |
|---------------------|--------|----------|
| Map → **heatmap** (zoom-aware) | Ch III / Fig. | ✅ Mobile + admin: zoom **&lt; 15** = field heatmap; **≥ 15** = positive pins |
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

## Summary scorecard (June 12, 2026)

| Area | App (📱) | Paper (📄) |
|------|----------|------------|
| **I. System reframing** | ✅ Implemented | ⬜ Not pasted |
| **II. App features** | ✅ ~90% (farm insight read on farmer app = gap) | ⬜ |
| **III. Data visualization** | ✅ Complete | ⬜ Figures/captions |
| **IV. Reporting system** | ✅ Core complete (no PDF/export) | ⬜ |
| **V. Model justify** | ✅ Left as-is | ⬜ Not written in thesis |
| **VI. Documentation** | 🟡 Repo updated | ⬜ Word thesis |
| **VII. Chapter IV** | 🟡 Ready to test | ⬜ Not written |
| **VIII. Chapter V** | — | ⬜ Not written |

**Phase 1 (app checkpoint):** Core panel app requirements **achieved**.  
**Phase 2 (after 24h / feedback):** Farmer farm-insights view, PDF export, date filters, chat, formal pilot write-up, thesis paste.

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
| Feature checklist | `docs/thesis/PANEL_FEATURE_CHECKLIST.md` |
| DA account setup | `docs/thesis/DA_SUPERUSER_SETUP.md` |
| Paper paste blocks (when ready) | `docs/thesis/THESIS_PASTE_BLOCKS.md` |
| Middleware framing | `docs/thesis/DETECTION_COLLECTOR_MIDDLEWARE.md` |
