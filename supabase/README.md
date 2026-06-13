# Supabase (**PINYA-PIC** / PINE)

**App-side context:** This folder documents **database, RLS, Storage, and Realtime** for the Flutter app. For **clone → Flutter → model → run** (including on-device YOLO, navigation guide, and UI flows), use the repo root **`RUN.md`**.

## Setup order (do once per project)

1. **Create** a Supabase project.
2. **Auth → Phone:** enable the Phone provider and configure your SMS provider (Twilio, etc.). Without this, OTP login in the app will not send codes.
3. **SQL Editor** — run migrations **in order:**
   - `migrations/20250320000000_initial_schema.sql` (tables, RLS, storage buckets + policies)
   - `migrations/20250321000001_enable_realtime.sql` (adds tables to `supabase_realtime` so Flutter `.stream()` works)
   - `migrations/20250322000000_drop_plots.sql` (removes `plots` and field-plot columns — run if your project was created from the older schema that included plots)
4. **Verify** — run `verify_setup.sql` in the SQL Editor and confirm every check is **OK** (see below).
5. **Run the app** with compile-time keys (no secrets in git):

```bash
flutter run --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

**PowerShell:** use backtick `` ` `` for line breaks, not `^`. Do not wrap the anon key in `<` `>`.

---

## Double-check Supabase is complete

### A) SQL verification (database + storage + realtime)

In **SQL Editor**, open and run the whole file:

**`verify_setup.sql`**

You should see:

| Section | What “good” looks like |
|--------|-------------------------|
| Core tables | Three rows (`profiles`, `fields`, `detections`), all `OK` |
| RLS | Three tables, `OK (RLS on)` |
| Policy counts | Nonzero policies on `profiles`, `fields`, `detections` |
| Storage | Rows for buckets `detections` and `avatars` |
| Storage policies | Several policies named with `detections` / `avatars` |
| Realtime | Three tables `OK (in supabase_realtime)` |

If **Realtime** shows `FAIL`, run `migrations/20250321000001_enable_realtime.sql` (or enable those tables under **Database → Publications → supabase_realtime**).

### B) Dashboard checks (not in SQL)

| Check | Where |
|--------|--------|
| Phone sign-in enabled | **Authentication → Providers → Phone** |
| SMS provider configured | Same screen (provider credentials) |
| API keys for the app | **Project Settings → API** — use **Project URL** and **anon public** key with `--dart-define` |

### C) Flutter connectivity test

```bash
flutter test test/integration/supabase_connection_test.dart --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

---

## Tables and buckets

- **Tables:** `profiles`, `fields`, `detections` (see migrations; `plots` was removed in `20250322000000_drop_plots.sql`).
- **Storage buckets:** `detections`, `avatars` (created by migration).

If the migration is not applied yet, the integration test may still pass with a specific “table missing” handling, or fail until SQL is applied — prefer running **`verify_setup.sql`** after migrations.
