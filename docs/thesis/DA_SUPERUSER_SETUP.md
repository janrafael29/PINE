# DA / OMAG Staff vs Full Admin

**Updated:** June 13, 2026

---

## How DA verification works

1. **User registers** in the mobile app → starts as **farmer**.
2. **More → DA / OMAG access** → optional note → **Request DA access**.
3. Request is stored in `da_access_requests` (status `pending`).
4. **Full admin** approves on **PineSight Admin → Users** (web) **or** **More → DA access requests** (mobile) → **Approve DA** or **Reject**.
5. On approve, edge function `pine-admin-review-da-request` sets `app_metadata.da: true`.
6. User **signs out and signs in** → DA features unlock.

Farmers cannot self-assign `da`. Only a full admin (`admin: true`) can approve.

---

## Manual override (still supported)

Admins can still set `da: true` directly in Supabase Dashboard → Authentication if needed.

---

## Two staff roles (JWT `app_metadata`)

| Claim | Role | PineSight Admin web | Mobile app |
|-------|------|---------------------|------------|
| `admin: true` | **Full admin** | Users, Fields, bulk edits, geofences, Analytics | All farms + field edit + **More → DA access requests** (approve/reject) |
| `da: true` (no admin) | **DA / OMAG staff** | Map (view), Reports (reply), Analytics (view) | All farms (view) + Farmer reports |

Farmers have neither claim — own fields only.

---

## Live demo accounts (PINYA-PIC)

| Role | Email | JWT flags | Display name |
|------|-------|-----------|--------------|
| **Full admin** | `morgajanrafael1793@gmail.com` | `admin: true` ✅ | ADMIN |
| **DA (after approval)** | `rgist45@gmail.com` | `da: true` after approve | DA |
| **Farmer (test)** | `morillo3580225@gmail.com` | none | anji |

Farmer test field: **Angelei** (`beb03fb0-f5e8-46c3-a72e-4032a06a18d4`).

**Smoke test:** [`SMOKE_TEST_2026-06-13.md`](SMOKE_TEST_2026-06-13.md)

---

## Important: refresh JWT after metadata change

If you change `admin` or `da` in Supabase, **sign out and sign in again** on:

- PineSight Admin (web)
- PINYA-PIC mobile app

The JWT only picks up `app_metadata` at sign-in.

---

## Where each role signs in

| Surface | DA (`rgist45@gmail.com` after approve) | Full admin (`morgajanrafael1793@gmail.com`) | Farmer |
|---------|----------------------------------------|---------------------------------------------|--------|
| **PineSight Admin** | Reports, Analytics, map view — **no** Users/Fields/bulk tools | Everything | Not authorized |
| **Mobile app** | **DA • all farms**, Farmer reports | **Admin • all farms**, DA access requests, Farmer reports | Own fields only; **More → Request DA access** |

---

## DA can do

- View all farmer fields on the map (read-only popups)
- Open **Reports** and write **DA advice** per positive capture
- View **Analytics** (counts, charts)

## DA cannot do

- Create/delete users
- Create/edit fields, boundaries, or owners
- Bulk assign/move captures or change capture owners
- Multi-select / drag capture pins on the map

---

## Quick test flow (15 minutes)

1. **Farmer** (`morillo3580225@gmail.com`): scan on **Angelei** → save.
2. **`rgist45@gmail.com`**: **More → Request DA access** → admin **Approve** (web or mobile) → sign out/in.
3. **DA** (`rgist45@gmail.com`): Reports → Pending reply → Save advice.
4. Confirm DA web: **no Users/Fields**; admin (`morgajanrafael1793@gmail.com`): **Users** visible.
5. **Farmer**: same capture → **Expert advice from DA/OMAG**.

---

## Supabase project

- **URL:** `https://sjdcnkendlgqbxxjdqml.supabase.co`
- **Migration:** `20260612120000_da_staff_jwt_role.sql` — DA read policies + staff expert-response write

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Admin web says “Not authorized” | Set `da: true` or `admin: true`; sign out/in |
| DA still sees Users / Fields | Hard refresh (`Ctrl+F5`); confirm JWT has `da` not `admin` |
| Mobile admin sees no pending requests | Tap refresh on **DA access requests** card; confirm signed in as full admin |
| Mobile still farmer-only | Sign out/in after metadata change |
| DA reply save fails | Confirm `expert_responses` policies and `author_id` = signed-in user |
| Farmer sees no advice | Capture must be **positive** and synced; DA must save reply |
