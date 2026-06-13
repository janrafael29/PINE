# PINYA-PIC — Thesis diagram pack (B-series) + Mermaid source

Official **B-series** labels for Chapter III figures, **inclusion policy**, and paste-ready **Mermaid** blocks aligned with `d:\old_PINE`.

---

## Chapter 3 — required disclaimer (paste verbatim)

Use this sentence in **Chapter III** (figure overview or methodology intro):

> The diagrams presented are logical representations of the system workflows and architecture. Certain optional branches, asynchronous operations, and error-handling paths are described in detail in Sections 3.3–3.4 and are not fully expanded in the diagrams to maintain clarity.

---

## B-series index (code ↔ thesis figure ID)

| ID | Title (for List of Figures) | Mermaid section below |
|----|-----------------------------|------------------------|
| **B1** | Diagnose Tab: Data Loading and Visualization Flow | § B1 |
| **B2** | Seven-Day Chart Processing Flow (sub-pipeline) | § B2 — *optional; omit if B1 suffices* |
| **B3** | Application Launch, Session, and User Initialization Flow | § B3 |
| **B4** | Image Capture and Detection Pipeline | § B4 |
| **B5** | Cloud Synchronization and Queue Processing Flow | § B5 *(primary)* |
| **B6** | Domain Model and Data Storage Relationships | § B6 |
| **B7** | Application Architecture: UI–State–Service Interaction Loop | § B7 |
| **B8** | High-Level System Architecture (Three-Layer Model) | § B8 |
| **B9** | Field Management Workflow | § B9 |
| **B10** | Feedback Submission Workflow | § B10 |
| **B11** | Profile Management and Preferences Flow | § B11 |
| **B12** | Deployment Topology (Mobile–Local–Cloud) | § B12 |
| **B14** | *Reserved* — assign to a non-Mermaid figure if needed (e.g. Gantt, ERD screenshot, deployment photo). No Mermaid block in this file. | — |

**Do not use in thesis:** the simplified B5 variant in § “B5 variant (not for thesis)” — it duplicates **B5** and weakens the panel story.

---

## What to include in the bound thesis (recommended)

**Core (must include):** B1, B3, B4, B5, B7, B9  

**Supporting (include if page budget / adviser asks):** B6, B10, B11, B12  

**Optional (only if needed):** B2 (if chart logic is discussed separately from B1), B8 (if adviser wants a layered view in addition to **B7** — prefer **B7** as the single primary architecture figure to avoid redundancy)

---

## Caption note for **B12** (required)

> This diagram represents **deployment topology** (where components live), not a single **runtime execution** path. On-device inference uses the TFLite asset from application code; SQLite does not “invoke” the model.

---

## B1 — Diagnose Tab: Data Loading and Visualization Flow

```mermaid
flowchart TD
  A[Load detections] --> B{Online?}
  B -->|Yes| C[Supabase realtime / query]
  B -->|No| D[Local SQLite captures fallback]
  C --> E[Merge or fallback dataset]
  D --> E
  E --> F[Compute DashboardStats]
  F --> G[Headline UI: image count, field count, infestation rate]
  F --> H[7-day daily counts series]
  H --> I[Find peak day index on series]
  I --> J[Render smoothed line chart]
  G --> K[Display Diagnose tab]
  J --> K
```

---

## B2 — Seven-Day Chart Processing Flow (sub-pipeline)

*Use only if you discuss chart construction separately; otherwise rely on **B1** only.*

```mermaid
flowchart TD
  A[Detection records with timestamps] --> B[Group counts by calendar day]
  B --> C[Restrict to rolling last 7 days]
  C --> D[Find peak day index]
  D --> E[Render Catmull-Rom smoothed curve]
  E --> F[Display chart]
```

---

## B3 — Application Launch, Session, and User Initialization Flow

```mermaid
flowchart TD
  A[Open app] --> FL{First launch?}
  FL -->|Yes| T[Accept terms]
  FL -->|No| S[Check session]
  T --> S
  S --> L{Logged in?}
  L -->|No| R[Login / Register]
  L -->|Yes| U{Require device unlock?}
  R --> U
  U -->|Yes| G[Device unlock screen]
  U -->|No| D[Go to dashboard]
  G --> D
  D --> N{Has display name?}
  N -->|No| P[Nickname prompt]
  N -->|Yes| C[Continue using app]
  P --> C
```

---

## B4 — Image Capture and Detection Pipeline

```mermaid
flowchart TD
  SC[Scan] --> SRC{Source?}
  SRC -->|Camera| PERM[Request camera permission]
  PERM --> CAP[Capture image]
  SRC -->|Gallery| SEL[Select image]
  CAP --> PRE[Preprocess: EXIF, letterbox 640, normalize]
  SEL --> PRE
  PRE --> INF[YOLO26n TFLite inference]
  INF --> F[Filter scores ≥ 0.20]
  F --> NMS[NMS in Dart]
  NMS --> GEN[Build detection list + overlay data]
  GEN --> DISP[Display results to user]
  DISP --> SAVE[Persist to SQLite captured_photo / related rows]
  SAVE --> LI{Logged in?}
  LI -->|Yes| Q[Enqueue / update upload queue for cloud sync]
  LI -->|No| SK[Skip cloud queue]
  Q --> END[Continue]
  SK --> END
```

