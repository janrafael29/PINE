# PINYA-PIC — Defense Flashcards

Print double-sided or cover the answer column while practicing aloud.  
**App name:** PINYA-PIC · **Repo/package:** pine · **Version:** 12.2.0+2035

---

## Opening & scope

### Q1. What is PINYA-PIC in one sentence?
**A:** Offline-first Android app that detects **mealybugs on leaves** with an on-device **YOLO TFLite** model, tags **GPS/field** context, stores data **locally first**, and **syncs to Supabase** when online.

### Q2. Who is it for?
**A:** Farmers, field enumerators, and researchers monitoring **pineapple/agricultural** pest pressure — especially where **connectivity is poor**.

### Q3. What problem does it solve?
**A:** Manual mealybug scouting is slow and inconsistent; tiny pests are hard to see and count. The app gives **repeatable counts**, **geo-tagged records**, and **offline operation** in the field.

### Q4. What is it *not*?
**A:** Not live video pest tracking; not a general plant-ID app; not cloud-required for detection; not multi-class production model today (**mealybug** primary).

---

## Architecture

### Q5. Name the four layers.
**A:** **Presentation** (Flutter screens/widgets) → **Core** (config, DI, Supabase provider, theme) → **Services** (ML, DB, sync, geo) → **Data** (SQLite, SharedPreferences, Supabase Postgres/Storage).

### Q6. How do services get dependencies?
**A:** Minimal **`ServiceLocator`** singletons registered in `main.dart` — not `get_it`; intentional simplicity.

### Q7. What global state exists?
**A:** **`AppState`** via **Provider**: login flag, **en/fil** language, **dark mode**, **inference accuracy mode**, captured-photos revision.

### Q8. What happens if Supabase keys are missing at build?
**A:** App shows **`ConfigRequiredScreen`** — no full dashboard until `--dart-define=SUPABASE_URL` and `SUPABASE_ANON_KEY` are provided.

---

## Machine learning

### Q9. Where is the model and how big?
**A:** `assets/model/best.tflite`, about **5.2 MB** bundled in the APK (no download at runtime).

### Q10. Model input/output shape?
**A:** Input **`[1, 640, 640, 3]`** float32; output **`[1, 300, 6]`** (boxes + scores per row).

### Q11. What class does it detect?
**A:** **`mealybug`** (`InferenceService.classLabels`); extensible by retraining + label list.

### Q12. Default confidence threshold?
**A:** **`0.20` (20%)** — `AppConstants.detectionThreshold`. **Not 30%** (fix thesis if it says 30%).

### Q13. Default NMS IoU?
**A:** **`0.45`** — greedy NMS in **Dart** (`nmsMergedDetections`), because export uses **`nms=False`**.

### Q14. Why is NMS in the app, not in TFLite?
**A:** Consistent parsing of fixed output tensor; thresholds tunable in code without re-exporting the model.

### Q15. Why letterbox to 640×640?
**A:** Preserves aspect ratio; pad gray **114** (Ultralytics standard); avoids stretching that shrinks apparent pest size.

### Q16. Why run inference in an isolate?
**A:** Tiled/large images can take seconds; **`Isolate.run`** prevents UI freeze and **ANR** on low-RAM phones.

### Q17. What is “Accuracy mode” in Settings?
**A:** Switches to **`AppConfig.accuracy()`**: lower threshold (**0.085**), looser NMS (**0.62**), **tiling** on, **TTA** (horizontal flip) — higher recall, slower.

### Q18. What is tiled inference?
**A:** Sliding-window on **native-resolution crops** when the image is large; merges detections + global NMS — helps **tiny distant** pests.

### Q19. YOLO11 vs YOLO26 — what do you say?
**A:** Be explicit: **archived training metrics** (thesis tables) may be **YOLO11**; **deployed APK** ships **`best.tflite`** from **YOLO26n** export pipeline in `RUN.md` / `scripts/retrain_yolo.py`.

### Q20. Why not cloud inference?
**A:** **Offline farms**, **privacy**, **latency**, **cost**, predictable behavior without signal.

---

## Detection UX

### Q21. Camera vs gallery?
**A:** Both via **`image_picker`**; rear camera, **quality 100**; gallery may use **EXIF GPS** or map pin.

### Q22. Live video detection?
**A:** **No** — **still-image** pipeline only.

### Q23. What does the user see after scan?
**A:** Bounding boxes, **count**, confidence %, optional **“what to do next”** (EN/Fil), save to field.

### Q24. User sees 0 pests but pests are visible — what do you say?
**A:** Suggest **Accuracy mode**, better light, steady shot, leaf filling frame; threshold tradeoff (recall vs false positives).

