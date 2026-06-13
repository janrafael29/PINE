# PineSight Admin — UI/UX Redesign Plan

**Updated:** June 13, 2026  
**Live URL:** https://celadon-mochi-48bf70.netlify.app  
**Reference:** [Data-to-Viz](https://www.data-to-viz.com/) chart families (comparisons, proportions, location, evolution)

---

## Goal

Redo the admin console so it feels **modern, engaging, and decision-focused** for DA/OMAG staff — not a raw data table behind a map. The app is **detection collector + middleware**: visuals must emphasize **positive outbreak signals** while negatives stay in audit views.

---

## Current state (June 2026)

| Area | Today | Gap |
|------|-------|-----|
| Layout | Map-first + right drawer | Analytics buried in drawer; no dedicated dashboard home |
| Charts | 7-day bar + top-farms table | Missing proportions, multi-series trends, field comparison charts |
| Map | Leaflet heatmap + pins | Strong — matches **Location** family |
| Visual design | Olive/cream mobile theme on dark map shell | Feels utilitarian; drawer typography dense |
| Chart.js | v4.4.1 CDN | Enough for Phase 1–2; D3 only if we need Sankey/Treemap later |

---

## Chart catalog → PineSight use cases

Mapped from your reference images to **real admin data** (`detections`, `fields`, `profiles`, `expert_responses`).

### Location (geographical)

| Chart type | Admin use | Status |
|------------|-----------|--------|
| **Choropleth map** | Field-level outbreak intensity (positive count per geofence) | ✅ Heatmap layer |
| **Dot map** | Individual positive capture pins when zoomed in | ✅ Pin layer |
| **Bubble map** | Sized circles = sighting count per field centroid | 🔲 Phase 2 |
| **Connection map** | Spread between neighboring positive fields | 🔲 Stretch |
| **Flow map** | Movement of reports over time (unlikely — static captures) | ⏭ Skip |

### Comparisons (differences between values)

| Chart type | Admin use | Status |
|------------|-----------|--------|
| **Bar chart** | Daily positive count (7-day) | ✅ Phase 1 |
| **Horizontal bar** | Top farms by positive sightings | ✅ Phase 1 |
| **Line graph** | 30-day positive trend | ✅ Phase 1 |
| **Stacked bar** | Positive vs negative per week | 🔲 Phase 2 |
| **Heatmap** | Day-of-week × hour report volume | 🔲 Phase 2 |
| **Population pyramid** | Not applicable (single pest class) | ⏭ Skip |
| **Radar chart** | Multi-metric field score (sightings, recency, pending DA reply) | 🔲 Phase 3 |

### Proportions (parts of a whole)

| Chart type | Admin use | Status |
|------------|-----------|--------|
| **Donut chart** | Positive vs negative scans (all uploads) | ✅ Phase 1 |
| **Pie chart** | Same as donut — pick one | ⏭ Use donut only |
| **Treemap** | Share of positives by field (top N + Other) | 🔲 Phase 2 |
| **Stacked bar (100%)** | Field contribution to org-wide positives | 🔲 Phase 2 |

### Evolution (change over time)

| Chart type | Admin use | Status |
|------------|-----------|--------|
| **Line / area** | Positive trend 7d / 30d / 90d | ✅ Phase 1 (line) |
| **Timeline** | Expert reply turnaround per capture | 🔲 Phase 3 |
| **Gantt** | Not applicable | ⏭ Skip |

### Distribution (spread of values)

| Chart type | Admin use | Status |
|------------|-----------|--------|
| **Histogram** | Confidence score distribution (when box JSON synced) | 🔲 Future |
| **Box plot** | Detections per field distribution | 🔲 Phase 3 |

---

## Redesign phases

### Phase 1 — Richer analytics (now)

- Donut: positive vs negative proportion  
- Line: 30-day positive trend  
- Horizontal bar: top 8 farms  
- Viz legend: which chart family each panel uses  
- Files: `admin/app.js`, `admin/styles.css`

### Phase 2 — Dashboard shell

- **Home** tab: KPI row + 2×2 chart grid (not only drawer)  
- Date range filter (7d / 30d / 90d / all) on analytics  
- Treemap or stacked bar for field share  
- Bubble map layer option on Leaflet  
- Wider drawer / optional full-screen analytics mode

### Phase 3 — Modern visual system

- New design tokens (spacing, elevation, motion) aligned with mobile brand  
- Card-based sidebar sections with icons  
- Empty states and skeleton loaders  
- Responsive: tablet-friendly drawer; mobile DA read-only view  
- Optional dark/light toggle (map stays dark)

### Phase 4 — Engagement & export

- CSV/PDF export from analytics  
- “Pending DA reply” bullet graph  
- Field comparison radar for panel demo  
- Animated chart transitions (Chart.js plugins)

---

## Layout concept (target)

```
┌─────────────────────────────────────────────────────────────┐
│  PineSight Admin          [Users] [Fields] [Reports] [Analytics ▼] │
├──────────┬──────────────────────────────────────────────────┤
│ Sidebar  │  MAP (choropleth / dots)                          │
│ KPIs     │                                                   │
│ Scope    │                                                   │
│ Layers   │                                                   │
├──────────┴──────────────────────────────────────────────────┤
│  Analytics strip (collapsible): donut | trend | top farms    │
└─────────────────────────────────────────────────────────────┘
```

---

## Rules (do not break)

1. **Map + analytics = positive only** (`has_mealybugs == true`).  
2. **Reports table = all uploads** (positive + negative).  
3. Donut includes negatives; map never does.  
4. Copy stays non-diagnostic (“sightings”, not “confirmed infestation”).  
5. DA read-only: hide admin-only drawers (`data-admin-only`).

---

## Deploy after UI changes

```powershell
cd d:\old_PINE
.\scripts\deploy_admin_web.ps1 -Target netlify -Prod
```

---

## Related

- [`PANEL_FEATURE_CHECKLIST.md`](PANEL_FEATURE_CHECKLIST.md) — section M (admin UI redesign)  
- [`APP_IMPLEMENTATION_REPORT_2026-06-12.md`](APP_IMPLEMENTATION_REPORT_2026-06-12.md)  
- [`ADMIN_WEB_DEPLOY.md`](ADMIN_WEB_DEPLOY.md)
