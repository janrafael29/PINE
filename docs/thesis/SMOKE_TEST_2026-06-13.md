# Smoke test checklist — June 13, 2026

Run this **before** recording the video demo. Check each box in order.

**Live project:** `https://sjdcnkendlgqbxxjdqml.supabase.co`  
**Admin web (live):** `https://celadon-mochi-48bf70.netlify.app` — deploy with [`ADMIN_WEB_DEPLOY.md`](ADMIN_WEB_DEPLOY.md)  
**Admin web (local):** `http://localhost:8080` (hard refresh `Ctrl+F5` after code changes)  
**Mobile:** `.\scripts\run_debug.ps1` with device connected

---

## Account setup (verified in Supabase)

| Role | Email | JWT flags | Use in test |
|------|-------|-----------|-------------|
| **Farmer** | `morillo3580225@gmail.com` | none | Scan, Angelei only |
| **New DA (after approval)** | `rgist45@gmail.com` | none → `da` after approve | Request + DA demo |
| **Full admin** | `morgajanrafael1793@gmail.com` | `admin: true` (+ `da`) | Approve requests, Users/Fields |

**Important:** After any metadata change, **sign out and sign in** on phone and web.

---

## Part 1 — DA approval workflow (~15 min)

### On phone — `rgist45@gmail.com`

- [ ] **Sign in** (do not register again)
- [ ] **More** → **DA / OMAG access** → optional note → **Request DA access**
- [ ] Confirm popup: **Request sent** / card shows **Pending admin review**

### Approve request — pick **web** or **mobile** (full admin `morgajanrafael1793@gmail.com`)

#### Option A — laptop (PineSight Admin)

- [ ] Open admin URL (live or `http://localhost:8080`) → sign in
- [ ] Sidebar shows **PineSight Admin** + **Users** + **Fields**
- [ ] **Users** → **DA access requests** → see `rgist45` / **DA**
- [ ] Click **Approve DA** → confirm
- [ ] Toast: DA access approved

#### Option B — phone (same admin account)

- [ ] Sign in as `morgajanrafael1793@gmail.com` on mobile
- [ ] **More** → **DA access requests** → see pending `rgist45` row
- [ ] Tap **Approve DA** → popup: *DA access approved*
- [ ] Card clears or shows no pending requests

### On phone — `rgist45@gmail.com` again

- [ ] **Sign out** → **Sign in**
- [ ] **Diagnose** or **My Fields** → badge **DA • all farms** (not Admin)
- [ ] **More** → **Farmer reports (DA)** opens
- [ ] **More** → no “request access” card (already staff)

### On laptop — DA role check (`rgist45@gmail.com`)

- [ ] Sign out admin → sign in as **rgist45**
- [ ] Title **PineSight DA** — **no Users, no Fields**
- [ ] **Reports** + **Analytics** work
- [ ] Map: read-only popups, no bulk bar, no Select chip

---

## Part 2 — Role boundaries (~10 min)

### DA cannot (use `rgist45` on web)

- [ ] **Users** button hidden
- [ ] **Fields** button hidden
- [ ] No bulk assign / move / set owner
- [ ] Capture pins not draggable

### Farmer scope (`morillo3580225@gmail.com`)

- [ ] **My Fields** → only **Angelei**
- [ ] **Diagnose** → no “all farms” badge
- [ ] **More** → no Farmer reports (DA)

### Full admin can (`morgajanrafael1793@gmail.com`)

**Web:**
- [ ] **Users** → create user form visible
- [ ] **Fields** → new field form visible
- [ ] Bulk bar / geofence tools available when Select on

**Mobile:**
- [ ] **More** → **DA access requests** card visible (full admin only)
- [ ] **Diagnose** / **My Fields** → badge **Admin • all farms**

---

## Part 3 — End-to-end report loop (~20 min)

### Farmer scan

- [ ] Sign in `morillo3580225@gmail.com`
- [ ] **Scan** → **Angelei** → positive test image → **Save**
- [ ] **Home** → thumbnail in Saved Images

### DA reply (web or mobile)

- [ ] Sign in DA (`rgist45@gmail.com`)
- [ ] **Reports** → filter **Pending reply** → find farmer’s capture
- [ ] Type advice → **Save advice** → status **Replied**

### Farmer reads advice

- [ ] Sign in farmer again
- [ ] Open **same capture** → scroll to **Expert advice from DA/OMAG**

---

## Pass criteria

All three parts checked → ready to record per `VIDEO_DEMO_GUIDE_2026-06-12.md`.

## If something fails

| Issue | Fix |
|-------|-----|
| Not authorized on admin web | Sign out/in; confirm `admin` or `da` in Supabase Auth |
| No pending request | Submit from phone as `rgist45`; refresh **Users** (web) or **More → DA access requests** (mobile) |
| DA still sees Users/Fields | Hard refresh `Ctrl+F5`; confirm JWT has `da` not only `admin` |
| Farmer sees all farms | Wrong account or stale JWT — sign out/in |
| No Expert advice card | Capture must be **positive** and synced; DA must save reply |