---

## Location & geofencing

### Q25. What is “geofencing” in your app?
**A:** **Point-in-polygon** (ray casting) — *not* Android background geofence APIs.

### Q26. Where are field boundaries stored?
**A:** Supabase **`fields.boundary_json`**; mirrored locally (**`land`**, **`field_cache`**).

### Q27. What if GPS fails?
**A:** Error/retry; gallery may use EXIF; optional **map picker**; some cloud saves use **random point inside field polygon** when GPS weak (document as design choice).

### Q28. Why polygons not circles?
**A:** Real farm plots are **irregular**; polygons match user-drawn boundaries on the map.

---

## Data & sync

### Q29. Local database name and version?
**A:** **`pine.db`**, schema version **12**.

### Q30. Main local tables?
**A:** **`captured_photo`** (primary captures), **`upload_queue`** (pending sync), **`field_cache`**, plus legacy **`land`** / **`detection`**.

### Q31. Cloud tables?
**A:** **`profiles`**, **`fields`**, **`detections`** (+ Storage buckets **`detections`**, **`avatars`**).

### Q32. Offline-first — exact meaning?
**A:** **Inference + local save always work**; **`upload_queue`** holds pending rows until **auth + network**; then **`CloudSyncService`** uploads.

### Q33. How does the app know it is online?
**A:** **`connectivity_plus`** + **DNS lookup** (`example.com`, 2 s timeout) in **`NetworkReachability`**.

### Q34. Sync failure handling?
**A:** Increment **`attempts`**, store **`last_error`**; manual sync shows progress; stops after **stuck batches** if count never drops (missing files).

### Q35. Row Level Security?
**A:** Postgres **RLS**: users only **SELECT/INSERT/UPDATE/DELETE** their own rows (`auth.uid()`).

### Q36. Admin users?
**A:** JWT **`app_metadata.admin = true`** — extra policies to read/update across users (research/admin tooling).

---

## Security & ethics

### Q37. Can User A see User B’s photos?
**A:** **No** under normal accounts — RLS + Storage path **`{userId}/...`**.

### Q38. Where are Supabase secrets?
**A:** **`--dart-define`** at run/build — **not** committed to git.

### Q39. Optional extra lock?
**A:** **`UnlockGate`** — biometric/device unlock **once per app run** after login if enabled.

### Q40. Research data sharing?
**A:** **`statistician_anonymized_export.sql`** — pseudonymous IDs with **private salt**; images still need ethical review (see `STATISTICIAN_EXPORT_ANONYMIZED.md`).

---

## Severity & dashboard

### Q41. Severity formula?
**A:** `raw = bugCount × (confidencePct/100)`; `s = 1 - exp(-raw/k)` with **`k = 8`**; maps to green→red for markers.

### Q42. Is severity the same as model confidence?
**A:** **No** — UI aggregate of **count × confidence**, saturating curve for map glow.

---

## Tech choices

### Q43. Why Flutter?
**A:** Fast UI iteration, rich plugins (camera, maps, TFLite), single codebase; **Android** is primary target.

### Q44. Why Supabase over Firebase?
**A:** **Postgres + SQL + RLS**, relational **fields/detections**, SQL export for researchers.

### Q45. Why SQLite?
**A:** Relational queries, indexes, migrations (v1→12), offline queue — fits structured sync model.

---

## Limitations & future work

### Q46. Top three limitations?
**A:** (1) **Single-class** mealybug model, (2) **still images only**, (3) **lighting/blur/GPS** affect real-world accuracy.

### Q47. Future work?
**A:** Multi-class pests, field validation studies, optional model updates, iOS, active learning from synced labels, edge hardware.

### Q48. Biggest technical challenge?
**A:** **Small-object detection** on phone photos + **offline sync** + **calibrated thresholds** for field conditions.

---

## Thesis alignment (if challenged)

### Q49. Thesis says 30% threshold?
**A:** **Incorrect for deployed app** — code uses **0.20**; corrected per `THESIS_FIGURES_TABLES_ERRATA.md`.

### Q50. Table says “edit field via long-press”?
**A:** App uses **edit button/menu** — fix table to match UI and §4.2.4 narrative.

---

## Quick numbers (rapid fire)

| Item | Answer |
|------|--------|
| Input size | 640 |
| Default threshold | 0.20 |
| Default NMS | 0.45 |
| SQLite version | 12 |
| Deep link | pine://reset-password |
| Re-onboarding after | 14 days inactive |
| Default class | mealybug |

---

*Practice: pick 10 random cards, answer in ≤30 seconds each, then demo the app once without looking.*
