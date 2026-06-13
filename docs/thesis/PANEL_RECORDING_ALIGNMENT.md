# Panel Recording Alignment — Ma'am Jan & Sir Jude

**Updated:** June 13, 2026  
**Purpose:** Map panel verbal guidance to implementation status, demo shots, and thesis wording.

**Related:** [`PANEL_FEATURE_CHECKLIST.md`](PANEL_FEATURE_CHECKLIST.md) · [`VIDEO_DEMO_GUIDE_2026-06-12.md`](VIDEO_DEMO_GUIDE_2026-06-12.md) · [`THESIS_PASTE_BLOCKS.md`](THESIS_PASTE_BLOCKS.md)

---

## One-sentence positioning (say in opening)

> PINYA-PIC is an **assistive mealybug detection collector and decision-support middleware**: farmers capture leaf images as before; each upload becomes a **centralized report**; **positive** sightings feed DA/OMAG maps and analytics; authorities **mediate** with per-case advice; the on-device model is an **initial pilot**, not deployment-ready.

---

## Ma'am Jan — alignment

| # | Panel guidance | Built? | Demo / thesis |
|---|----------------|--------|---------------|
| 1 | Present **limitations** (low metrics) | Docs ✅ | Say: 73.3% mAP@0.5, 64.7% recall, 40.7% mAP@0.5:0.95 — below targets |
| 2 | **Careful conclusion/discussion** | Thesis ⬜ | Use Ch IV–V paste blocks; avoid deployability claims |
| 3 | **Magdagdag ng information** | App ✅ | Expert advice, analytics, roles, heatmap — describe in Ch IV |
| 4 | **Data visualization** | App ✅ | Heatmap, pins, Reports cards, Analytics chart |
| 5 | **Middleware** → authorized user | App ✅ | Auto-sync; DA/Admin review queue |
| 6 | Field consolidation → DA/OMAG | App ✅ | Positive sightings per field → org map |
| 7 | Authorities gather reports for **mediation** | App ✅ | Reports + Pending reply + Save advice |
| 8 | Farmers see **own** maps (positive instances) | App ✅ | Own fields; positive-only on full map |

---

## Sir Jude — alignment

| # | Panel guidance | Built? | Demo / thesis |
|---|----------------|--------|---------------|
| 1 | **Detection collector** | App ✅ | One row per upload in `detections` |
| 2 | **Transparent** — not always positive | App ✅ | Positive/Negative badges; negatives not on map |
| 3 | Recommend better annotations/datasets | Docs ✅ | Ch V recommendation #3–#5 |
| 4 | Consolidate by field → authorities → remedy | App ✅ | Field + GPS + `expert_responses` |
| 5 | **Remediation** vs modeling emphasis | Partial | Per-image DA advice ✅; farm insight admin-only |
| 6 | DA/OMAG map of **all** farmer fields | App ✅ | Staff JWT org-wide map |
| 7 | Accredited farmers' reports for superuser | App ✅ | PineSight Admin / DA console |
| 8 | Connect superuser to **existing app** | App ✅ | Web + mobile staff modes |
| 9 | **Initial pilot**, not deployment-ready | App ✅ / thesis ⬜ | Wording audit in abstract & Ch V |
| 10 | Recommendations: act on metrics gap | Docs ⬜ | Paste Ch V from `THESIS_PASTE_BLOCKS.md` |
| 11 | Each scan = **case/report** to superuser | App ✅ | Reports list; optional "Case #" label in UI |
| 12 | DA inputs **strategies** per case | App ✅ | Web Reports + mobile Farmer reports (DA) |
| 13 | **Analytics** — top farms, farmer info | App ✅ | Analytics drawer |
| 14 | Table + farmer **feedback** visualization | Partial | Reports cards ✅; PDF/CSV export ❌ |
| 15 | Heatmap/distribution **positive only** | App ✅ | Mobile + admin map rules |

---

## End-to-end middleware loop (panel story)

```
Farmer scan → auto-report → DA consolidates (map/analytics/reports)
→ DA writes strategy → farmer reads Expert advice
```

| Step | Role | Surface |
|------|------|---------|
| 1 | Farmer | Mobile: Scan → Save |
| 2 | System | Supabase `detections` sync |
| 3 | DA/Admin | Web Reports or mobile queue |
| 4 | DA | Save advice on positive capture |
| 5 | Farmer | Capture detail → Expert advice card |

---

## Demo shot order (matches panel)

1. Limitations line (15 sec)
2. Farmer: scan, save, own map (positives)
3. DA web: Reports + Analytics + read-only map
4. Admin web: Users + Fields (brief)
5. Farmer: Expert advice card
6. *(Optional)* DA approval workflow

Full script: [`VIDEO_DEMO_GUIDE_2026-06-12.md`](VIDEO_DEMO_GUIDE_2026-06-12.md)

---

## Thesis work remaining (not code)

| Priority | Task | File |
|----------|------|------|
| P0 | Paste limitations + conclusion into Word | `THESIS_PASTE_BLOCKS.md` Ch IV–V |
| P0 | Abstract middleware framing | Same file, Abstract |
| P0 | Panel response letter finalize | `PANEL_REVISION_RESPONSE_DRAFT.md` |
| P1 | Architecture diagram (middleware) | `SYSTEM_ARCHITECTURE.md` |
| P1 | APA 7 figure/table captions | `THESIS_FIGURES_TABLES_ERRATA.md` |

---

## Gaps (optional post-defense)

- PDF/CSV export from admin UI
- Farmer mobile UI for farm-level DA insights
- Formal "Case #" numbering in Reports UI
- In-app chat / AI assistant

---

## What to say / not say

**Say:** collector, middleware, assistive, initial pilot, positive-only map, expert mediation, transparent metrics.

**Do not say:** deployment-ready, diagnostic-grade, replaces DA inspection, heatmap includes negatives.
