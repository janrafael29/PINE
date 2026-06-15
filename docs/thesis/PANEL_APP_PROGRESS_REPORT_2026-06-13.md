# PINYA-PIC — Panel App Progress Report

**Date:** June 13, 2026  
**Audience:** Adviser, panel, and team (non-technical friendly)  
**Scope:** Mobile app + PineSight Admin web — what the panel asked for vs what is built today  

**Related docs:** [`PANEL_RECORDING_ALIGNMENT.md`](PANEL_RECORDING_ALIGNMENT.md) · [`PANEL_FEATURE_CHECKLIST.md`](PANEL_FEATURE_CHECKLIST.md) · [`APP_IMPLEMENTATION_REPORT_2026-06-12.md`](APP_IMPLEMENTATION_REPORT_2026-06-12.md)

---

## Executive summary (plain language)

After the panel meeting, the project **changed direction**. Instead of selling PINYA-PIC as a perfect automatic detector, it is now a **reporting and support tool**:

- **Farmers** still take photos of pineapple leaves on their phone.
- **Each photo** becomes its own report and is sent to the cloud automatically.
- If the app thinks it saw **mealybugs**, that sighting can appear on a **map and charts** for authorities.
- If the app found **no mealybugs**, the photo is still saved in a **list/table** for records, but it does **not** clutter the outbreak map.
- **DA / OMAG staff** review positive reports, write **advice** (what the farmer should do), and see **analytics** across all participating farms.
- The **AI model is kept as-is** (YOLO v16). The team is honest that it is an **initial pilot**, not ready for full field deployment without more training data work.

**Bottom line for the panel:** The **app side of the new direction is largely complete.** What remains is mostly **thesis writing** (limitations, APA formatting, recommendations) and a few **nice-to-have** features (export PDF, chat, push alerts).

---

## What the panel asked for (app side)

| # | Panel request (in simple terms) | Status |
|---|----------------------------------|--------|
| 1 | Stop pretending the model is perfect; focus on **collecting and routing reports** | **Done** (behavior + docs) |
| 2 | Add a **DA / authority user** who sees reports from many farms | **Done** |
| 3 | Each farmer photo = **one report**, submitted **right after** capture | **Done** |
| 4 | Farmers may upload **many photos** (duplicates OK) | **Done** |
| 5 | **Positive** (mealybug found) → map + analytics + DA can reply | **Done** |
| 6 | **Negative** (no mealybug) → visible in **table/history only**, not on map | **Done** |
| 7 | DA writes **mitigation / advice** per positive case | **Done** |
| 8 | Farmer **reads DA advice** on their photo | **Done** |
| 9 | **Analytics**: counts, trends, top farms, heat-style map | **Done** (web Analytics drawer) |
| 10 | Farmer only sees **their own farm**; DA sees **org-wide** data | **Done** |
| 11 | Connect authority tools to the **same system** (web + mobile staff) | **Done** |
| 12 | **Three roles**: Farmer, DA staff, Full Admin + approval for new DA accounts | **Done** |
| 13 | Staff (DA/Admin) should **not use the camera** — review & advise only | **Done** (June 13) |
| 14 | **Notifications** when DA requests need action or farmer request approved/rejected | **Done** (red badges) |
| 15 | Export formal PDF/CSV reports from admin | **Not built** (optional) |
| 16 | In-app **chat** or **AI assistant** with experts | **Not built** (panel suggested as future) |
| 17 | Push notification when DA replies | **Not built** (placeholder screen only) |

---

## Verification — did we achieve the panel direction?

### Fully achieved

#### 1. Detection collector (middleware)

Every time a farmer saves a scan:

1. The photo is analyzed on the phone (same YOLO model as before).
2. A row is created in the cloud database (`detections`) — **one row per upload**.
3. The system records whether mealybugs were found (`has_mealybugs`), how many, GPS if available, and which field.

This matches Sir Jude’s “each scan becomes a case/report to the superuser” and the chat confirmation: **per upload, submit immediately**.

#### 2. Positive vs negative split

| Type | Meaning | Where it shows |
|------|---------|----------------|
| **Positive** | Model confirmed at least one mealybug (count > 0) | Map, heatmap, analytics, DA “pending reply” queue |
| **Negative** | No mealybugs confirmed | History lists, Reports table — **not** on outbreak map |

This matches Christine / Sir Jude: *“Yung may mealybugs lang”* on the map; negatives stay as reported cases in the table.

#### 3. Farmer experience (unchanged core, safer wording)

- Bottom nav: Home, Diagnose, **Scan (camera)**, My Fields, More.
- Scan → pick field → analyze → save → auto-sync.
- Capture history shows **Positive / Negative** badges.
- On photo detail, farmer can read **“Expert advice from DA/OMAG”** when staff has replied.
- Advisory text uses careful language (“possible mealybug”, verify visually) — not claiming perfect accuracy.

