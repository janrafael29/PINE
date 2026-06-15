# PINYA-PIC — Use Case Diagram (updated June 2026)

**Purpose:** Replace the older **User / Superuser** diagram with the **panel-aligned** system: detection collector, three roles, DA advice loop, and PineSight Admin web.

**Source files (draw or export figures from these):**

| File | Tool |
|------|------|
| [`docs/diagrams/PINYA_PIC_ALL_DIAGRAMS.md`](../diagrams/PINYA_PIC_ALL_DIAGRAMS.md) | **All diagrams in one shareable Markdown file** |
| [`docs/diagrams/use_case_diagram.puml`](../diagrams/use_case_diagram.puml) | **PlantUML** — classic UML ovals (best for thesis figure) |
| [`docs/diagrams/use_case_diagram.mmd`](../diagrams/use_case_diagram.mmd) | **Mermaid** — quick preview in VS Code / GitHub |

**Related:** [`PANEL_APP_PROGRESS_REPORT_2026-06-13.md`](PANEL_APP_PROGRESS_REPORT_2026-06-13.md) · [`PANEL_RECORDING_ALIGNMENT.md`](PANEL_RECORDING_ALIGNMENT.md)

---

## Chapter III disclaimer (paste with figure)

> The use case diagram presents the primary functional capabilities of PINYA-PIC as a **detection collector and reporting middleware**. Optional paths (offline sync retries, error dialogs, navigation guide) and detailed sequence logic are described in Sections 3.3–3.4 and are not every branch on this figure.

---

## Actors (4)

| Actor | Description | Primary client |
|-------|-------------|----------------|
| **Farmer** | Owns fields; captures leaf photos; reads DA advice | Flutter mobile |
| **DA Staff** | Reviews org-wide positive reports; writes advice; views analytics — **does not capture** | Flutter mobile + web |
| **Full Admin** | All DA capabilities + approves DA access + user/field admin | Flutter mobile + web |
| **PineSight Web Admin** | *(Optional fourth actor)* Browser UI for map, Reports, Analytics, Users | Netlify static admin |

**Note:** In the bound thesis you may **merge DA Staff + Full Admin** into one stick figure **“DA / OMAG Authority”** with a footnote for admin-only cases, if the panel prefers a simpler drawing.

---

## Use cases by actor

### Farmer

| Use case | Maps to app |
|----------|-------------|
| Register Account | `register_screen.dart` — farmer or staff intent |
| Login / Logout | Supabase Auth |
| Manage Profile | `profile_screen.dart`, settings, language, dark mode |
| Request DA Access | More → DA/OMAG access (staff applicants who register as farmer first) |
| View Access Request Outcome | Notification dialog + More tab badge |
| Create / Edit / View Field | `fields_list_screen.dart`, `edit_field_screen.dart`, `field_detail_screen.dart` |
| Delete Field | Field detail (optional) |
| Edit Field Boundary | Map / geofence editor |
| Manage Field Photos | `manage_field_photos_screen.dart` |
| Select Field for Scan | Pre-scan field picker |
| Capture Image → Detect Mealybugs | `permission_screens.dart` / detection flow + TFLite |
| Save Capture & Submit Report | SQLite + `cloud_sync_service.dart` → `detections` row |
| View Capture History | `captured_photos_screen.dart` — Positive / Negative badges |
| View Capture Detail | `captured_photo_detail_screen.dart` |
| Read Expert Advice | Expert reply block on capture detail |
| View Diagnose Dashboard | Diagnose tab — weekly stats + pest chart |
| Browse Disease Information | `disease_info_screen.dart` |
| View Map / Home preview | `detections_map_screen.dart`, `home_map_preview_section.dart` |
| Submit Feedback | `feedback_screen.dart` |

### DA Staff

