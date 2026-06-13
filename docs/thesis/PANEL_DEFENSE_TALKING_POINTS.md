# Panel Defense — Talking Points

**Updated:** June 12, 2026

---

## One-paragraph positioning

PINYA-PIC is a **mealybug detection collector and agricultural decision-support middleware**. Farmers upload geotagged images that are analyzed on-device; every scan is logged, but only **confirmed positive detections** feed outbreak maps and authority-facing analytics. DA/OMAG staff log in as **superuser** (web or mobile), review consolidated per-farm reports, use analytics to spot high-sighting areas, and **reply with remedial guidance** that farmers see on the same capture. The YOLO26 v16 model demonstrates feasibility but remains a **research prototype** — recall and strict localization are below deployability thresholds despite extensive revision work (v20–v22).

---

## Demo script (8 steps)

1. Farmer scans leaf → report auto-saves.
2. History list → positive **and** negative rows with badges.
3. DA superuser login → sees farmer field and image.
4. Map zoomed out → field heatmap (no pin clutter).
5. Map zoomed in → positive pins only.
6. Analytics → top farms, counts, 7-day chart.
7. DA saves advice on a positive report.
8. Farmer opens same capture → sees DA/OMAG advice card.

Close with limitations slide — **not deployment-ready**.

---

## Metrics (honest)

| Metric | v16 | Panel target |
|--------|-----|--------------|
| mAP@0.5 | 73.3% | ≥85% |
| Recall | 64.7% | ≥80% |
| mAP@0.5:0.95 | 40.7% | ≥55% |
| Precision | 80.6% | ≥80% |

---

## What we do NOT claim

- Model is **not** deployment-ready.
- App does **not** diagnose plant health or replace extension officers.
- Negative scans are **not** hidden — only excluded from outbreak **map/analytics**.

---

## Superuser setup

See [`DA_SUPERUSER_SETUP.md`](DA_SUPERUSER_SETUP.md).
