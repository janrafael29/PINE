# PINYA-PIC — Video Demo Guide (June 12, 2026)

**Use this while screen-recording.** Follow the shot list in order for the full panel story: *detection collector → auto-report → DA consolidation → expert feedback*.

**Suggested length:** 8–12 minutes (or cut Parts B/C for a 5-min mobile-only clip).

---

## Before you record

| Check | Detail |
|-------|--------|
| Phone | TECNO connected; app running via `run_debug.ps1` or release build |
| Network | Wi‑Fi/data ON (sync + map need internet) |
| Brightness | Max; Do Not Disturb on |
| Test leaf photos | One image likely **positive** (visible pests) + one **negative** (clean leaf) in gallery |
| Accounts | Know both passwords; sign out between role switches |
| Admin web | `admin/config.js` filled; open PineSight Admin in browser — **live:** see [`ADMIN_WEB_DEPLOY.md`](ADMIN_WEB_DEPLOY.md) · **local:** `http://localhost:8080` |
| Pre-seed (optional) | 2–3 prior scans on field **Angelei** so map/analytics aren’t empty |

### Test accounts (June 13, 2026)

| Role | Email | JWT | What you’ll show |
|------|-------|-----|------------------|
| **Farmer** | `morillo3580225@gmail.com` | none | Scan, save, history, map, read DA advice |
| **DA (after approval)** | `rgist45@gmail.com` | `da: true` after admin approves | PineSight DA, Reports, Analytics, mobile queue |
| **Full admin** | `morgajanrafael1793@gmail.com` | `admin: true` | Approve DA requests (web **or** mobile), Users, Fields, bulk tools |
| **Legacy DA** | `morgajanrafael1793@gmail.com` | also has `da` | Use as **admin** for approval; use **rgist45** for pure DA shots |

**Field for farmer:** **Angelei**

**Sign out and sign in** after any role change so the JWT refreshes.

**Smoke test checklist:** [`SMOKE_TEST_2026-06-13.md`](SMOKE_TEST_2026-06-13.md)

### Three roles (panel story)

| Role | Can do | Cannot do |
|------|--------|-----------|
| **Farmer** | Own fields, scan, read DA advice | Org-wide data, staff tools |
| **DA** | View all farms, Reports reply, Analytics | Users, Fields, bulk edits |
| **Admin** | Everything DA can + user/field management + approve DA requests (web or mobile) | — |

DA access: farmer **requests** in app → **full admin approves** on web (**Users** drawer) **or** mobile (**More → DA access requests**).

---

## Bottom navigation (mobile)

| Icon | Label | Use in video |
|------|-------|--------------|
| Home | Home | Saved images, map preview, field shortcuts |
| Shield | Diagnose | Farmer weekly stats (not org-wide DA analytics) |
| **Center** | **Scan** | Main scan flow |
| Landscape | My Fields | Field list → field detail → detections map |
| Grid | More | Profile, DA request (farmer), DA approval (admin), Farmer reports (DA) |

---

## PART 1 — Opening (30–45 sec)

**Say something like:**
> “PINYA-PIC is a **mealybug detection collector** and assistive middleware. Farmers upload leaf images; the app detects on-device, **auto-submits a report** per upload, and DA/OMAG can review consolidated sightings, enter strategies, and send feedback back to farmers. The model supports scouting — it is **not** claimed as deployment-ready diagnosis.”

**Show:** App logo / Home screen (farmer logged in).

---

## PART 2 — Farmer flow (4–5 min)

### Shot 2.1 — Scan & detection

| Step | Where to tap | What to show on screen |
|------|--------------|------------------------|
| 1 | Bottom nav → **Scan** (center button) | Field-first flow starts |
| 2 | Choose field **Angelei** | Field selection |
| 3 | **Camera** or **Gallery** | Take photo or pick test image |
| 4 | Wait for analysis | Progress → result with bounding boxes |
| 5 | Point at UI | **Count**, confidence %, advisory (“possible mealybug — verify visually”) |

**Say:** Each upload becomes one report; duplicates per farm are OK.

### Shot 2.2 — Save & auto-sync

| Step | Where | What to show |
|------|-------|--------------|
| 1 | Tap **Save** on result screen | Confirm field + location |
| 2 | Success / return to dashboard | Capture appears under **Saved Images** |

**Say:** Report syncs to Supabase automatically when online — no separate “submit” button.

### Shot 2.3 — Positive / Negative in history

| Step | Where | What to show |
|------|-------|--------------|
| 1 | **Home** → tap a thumbnail in **Saved Images** | Or: field **⋮** menu → manage photos |
| 2 | **Captured Picture** detail | Image + overlay, field name, GPS, count |
| 3 | Back to list | **Positive** (red) or **Negative** (green) chip on each card |