| Use case | Maps to app |
|----------|-------------|
| View Staff Dashboard | Home tab `_StaffHomePanel` |
| View Org Analytics | Diagnose tab `StaffAnalyticsPanel` |
| Review Farmer Reports (by Field) | `admin_reports_screen.dart` — expandable field groups |
| Write Expert Advice | Capture detail or web Reports drawer |
| View Farmer Feedback | Admin/staff feedback views |
| View Detections Map / Outbreak viz | Map — positive detections, severity coloring |
| Login / Manage Profile | Same auth; **no camera** on center nav |

### Full Admin (additional)

| Use case | Maps to app |
|----------|-------------|
| Review / Approve / Reject DA Access | `da_access_requests_screen.dart`, web Users drawer |
| Manage Users | Web admin + edge functions |
| Write Farm-Level Insight | Web Fields drawer → `farm_insights` |

### PineSight Web Admin (optional actor)

| Use case | Maps to app |
|----------|-------------|
| Reports Drawer (field groups) | `admin/app.js` captures drawer |
| Analytics Drawer | Trend / donut / top farms |
| Fields / Users Drawers | Full admin map + CRUD |

---

## Include relationships (`<<include>>` — mandatory sub-step)

| Base use case | Includes |
|---------------|----------|
| **Capture Image** | **Detect Mealybugs (on-device)** |
| **Save Capture & Queue Sync** | **Capture Image** |
| **Save Capture & Queue Sync** | **Submit Report to Cloud** |
| **View Diagnose Dashboard** | **View Weekly Pest Chart** |
| **Review Farmer Reports** | **View Capture Detail** |
| **Write Expert Advice** | **View Capture Detail** |

---

## Extend relationships (`<<extend>>` — optional)

| Extension | Extends |
|-----------|---------|
| **Delete Field** | View Fields / Field Detail |
| **Edit Field Boundary** | View Field **or** Edit Field |
| **Read Expert Advice** | View Capture Detail *(only when reply exists)* |
| **Write Expert Advice** | Review Farmer Reports *(only for positive / pending)* |
| **Approve / Reject DA Access** | Review DA Access Requests |

---

## What changed from the old diagram

| Old (User / Superuser) | New (June 2026) |
|------------------------|-----------------|
| 2 actors | **3 roles** (+ optional web actor) |
| “Capture Image” only | **Detect + auto cloud report** |
| Superuser creates own account | **DA registers → admin approves** |
| Superuser can capture | **Staff must not use camera** |
| Flat “View User Reports” | **Review reports by field**, pending queue, advice per image |
| Missing feedback loop | **Write advice → farmer reads on capture** |
| “Remove Field Boundary” included everywhere | **Edit boundary** is optional **`<<extend>>`** |
| Floating “View Fields and Instances” | Folded into **View Fields / Map / Analytics** |

---

## Draw.io / Lucidchart checklist

1. Draw **system boundary** rectangle: *PINYA-PIC: Mealybug Detection Collector*.
2. Place **3 stick figures**: Farmer (left), DA Staff (right), Full Admin (right, below or generalization line from DA).
3. *(Optional)* Fourth figure: **PineSight Web Admin** outside mobile boundary or inside as separate package.
4. Group ovals into **packages** (Account, Fields, Capture, Diagnose, Map, Staff, Admin) — match PlantUML file.
5. Solid lines: **actor → use case** (association).
6. Dashed arrow **`<<include>>`**: base → included (arrow to included case).
7. Dashed arrow **`<<extend>>`**: extension → base (arrow to base case).
8. Add **note** on DA Staff: *No camera on mobile; review queue only.*
9. Add **note** on Submit Report: *Positive → map; negative → table only.*
10. Export as **PNG/SVG** for List of Figures — suggest label: **Figure X. Use Case Diagram of PINYA-PIC**.

---

## Suggested thesis caption

**Figure X.** Use case diagram of the PINYA-PIC mealybug detection collector showing farmer capture and reporting, DA/OMAG review and advice, and full-administration functions across the mobile application and PineSight Admin web console.

---

*Last updated: 13 June 2026.*
