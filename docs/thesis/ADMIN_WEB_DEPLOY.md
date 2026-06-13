# PineSight Admin — public deploy (not localhost)

**Updated:** June 13, 2026

The admin console is a static site in `admin/` (HTML + JS + CSS).

**Supabase cannot host this UI.** Both Storage and Edge Functions rewrite HTML responses to `text/plain`, so the browser shows source code instead of the login screen. Use **Netlify** (free) for the live demo URL.

---

## Option A — Netlify (recommended)

Permanent public URL. One-time free Netlify account.

### One-time login

```powershell
cd d:\old_PINE\admin
npx netlify-cli login
```

A browser window opens; sign in or create a free Netlify account.

### Deploy

```powershell
cd d:\old_PINE
.\scripts\deploy_admin_web.ps1 -Target netlify -Prod
```

### Live URL (after deploy)

```
https://celadon-mochi-48bf70.netlify.app
```

Bookmark this URL. Re-run the deploy command after any change to `admin/app.js`, `admin/styles.css`, or `admin/index.html`.

### Quick claim (if you already ran an anonymous deploy)

If the CLI printed a **Claim on Netlify** link, open it within 60 minutes to attach the site to your account (removes the temporary password and keeps the URL).

---

## Option B — Local dev

```powershell
cd d:\old_PINE\admin
npx --yes serve -p 8080
```

Open `http://localhost:8080` — hard refresh `Ctrl+F5` after code changes.

---

## Option C — Supabase Storage (backup only, not a live UI)

Uploads files to bucket `pinesight-admin` for backup. **Do not open the Storage or edge-function URL in a browser** — HTML will display as plain text.

```powershell
cd d:\old_PINE
$env:SUPABASE_SERVICE_ROLE_KEY = 'YOUR_SERVICE_ROLE_KEY_HERE'
.\scripts\deploy_admin_web.ps1 -Target supabase
```

---

## Auth notes

- Admin sign-in uses **email + password** (`signInWithPassword`) — no OAuth redirect setup required for the live URL.
- The **anon key** in `config.js` is meant to be public (protected by RLS).
- Never put the **service_role** key in `config.js` or the mobile app — deploy script only.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `Missing admin/config.js` | Copy `config.example.js` → `config.js` and fill values |
| Raw HTML / source code in browser | You are on a Supabase URL — deploy to **Netlify** instead |
| `Authentication required` on Netlify deploy | Run `npx netlify-cli login` first |
| Netlify site asks for password | Anonymous deploy — claim the site or redeploy after `netlify login` with `-Prod` |
| Blank page on live URL | DevTools → confirm `config.js` loaded; hard refresh `Ctrl+F5` |
| Sign-in works locally but not live | Same `config.js` values; sign out/in; confirm staff JWT (`admin` or `da`) |

---

## Related

- [`VIDEO_DEMO_GUIDE_2026-06-12.md`](VIDEO_DEMO_GUIDE_2026-06-12.md)
- [`SMOKE_TEST_2026-06-13.md`](SMOKE_TEST_2026-06-13.md)
- [`DA_SUPERUSER_SETUP.md`](DA_SUPERUSER_SETUP.md)