**Alternative list paths:**
- **My Fields** → **Angelei** → ⋮ menu → **Manage photos**
- During scan: **Add Photo** screen → top-right **photo library** icon → full capture list

**Say (Ma'am Jan rule):**  
> “**Positive** means mealybugs were detected. **Negative** scans still appear in the table and history, but they are **excluded** from the outbreak map and analytics.”

Repeat Shot 2.1–2.3 with a **negative** image if you have one — contrast badges and map behavior.

### Shot 2.4 — Detections map & heatmap (important)

**Use this screen — not the small Home map preview** (Home preview may show all GPS pins; the full map applies positive-only rules).

| Step | Where | What to show |
|------|-------|--------------|
| 1 | **My Fields** → **Angelei** | Field detail |
| 2 | Tap **View detections map** | Full-screen satellite map |
| 3 | **Pinch zoom OUT** (wide area) | **Field heatmap** — fields tinted by positive sighting density; **no per-image pins** |
| 4 | **Pinch zoom IN** (close) | Individual **positive** pins appear |
| 5 | Tap a pin | Bottom sheet: count, confidence, open detail |
| 6 | (If only negatives exist) | Message: *“No positive mealybug detections… Negative scans remain in your history.”* |

**Optional:** Tap **Fields** FAB (bottom-right) → filter to one field.

**Also from Home:** Map Preview card → **Open** → same **Detections Map** screen.

**Say:** Zoomed out = field-level heatmap for authorities; zoomed in = drill-down to each positive sighting.

### Shot 2.5 — Farmer Diagnose tab (brief, ~20 sec)

| Step | Where | What to show |
|------|-------|--------------|
| 1 | Bottom nav → **Diagnose** | Weekly image count, infestation % for **this farmer’s fields** |

**Say:** This is the farmer’s own dashboard — org-wide analytics are on the DA admin console.

---

## PART 3 — DA web (PineSight DA) (2–3 min)

Use **`rgist45@gmail.com`** after admin approval (see Part 3B optional clip).

### Open DA console

1. Browser → admin site (live URL from [`ADMIN_WEB_DEPLOY.md`](ADMIN_WEB_DEPLOY.md), or `npx serve` in `admin/` for local dev).
2. Sign in as **DA** (`rgist45@gmail.com`).
3. Confirm sidebar: **PineSight DA** — **Reports** + **Analytics** only (**no Users / Fields**).

### Shot 3.1 — Sidebar overview

Point at top stats: **users · fields · reports** (read-only context).

### Shot 3.2 — Reports (card UI + DA reply)

| Step | Sidebar | What to show |
|------|---------|--------------|
| 1 | **Reports** | **Card layout**: thumbnail, status pill, farmer/field |
| 2 | Filter **Pending reply** | Positive reports waiting for DA |
| 3 | On a positive card | Textarea + action → **Save advice** |
| 4 | Filter **All** | Positive + negative rows (negatives not on map) |

### Shot 3.3 — Analytics

| Step | Sidebar | What to show |
|------|---------|--------------|
| 1 | **Analytics** | Positive/negative totals, 7d/30d |
| 2 | Scroll | 7-day trend chart, **Top farms** |
| 3 | **View on map** | Focuses field on map |

### Shot 3.4 — DA map (read-only)

| Step | Main map | What to show |
|------|----------|--------------|
| 1 | Zoom **out** | Field heatmap + legend |
| 2 | Zoom **in** | Positive pins only |
| 3 | Tap field/capture | Read-only popups — **no** owner dropdowns, **no** bulk bar, **no** Select chip |

---

## PART 3B — Optional: DA approval workflow (30–45 sec)

| Step | Who | Action |
|------|-----|--------|
| 1 | `rgist45@gmail.com` (phone) | **More → DA / OMAG access → Request DA access** → popup: *Request sent…* |
| 2a | `morgajanrafael1793@gmail.com` (**web**) | **Users → DA access requests → Approve DA** |
| 2b | *or* `morgajanrafael1793@gmail.com` (**phone**) | **More → DA access requests → Approve DA** → popup: *DA access approved* |
| 3 | `rgist45@gmail.com` | Sign out/in → **DA • all farms** (mobile) or **PineSight DA** (web) |

**Say:** Full admin can approve from the laptop console or the same mobile app — same edge function either way.

---

## PART 3C — Full admin (PineSight Admin + mobile) (1–2 min)

### Web — `morgajanrafael1793@gmail.com` (`admin: true`)

| Step | Sidebar | What to show |
|------|---------|--------------|
| 1 | **Users** | DA access requests + **Create user** |
| 2 | **Fields** | **New field**, boundary edit, owner dropdown |
| 3 | Map tools | **Select** + bulk **Assign field / Move / Set owner** |

### Mobile — same full admin account (optional 30 sec)

| Step | Where | What to show |
|------|-------|--------------|
| 1 | **More** → **DA access requests** | Pending list with **Approve DA** / **Reject** (if any pending) |
| 2 | **Diagnose** / **My Fields** | Badge **Admin • all farms** |
| 3 | **More → Farmer reports (DA)** | Same DA reply queue as web (staff tools) |

**Say:** Only full admin manages accounts and field data; DA staff advise on reports only. DA approval works on web or phone.

### Shot 3.5 — DA farm insight (admin only, optional 20 sec)

| Step | Sidebar | What to show |
|------|---------|--------------|
| 1 | **Fields** → **DA farm insight** | Select field, note → Save |

**Note:** Farmer mobile UI to read farm insights is **not built yet**.

---

## PART 4 — Close the feedback loop (1–2 min)

### Shot 4.1 — Farmer sees DA advice

| Step | Action |
|------|--------|
| 1 | **Sign out** DA on web (or switch device) |
| 2 | Mobile: sign in as **farmer** (`morillo3580225@gmail.com`) |
| 3 | Open the **same positive capture** DA replied to |
| 4 | Scroll to card: **Expert advice from DA/OMAG** |

**Say:** This completes the middleware loop — collect → consolidate → expert strategy → farmer feedback.

### Shot 4.2 — DA on mobile (optional, 30 sec)

| Step | Action |
|------|--------|
| 1 | Sign in as **DA** (`rgist45@gmail.com`) on phone |
| 2 | **Diagnose** / **My Fields** → badge **DA • all farms** |
| 3 | **More → Farmer reports (DA)** → Pending reply → reply form |
| 4 | Open capture detail → **DA/OMAG reply** on positive image |

---

## PART 5 — Closing line (15 sec)

**Say:**
> “The model stays YOLO26 v16 — we document its limits honestly. This sprint focused on **collector workflow**, **positive-only visualization**, and **DA mediation** — not claiming the detector is deployment-ready without expert validation.”

---

## Quick reference — where each panel requirement appears

| Panel ask | Where to show it |
|-----------|------------------|
| Detection collector / auto-report | Farmer scan → save (Part 2.2) |
| Per-upload reporting | Same; one row per scan |
| Positive-only map/heatmap | **Detections Map** zoom out/in (2.4) + Admin map (3.4) |
| Negative in table only | Reports **All** filter + capture list badges (2.3) |
| DA sees all farmers | Admin **Reports** (3.2) |
| Analytics / top farms | Admin **Analytics** (3.3) |
| DA strategy input | Admin Reports save advice (3.2) or mobile DA reply (4.2) |
| DA access approval | Farmer request (3B step 1) + admin approve web (3C) or mobile (3C) |
| Farmer feedback | **Expert advice from DA/OMAG** card (4.1) |
| Farmer UX unchanged | Scan flow (2.1) |
| Geotagging | Capture detail **GPS** row (2.3) |

---

## Troubleshooting while recording

| Problem | Fix |
|---------|-----|
| Map empty but history has scans | Need **positive** detections + GPS; zoom level matters |
| Farmer sees no DA advice | Must be **positive**, synced online, DA saved reply |
| No pending DA request (admin) | Refresh **Users** drawer (web) or **More → DA access requests** (mobile) |
| Admin “Not authorized” | Sign out/in after `admin: true` |
| Sync delay | Pull to refresh / reopen app; check network |
| Device not found | Unlock phone, USB debugging, re-run `flutter devices` |

---

## Suggested recording order (one continuous take)

1. **[Optional]** `rgist45` request DA → admin approve (web **or** mobile) → sign in as DA  
2. Farmer: scan positive → save  
3. Farmer: badges in list → detail (GPS)  
4. Farmer: **Detections Map** heatmap + zoom to pins  
5. DA web (`rgist45`): Reports → Pending reply → save advice  
6. DA web: Analytics + map (read-only tools)  
7. Admin web (`morgajanrafael`): Users + Fields (brief)  
8. Farmer: **Expert advice** card  
9. Optional: negative scan → in list, not on map  

---

## Related docs

| Doc | Purpose |
|-----|---------|
| `APP_IMPLEMENTATION_REPORT_2026-06-12.md` | What was built |
| `ADMIN_WEB_DEPLOY.md` | Deploy admin web to a public URL |
| `REVISIONS_LIST_2026-06-12.md` | Panel revision progress |
| `DA_SUPERUSER_SETUP.md` | Account setup + 15-min test |
