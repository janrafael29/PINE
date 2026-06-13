# PINYA-PIC — 5-Minute Defense Demo Script

**Total time:** ~5:00 (buffer 30 s for login if session expired)  
**Goal:** Show **offline ML**, **field context**, and **cloud sync** — the three pillars panelists care about.

**Before you enter the room**
- [ ] Phone charged; **Accuracy mode OFF** first (faster demo), know how to toggle ON if they ask
- [ ] Supabase configured; **test account** logged in once today
- [ ] One **leaf photo with visible pests** ready (camera) + one **clean leaf** optional
- [ ] **Airplane mode** ready to toggle for offline beat
- [ ] Field already created with boundary (or create one night before)
- [ ] Disable notifications; brightness max; **Do Not Disturb**

---

## Minute 0:00–0:30 — Opening (no phone yet)

**Say:**
> “PINYA-PIC is an offline-first Android tool for detecting **mealybugs** on leaves. The **YOLO model runs on the phone** — no internet required to scan. When the user is online, captures **sync to Supabase** for backup and research. I’ll show detection, field linking, and offline behavior.”

**Do:** Unlock phone; app already on dashboard if possible.

---

## Minute 0:30–1:45 — Scan & on-device AI (core contribution)

**Say:**
> “The user taps **Scan** — still photo only, not live video. We use the rear camera at full quality because compression hurts tiny pests.”

**Do:**
1. Tap **Scan** (center bottom nav) → **Camera**
2. Photograph prepared leaf (or open a prepared gallery image)
3. Wait for **inference progress** dialog → result screen

**Say (while boxes appear):**
> “The model is **best.tflite**, bundled at build time — about 5 MB. Input is **640×640 letterboxed**. Default score cutoff is **0.20**, not 0.90, because small pests rarely score that high. **NMS at IoU 0.45** runs in Dart because we export without embedded NMS.”

**Point on screen:**
- Bounding boxes
- **Count** and per-box confidence %
- **“What to do next”** card (management tips)

**If 0 detections:** Switch to Settings → **Detection accuracy mode** ON, rescan — say:
> “Accuracy mode enables tiling and a lower threshold for higher recall at the cost of speed.”

---

## Minute 1:45–2:45 — Save to field + geo context

**Say:**
> “Detections are meaningless without **where** they occurred. We capture GPS and match against **field polygons** using point-in-polygon — not OS background geofences.”

**Do:**
1. Tap **Save** / assign to an existing **field**
2. Confirm field name on summary
3. Open **My Fields** → select that field → show capture in list or map

**Say:**
> “Locally we write to SQLite **`captured_photo`** and enqueue **`upload_queue`**. Boundaries live in **`fields.boundary_json`** in Supabase and mirror offline.”

**Optional 10 s:** Open map on field — point at pin inside boundary.

---

## Minute 2:45–3:30 — Offline proof (high impact)

**Say:**
> “Field connectivity is often poor, so inference and local save must work with **no network**.”

**Do:**
1. Enable **Airplane mode** (or turn off Wi‑Fi/data)
2. Scan **another** image (or re-save flow if UI allows quick re-test)
3. Show it appears under **captured photos** / field list

**Say:**
> “Cloud upload is deferred. The queue status stays **pending** until auth and DNS reachability succeed.”

**Do:** Turn network **back on**.

---

## Minute 3:30–4:15 — Sync & cloud (supporting system)

**Say:**
> “**CloudSyncService** uploads the image to Storage under the user’s folder, then inserts a row in **`detections`** with count, confidence, coordinates, and optional **detections_json** for boxes.”

**Do:**
1. Trigger **Sync** (dashboard or captured-photos sync control — use whatever your build exposes)
2. Briefly show progress if available
3. Optional: Supabase dashboard screenshot in slides if live dashboard is slow

**Say:**
> “**Row Level Security** ensures users only access their own rows. Research exports use a separate **anonymized SQL** script with pseudonymous IDs.”

---

## Minute 4:15–4:45 — Settings & security (30 s)

**Do:** Open **Settings** — point to:
- **Detection accuracy mode**
- **Dark mode** / language (EN/Fil) if time
- Mention **optional biometric unlock** after login

**Say:**
> “Supabase keys are compile-time **dart-define**, not in the repository. Optional **UnlockGate** adds device biometrics once per session.”

---

## Minute 4:45–5:00 — Close

**Say:**
> “In summary: **on-device YOLO** for privacy and offline use, **SQLite-first** persistence, **Supabase** for authenticated sync and research. Limitations include still-image-only capture, single-class deployment, and sensitivity to blur and lighting — addressed partly through user guidance and accuracy mode. Thank you — I’m ready for questions.”

**Stop.** Do not ramble into architecture unless asked.

---

## Backup slides (if demo fails)

| Failure | Backup |
|---------|--------|
| Login expired | Screenshot: result screen with boxes |
| Model slow | Pre-recorded 15 s screen capture |
| No pests in photo | Gallery image known to detect |
| Supabase down | Emphasize offline path only; show SQLite queue in slide |
| Projector only | Walk through `docs/diagrams/detection_flow.mmd` |

---

## Anticipated interruptions — short answers

| Panelist says | You answer (≤15 s) |
|---------------|-------------------|
| “Is this real-time?” | “Still images only; each photo is one inference pass.” |
| “30% threshold?” | “Deployed default is **20%**; thesis errata documents the correction.” |
| “Cloud required?” | “Only for account and sync — not for detection.” |
| “How big is the model?” | “About **5.2 MB** TFLite in assets.” |
| “False positives?” | “Threshold + NMS; accuracy mode increases recall; field validation is human-in-loop.” |

---

## Timing cheat sheet

| Block | Time |
|-------|------|
| Intro | 0:30 |
| Scan + ML | 1:15 |
| Field + geo | 1:00 |
| Offline | 0:45 |
| Sync + security close | 1:30 |
| **Total** | **~5:00** |

---

*Rehearse twice: once with network on, once fully offline after the scan step.*