---

## B5 — Cloud Synchronization and Queue Processing Flow (PRIMARY)

```mermaid
flowchart TD
  Q[Queue has pending work?] --> L{Logged in?}
  L -->|No| W[Wait]
  L -->|Yes| N{Internet available?}
  N -->|No| W
  N -->|Yes| T[Trigger CloudSyncService]
  T --> P[Process queue items]
  P --> U[Upload to Supabase + Storage as needed]
  U --> S{Success?}
  S -->|Yes| M[Mark synced / dequeue]
  S -->|No| R[Record error / schedule retry]
  R --> Q
  M --> Q2{More pending?}
  Q2 -->|Yes| Q
  Q2 -->|No| E[Idle]
```

### B5 variant (not for thesis — duplicate of B5)

*Do not place in the manuscript; kept here for quick drafts only.*

```mermaid
flowchart TD
  Q[Queue exists] --> L{Logged in?}
  L -->|No| W[Wait]
  L -->|Yes| N{Internet available?}
  N -->|No| W
  N -->|Yes| T[Trigger sync]
  T --> P[Process queue items]
  P --> U[Upload to Supabase]
  U --> S{Success?}
  S -->|Yes| M[Mark synced]
  S -->|No| R[Retry later]
  R --> Q
```

---

## B6 — Domain Model and Data Storage Relationships

*Logical **data placement** / persistence — not a single user click path.*

```mermaid
flowchart TD
  DM[Domain: auth user + profiles] --> F[Fields + boundaries]
  F --> D[Detections metadata]
  D --> L[(SQLite: captured_photo + land + field_cache)]
  D --> Q[(SQLite: upload_queue)]
  Q --> SB[(Supabase: fields + detections rows)]
  SB --> ST[Supabase Storage buckets]
  L -. image bytes .-> FS[Local filesystem]
```

---

## B7 — Application Architecture: UI–State–Service Interaction Loop

*Recommended **primary** in-app architecture figure. Full stack (mobile + Supabase + ML pipeline): `docs/thesis/SYSTEM_ARCHITECTURE.md` §3.1.*

```mermaid
flowchart TD
  UI[UI layer] --> ST[State / controllers Provider + AppState]
  ST --> I[InferenceService]
  ST --> DB[DatabaseService]
  ST --> CS[CloudSyncService]
  ST --> GS[GeoService + GeoFenceService]
  I --> R[Results / model outputs]
  DB --> R
  CS --> R
  GS --> R
  R --> UI
```

---

## B8 — High-Level System Architecture (Three-Layer Model)

*Use only if **B7** alone is insufficient; add `OUT --> UI` if you want an explicit return edge.*

```mermaid
flowchart TD
  UI[UI layer] --> SV[Service layer]
  SV --> LS[Local storage SQLite]
  SV --> CL[Cloud integration Supabase]
  SV --> IE[Inference engine TFLite]
  LS --> OUT[Output to UI]
  CL --> OUT
  IE --> OUT
```

---

## B9 — Field Management Workflow

```mermaid
flowchart TD
  MF[My Fields] --> A{Action?}
  A -->|Create| N[Enter name]
  N --> I[Select preview image]
  I --> M[Define boundary on map]
  M --> SF[Save field]
  A -->|Edit| O[Open field]
  O --> E[Edit via button or menu]
  E --> U[Update data]
  U --> SF
  A -->|View| D[Open details]
  SF --> R[Result / updated list]
  D --> R
```

---

## B10 — Feedback Submission Workflow

```mermaid
flowchart TD
  F[User feedback] --> O{Online?}
  O -->|Yes| S[Submit to server web form]
  O -->|No| E[Email compose or copy address fallback]
  S --> X{Server OK?}
  X -->|No| E
  X -->|Yes| Done[Submitted]
  E --> Done
```

---

## B11 — Profile Management and Preferences Flow

```mermaid
flowchart TD
  P[Profile] --> A{Action?}
  A -->|Edit info| U1[Update profile data]
  U1 --> S1[Save to Supabase profiles]
  A -->|Avatar| U2[Pick or capture image]
  U2 --> S2[Upload to Storage + update profile URL]
  A -->|Language| T1[Toggle EN/FIL immediate AppState]
  A -->|Security| T2[Toggle require device unlock immediate prefs]
```

---

## B12 — Deployment Topology (Mobile–Local–Cloud)

```mermaid
flowchart TD
  MD[Mobile device] --> SQL[SQLite local DB]
  MD --> TF[TFLite model assets]
  SQL --> SYNC[Sync service]
  SYNC --> SB[Supabase cloud]
```

**Caption note:** TFLite runs from app code paths, not from the DB engine; this figure is **topology**, not a single call stack.

---

## B14 — reserved

Assign **B14** in the List of Figures to any **non-Mermaid** asset you already use (e.g. methodology Gantt, ERD, deployment screenshot). There is no Mermaid block for B14 in this repository file by default.

---

*When the app changes, update Mermaid here first, then re-export PNG/PDF for the thesis.*
