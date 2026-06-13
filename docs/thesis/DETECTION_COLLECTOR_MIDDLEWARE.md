# PINYA-PIC — Detection Collector & Decision-Support Middleware

**Updated:** June 12, 2026

---

## 1. System positioning

PINYA-PIC is **not** a deployment-ready field diagnostic. It is a **mealybug detection collector and decision-support middleware** that:

1. Helps farmers capture geotagged leaf images on-device.
2. Runs a lightweight YOLO26 detector (v16) as an **assistive hint** — not a final diagnosis.
3. **Automatically submits** each upload as a per-image report to Supabase.
4. Routes **positive** sightings to outbreak maps and DA/OMAG analytics.
5. Lets DA/OMAG superusers **reply** with treatment advice farmers can read on the same capture.

Farmers keep using the mobile app as-is. Authorities use PineSight Admin (web) and/or mobile admin mode.

---

## 2. Why the shipped model is v16 (YOLO26s)

| Reason | Detail |
|--------|--------|
| Best on locked test | After full revision cycle (v20–v22), **v16 remains best** on corrected held-out test |
| Mobile fit | YOLO26s exported to TFLite (~37 MB) balances size and domain performance |
| Single class | Model detects **mealybugs only** — aligned with panel scope |
| Honest limit | Recall **64.7%** and mAP@0.5:0.95 **40.7%** are **below** panel deployability targets |

See [`MODEL_PERFORMANCE_ALL_VERSIONS.md`](../training/MODEL_PERFORMANCE_ALL_VERSIONS.md).

---

## 3. Limitations (state clearly in thesis)

- **Not deployment-ready** by panel benchmarks (≥85% mAP@0.5, ≥80% recall).
- **Recall gap** — missed infestations remain a scouting risk; farmers must verify visually.
- **Train @ 1280px, deploy @ 640px** — resolution mismatch.
- **Label noise** — historical under-annotation; revision labeling did not close the gap on held-out test.
- **No expert field validation @ operational confidence 0.25** — v13afix expert F1 @ 0.30 only.
- **Middleware role** — system assists and collects; it does not replace DA/OMAG inspection.

---

## 4. Positive vs negative detection

| Type | Rule | Map / analytics | Tables / history |
|------|------|-----------------|------------------|
| **Positive** | Confirmed mealybug count > 0 (`has_mealybugs == true`, conf ≥ 0.25) | Yes | Yes |
| **Negative** | Zero confirmed mealybugs | No | Yes |

Manual-check tier (0.12–0.24) is overlay-only and not counted as positive.

---

## 5. Recall justification (literature angle)

In pest **scouting**, false negatives (missed infestations) are typically more costly than false positives that trigger manual verification. PINYA-PIC therefore prioritizes recall in threshold design, but **benchmark recall still falls short** of the panel target — an honest gap for recommendations.

See [`LITERATURE_mAP_70_78_BAND.md`](LITERATURE_mAP_70_78_BAND.md).

---

## 6. Recommendations (Chapter V)

1. **Expert consultation** — farmers should confirm detections with DA/OMAG before treatment.
2. **Collector features** — per-image reporting, DA analytics, expert reply loop (implemented in app/admin).
3. **More hard-case field imagery** — ≥2,500 images still needed for model improvement (future work).
4. **Expert re-validation** at deploy confidence 0.25.
5. **Do not claim** minimum deployability until metrics meet panel thresholds.