#### 4. DA / Admin on PineSight Admin (web)

Live site: https://celadon-mochi-48bf70.netlify.app

| Feature | What it does |
|---------|----------------|
| **Reports** | All uploads in a table; filters: All, Positive only, Negative only, Pending reply |
| **DA advice** | Staff types strategy/remedy per positive image and saves |
| **Analytics** | Positive counts (7d/30d/all), negative count, 7-day chart, top farms table |
| **Map** | Org-wide view; **positive-only** heatmap when zoomed out, pins when zoomed in |
| **Users** | Manage accounts; **DA access requests** with popup when new requests arrive |
| **Fields** | View/edit farm boundaries; optional DA farm-level notes (admin side) |

Map editing tools were simplified to **read-only** for panel demo stability (no bulk move/drag).

#### 5. DA / Admin on mobile

| Role | Center button (replaces camera) | Home screen |
|------|--------------------------------|-------------|
| **Full Admin** | DA access requests (pending approvals) | Staff dashboard — requests + farmer reports |
| **DA staff** | Farmer reports (pending advice queue) | Staff dashboard — reports shortcut |
| **Farmer** | Camera / Scan (unchanged) | Saved images + map preview |

Red **badge numbers** appear when:

- Admin has pending DA access requests.
- DA has farmer reports waiting for advice.
- Farmer’s DA access request was approved or rejected (badge on **More** until they open it).

Staff no longer see “Saved Images” or “Add Photo” prompts — they only **review farmer input and write reports**.

#### 6. Registration & DA access workflow

- **Register** → choose **Farmer** or **DA / OMAG / LGU staff**.
- Farmers get a normal account.
- Staff applicants fill org/name/location/position; request goes to **pending**.
- **Full admin** approves or rejects on **web (Users)** or **mobile (DA access requests)**.
- Approved staff get JWT role `da`; full admins get `admin`.

#### 7. Model honesty (app behavior)

- The shipped model was **not retrained** during this sprint (still YOLO26s **v16** @ confidence 0.25).
- The app does **not** claim “100% accurate” or “deployment-ready” in UI copy.
- **Thesis/paper** still needs explicit limitations chapter (see “Not done — documentation” below).

---

### Partially achieved

| Item | What works | What’s missing |
|------|------------|----------------|
| **Farm-level DA insights** | Admin can save notes per field on web | Farmer mobile app does not show these notes yet |
| **Analytics depth** | Counts, trend chart, top farms | No date-range picker (7d/30d/90d toggle) on admin home |
| **Admin dashboard layout** | Analytics in sidebar drawer | No full-page “dashboard home” with KPI grid (Phase 2 design) |
| **Case numbering** | Each upload has a database ID | No friendly “Case #123” label in UI |
| **Zoom map threshold** | Mobile uses zoom **18** for pins; admin web uses **15** | Minor inconsistency — same idea, different number |

---

### Not built (optional / post-defense)

These were mentioned by the panel as **future ideas**, not blockers for Monday:

- PDF or CSV **export** from admin UI  
- Farmer ↔ DA **in-app chat**  
- **AI chatbot** connected to live expert  
- **Push notifications** when DA replies (Notifications screen is still a placeholder)  
- Formal **user testing** write-up of new features (panel said put in recommendations, not required before code freeze)

---

### Not app work — still needed for thesis

| Task | Owner |
|------|--------|
| Write **limitations** (recall ~65%, mAP below panel targets) | Thesis Ch IV–V |
| Explain **why v16** kept vs v20–v22 | Thesis + `MODEL_PERFORMANCE_ALL_VERSIONS.md` |
| **APA 7** formatting (tables, figures, abstract) | Thesis document |
| Panel **response letter** / revision list final | `PANEL_REVISION_RESPONSE_DRAFT.md` |
| Do **not** claim deployment-ready in abstract | Wording audit |

---

## How the full loop works (story for defense)

```
┌─────────────┐     scan + save      ┌──────────────┐
│   Farmer    │ ──────────────────►  │   Cloud DB   │
│  (mobile)   │   one row per photo  │  detections  │
└─────────────┘                      └──────┬───────┘
       ▲                                    │
       │         expert_responses           │
       │         (advice text)              ▼
       │                            ┌──────────────┐
       └─────────────────────────── │  DA / Admin  │
                 read advice       │  web + mobile │
                                    └──────────────┘
                                           │
                    positive only          │
                                           ▼
                                    Map + Analytics
```

**Example walkthrough:**

1. Farmer Juan scans a leaf in Field A. App finds 3 mealybugs → **Positive** report syncs.
2. DA Maria opens **Reports → Pending reply**, sees Juan’s photo, writes: *“Apply recommended oil spray; rescan in 7 days.”*
3. Juan opens that photo on his phone → sees **Expert advice from DA/OMAG**.
4. On the admin **map**, Field A gains heat color; negative scans from other farmers do not appear there.

---

## Work completed by area (detailed but plain)

### Mobile app

| Area | What we built |
|------|----------------|
| **Scan & save** | Unchanged farmer flow; every save creates a cloud report |
| **Status labels** | Positive / Negative chips on capture cards and lists |
| **Map** | Farmer map shows **positive sightings only**; heatmap when zoomed out, pins when zoomed in close |
| **DA reports (mobile)** | Staff open **Farmer reports** with filters: All, Positive, Pending reply, **Negative only** |
| **Expert advice** | DA writes on positive captures; farmer reads on same screen |
| **Roles** | Farmer vs DA vs Full Admin via JWT; staff see org-wide data |
| **Registration** | One-time role choice at sign-up; staff DA request form |
| **Staff navigation** | No camera for staff; center button = their main queue; red badges |
| **DA request card** | Farmers request access safely (checkbox + confirm); hidden for staff |

### PineSight Admin (web)

| Area | What we built |
|------|----------------|
| **Reports drawer** | Renamed from “Captures”; positive/negative/pending filters |
| **Analytics drawer** | Stats + chart + top farms |
| **Map** | Positive-only heatmap and pins; read-only for demo |
| **Users** | DA access request list + approve/reject + notification modal |
| **Deploy** | Netlify script fixed; live at celadon-mochi-48bf70.netlify.app |

### Database (Supabase)

| Addition | Purpose |
|----------|---------|
| `expert_responses` | DA advice linked to each detection |
| `farm_insights` | Optional field-level notes (admin) |
| `da_access_requests` | Staff access approval workflow |
| `profiles.account_intent` | farmer vs staff at registration |
| RLS policies | Farmers see own data; staff see org-wide |

---

## Model status (for transparency — not re-coded)

The panel agreed to **leave the model as-is** and discuss gaps in the **paper**:

| Version | Notes |
|---------|--------|
| **v16 (shipped)** | Best balance so far; used in the app |
| **v20–v22** | Trained (YOLO26 S/M, higher resolution); did not beat v16 enough to switch |
| **v22 metrics** (conf 0.25) | Precision 77.6%, Recall 58.3%, mAP@0.5 64.3%, mAP@0.5:0.95 33.8% |

Panel targets (≥85% mAP, ≥80% recall) were **not met**. The app compensates by being **assistive** — collecting sightings and connecting farmers to human experts — not by claiming the AI is final authority.

---

## Test accounts (for demo)

| Role | Email | What to show |
|------|-------|--------------|
| Farmer | `morillo3580225@gmail.com` | Scan, positive/negative badges, read DA advice |
| DA staff | `rgist45@gmail.com` | Center = Farmer reports; write advice |
| Full admin | `morgajanrafael1793@gmail.com` | Center = DA requests; web Users + Analytics |

Sign out and sign back in after role changes. **Hot restart** the app after code updates.

---

## Gaps vs panel — honest scorecard

| Panel theme | App score | Notes |
|-------------|-----------|-------|
| Detection collector / middleware | **95%** | Core loop complete |
| Positive-only map & analytics | **100%** | Mobile + web |
| DA mediation (advice back to farmer) | **90%** | Per-image advice done; farm-level insight not on farmer app |
| New DA user & roles | **95%** | Approval workflow + staff UX |
| Analytics dashboard | **85%** | Drawer works; no date filter / export |
| Model retraining | **N/A** | Intentionally paused per panel |
| Thesis / APA / limitations text | **30%** | Docs exist; Word chapters need paste |

---

## Recommended talking points for defense

**Say:**

- “PINYA-PIC is an **assistive detection collector** — farmers report sightings; DA mediates with expert advice.”
- “Only **positive** mealybug sightings appear on the outbreak map; negatives are still logged for transparency.”
- “The on-device model is an **initial pilot**; we document low recall and recommend better annotations and datasets.”

**Do not say:**

- “Deployment-ready” or “replaces DA inspection”
- “The heatmap includes all scans” (negatives are excluded by design)

---

## What to do next (priority order)

1. **Thesis:** Paste limitations, middleware framing, and recommendations from `THESIS_PASTE_BLOCKS.md`.
2. **Revision list:** Send finalized list to Sir Khil before Monday deadline.
3. **Demo video:** Follow `VIDEO_DEMO_GUIDE_2026-06-12.md` — update staff section to show **center button = queue** (not camera) for DA/Admin accounts.
4. **Optional polish:** PDF export, date filters, farmer view of farm insights, push notifications.

---

## Change log

| Date | Change |
|------|--------|
| 2026-06-12 | Core collector features: positive/negative split, Reports, Analytics, expert advice |
| 2026-06-13 | Staff mobile UX: replace camera with DA requests / farmer reports; red badges; registration roles; DA approval on web + mobile |
| 2026-06-13 | This progress report — panel alignment verification |
