# PINYA-PIC — Complete Diagram Pack (single shareable file)

**Date:** 13 June 2026  
**Project:** PINYA-PIC / PineSight — mealybug detection collector (mobile + admin web)  
**Format:** Mermaid blocks — paste into [Mermaid Live](https://mermaid.live), VS Code preview, GitHub, or export PNG for thesis.

---

## How to use this file

1. Share this **one `.md` file** with advisers or panel members.
2. Each section has a **Mermaid code block** — copy into Mermaid Live to export PNG/SVG.
3. For classic **UML use case ovals**, use [`use_case_diagram.puml`](use_case_diagram.puml) with PlantUML.
4. **B-series** IDs (B1–B12) map to Chapter III figure labels in [`PINYA_PIC_thesis_flowcharts.md`](PINYA_PIC_thesis_flowcharts.md).

---

## Chapter III disclaimer (paste verbatim)

> The diagrams presented are logical representations of the system workflows and architecture. Certain optional branches, asynchronous operations, and error-handling paths are described in detail in Sections 3.3–3.4 and are not fully expanded in the diagrams to maintain clarity.

---

## Table of contents

| # | Section |
|---|---------|
| B0 | [Use case diagram](#b0--use-case-diagram-june-2026) |
| B0t | [Thesis-style use case (APA 7)](#figure-1--use-case-diagram-apa-7) |
| B1 | [Diagnose tab data flow](#b1--diagnose-tab-data-loading) |
| B2 | [Seven-day chart pipeline](#b2--seven-day-chart-pipeline) |
| B3 | [App launch and auth](#b3--application-launch-and-auth) |
| B4 | [Capture and detection](#b4--image-capture-and-detection) |
| B5 | [Cloud sync queue](#b5--cloud-synchronization) |
| B6 | [Domain model / ERD](#b6--domain-model-erd) |
| B7 | [Component architecture](#b7--component-architecture) |
| B8 | [Three-layer architecture](#b8--three-layer-architecture) |
| B9 | [Field management](#b9--field-management) |
| B10 | [Feedback](#b10--feedback) |
| B11 | [Profile and preferences](#b11--profile) |
| B12 | [Deployment topology](#b12--deployment) |
| B13 | [Staff review and expert advice](#b13--staff-review-loop) |

---


## B0 — Use case diagram (June 2026)

```mermaid
%% PINYA-PIC — Use Case Diagram (structured layout, June 2026)
%% Paste into https://mermaid.live — zoom out for full view
%% Classic UML ovals: docs/diagrams/use_case_diagram.puml

flowchart LR
  classDef actor fill:#e8f0e3,stroke:#587048,stroke-width:2px,color:#1a1a1a
  classDef uc fill:#ffffff,stroke:#2e3141,stroke-width:1px
  classDef web fill:#f4f8ff,stroke:#4a6fa5,stroke-width:1px

  subgraph ACTORS_L["Actors"]
    direction TB
    F((Farmer)):::actor
    DA((DA Staff)):::actor
    AD((Full Admin)):::actor
    AD -.->|«inherits»| DA
  end

  subgraph SYS["PINYA-PIC System Boundary"]
    direction TB

    subgraph ROW1["Mobile — account, fields, capture"]
      direction LR

      subgraph AUTH["① Account & access"]
        direction TB
        A1[Register Account]:::uc
        A2[Login / Logout]:::uc
        A3[Manage Profile]:::uc
        A4[Request DA Staff Access]:::uc
        A5[View Access Outcome]:::uc
      end

      subgraph FIELD["② Field management"]
        direction TB
        F1[Create Field]:::uc
        F2[View Fields / Detail]:::uc
        F3[Edit Field]:::uc
        F4[Delete Field]:::uc
        F5[Edit Field Boundary]:::uc
        F6[Manage Field Photos]:::uc
      end

      subgraph CAP["③ Capture & reporting"]
        direction TB
        C1[Select Field for Scan]:::uc
        C2[Save Capture & Queue Sync]:::uc
        C3[Capture Image]:::uc
        C4[Detect Mealybugs On-Device]:::uc
        C5[Submit Report to Cloud]:::uc
        C6[View Capture History]:::uc
        C7[View Capture Detail]:::uc
        C8[Read Expert Advice]:::uc
      end
    end

    subgraph ROW2["Mobile — diagnose, map, feedback"]
      direction LR

      subgraph DIAG["④ Diagnose & education"]
        direction TB
        D1[View Diagnose Dashboard]:::uc
        D2[View Weekly Pest Chart]:::uc
        D3[Browse Disease Information]:::uc
      end

      subgraph MAP["⑤ Map & analytics"]
        direction TB
        M1[View Detections Map]:::uc
        M2[View Home Map Preview]:::uc
        M3[View Outbreak Heatmap]:::uc
      end

      FB[⑥ Submit Feedback]:::uc
    end

    subgraph ROW3["Staff & admin"]
      direction LR

      subgraph STAFF["⑦ Staff review — mobile"]
        direction TB
        S1[View Staff Home Panel]:::uc
        S2[View Org Analytics]:::uc
        S3[Review Reports by Field]:::uc
        S4[Write Expert Advice]:::uc
      end

      subgraph ADMIN["⑧ Administration"]
        direction TB
        N1[Review DA Access Requests]:::uc
        N2[Approve / Reject DA Access]:::uc
        N3[Manage Users]:::uc
        N4[Write Farm-Level Insight]:::uc
      end
    end

    subgraph ROW4["Web console — PineSight"]
      direction LR

      subgraph WEBUC["⑨ PineSight drawers"]
        direction TB
        W1[Reports — Field Groups]:::web
        W2[Analytics Drawer]:::web
        W3[Fields / Users Drawers]:::web
      end
    end
  end

  WEB((PineSight Web Admin)):::actor

  %% Includes
  C1 -.->|«include»| C3
  C3 -.->|«include»| C4
  C2 -.->|«include»| C3
  C2 -.->|«include»| C5
  D1 -.->|«include»| D2
  S3 -.->|«include»| C7
  S4 -.->|«include»| C7

  %% Extends
  F4 -.->|«extend»| F2
  F5 -.->|«extend»| F2
  F5 -.->|«extend»| F3
  F6 -.->|«extend»| F2
  C8 -.->|«extend»| C7
  S4 -.->|«extend»| S3
  N2 -.->|«extend»| N1

  %% Farmer
  F --> A1
  F --> A2
  F --> A3
  F --> A4
  F --> A5
  F --> F1
  F --> F2
  F --> F3
  F --> C1
  F --> C2
  F --> C6
  F --> C7
  F --> D1
  F --> D3
  F --> M1
  F --> M2
  F --> FB

  %% DA Staff
  DA --> A2
  DA --> A3
  DA --> S1
  DA --> S2
  DA --> S3
  DA --> S4
  DA --> M1
  DA --> M3

  %% Full Admin
  AD --> N1
  AD --> N2
  AD --> N3
  AD --> N4

  %% PineSight Web
  WEB --> A2
  WEB --> W1
  WEB --> W2
  WEB --> W3
  WEB --> S4
  WEB --> M1
  WEB --> M3
  WEB --> N1
  WEB --> N3

  ACTORS_L ~~~ SYS
  SYS ~~~ WEB
```


## B0b — Mobile admin vs web admin

```mermaid
%% PINYA-PIC — Mobile vs Web Admin (compact, June 2026)
%% Mermaid Live: paste whole block, zoom 100–110%

flowchart TB
  classDef actor fill:#587048,stroke:#2d3a24,stroke-width:3px,color:#ffffff
  classDef mob fill:#c8e0b0,stroke:#4a6b35,stroke-width:2px,color:#1a1a1a
  classDef web fill:#b8d4f0,stroke:#2e5f9e,stroke-width:2px,color:#1a1a1a
  classDef adm fill:#ffd966,stroke:#b8860b,stroke-width:2px,color:#1a1a1a
  classDef note fill:#f5f5f5,stroke:#999999,stroke-width:1px,color:#444444,font-size:12px

  DA((DA Staff)):::actor
  AD((Full Admin)):::actor
  AD -.->|inherits| DA

  subgraph MOBILE["MOBILE — PINYA-PIC app"]
    direction TB
    M1["Reports queue + expert advice"]:::mob
    M2["Org analytics + map + heatmap"]:::mob
    M3["All farms + staff home"]:::mob
    M4["Approve DA access"]:::adm
  end

  subgraph WEB["WEB — PineSight console"]
    direction TB
    W1["Reports drawer + filters"]:::web
    W2["Analytics + realtime KPIs"]:::web
    W3["Org map + focus + search"]:::web
    W4["Users CRUD"]:::adm
    W5["Fields + boundary + bulk"]:::adm
    W6["Farm insight + DA approval"]:::adm
  end

  LEG["Legend: green = mobile · blue = web · gold = full admin only"]:::note

  DA --> M1 & M2 & M3
  DA --> W1 & W2 & W3
  AD --> M4
  AD --> W4 & W5 & W6

  DA ~~~ MOBILE ~~~ WEB ~~~ LEG
```

## Figure 1 — Use case diagram (APA 7)

**Figure 1**  
*Use Case Diagram of the PINYA-PIC Mealybug Collecting Mobile Application With Decision Middleware*

> Classic UML ovals: [`use_case_diagram_thesis.puml`](use_case_diagram_thesis.puml) + full APA block: [`FIGURE_1_USE_CASE_APA7.md`](FIGURE_1_USE_CASE_APA7.md)

```mermaid
%% PINYA-PIC — Thesis-style use case (Mermaid, oval shapes)
%% Best classic ovals: use use_case_diagram_thesis.puml with PlantUML

flowchart TB
  classDef actor fill:#e8f0e3,stroke:#2e3141,stroke-width:2px
  classDef uc fill:#fff,stroke:#2e3141,stroke-width:1.5px

  TITLE["PINYA-PIC: Mealybug Collecting Mobile Application with Decision Middleware"]

  subgraph ROW[" "]
    direction LR
    F((Farmer)):::actor

    subgraph SYS["PINYA-PIC System Boundary"]
      direction TB

      subgraph UC_LEFT[" "]
        direction TB
        L1([Register Account]):::uc
        L2([Manage Profile]):::uc
        L3([Log In]):::uc
        L4([Create New Field]):::uc
        L5([Select Field]):::uc
        L6([View Field]):::uc
        L7([Capture Image]):::uc
        L8([View Map]):::uc
        L9([Edit Field]):::uc
      end

      subgraph UC_MID[" "]
        direction TB
        M1([Detect Mealybugs On-Device]):::uc
        M2([Save Capture and Submit to Cloud]):::uc
        M3([Delete Field]):::uc
        M4([Edit Field Boundary]):::uc
        M5([View Detections Map]):::uc
        M6([View Mealybug Infestation Count]):::uc
        M7([Manage Field Photos]):::uc
      end

      subgraph UC_RIGHT[" "]
        direction TB
        R4([View Outbreak Visualization]):::uc
        R5([Review Farmer Reports]):::uc
        R6([View Capture Detail]):::uc
        R7([Write Expert Advice]):::uc
      end
    end

    DA((DA Staff)):::actor
  end

  AD((Full Admin)):::actor
  A1([Review DA Access Requests]):::uc
  A2([Approve Sign-Up Request]):::uc

  %% Includes
  L5 -.->|«include»| L7
  L7 -.->|«include»| M1
  L7 -.->|«include»| M2
  R5 -.->|«include»| R6
  R7 -.->|«include»| R6

  %% Extends
  M3 -.->|«extend»| L6
  M4 -.->|«extend»| L6
  M4 -.->|«extend»| L9
  M5 -.->|«extend»| L6
  M6 -.->|«extend»| L6
  M7 -.->|«extend»| L6
  R7 -.->|«extend»| R5
  A2 -.->|«extend»| A1

  %% Farmer
  F --> L1 & L2 & L3 & L4 & L5 & L6 & L7 & L8 & L9

  %% DA Staff (shared Log In, Profile, Map with farmer nodes)
  DA --> L2 & L3 & L8 & R4 & R5

  %% Full Admin
  AD --> A2

  TITLE ~~~ ROW
  ROW ~~~ AD
  AD --> A1
```

*Note.* Farmer (left), DA Staff (right), and Full Admin (bottom) match the thesis layout. Approve Sign-Up Request = DA staff access approval. Include/extend links reflect the June 2026 codebase.

## B1 — Diagnose tab data loading

```mermaid
flowchart TD
  A[MainDashboardScreen _DiagnoseTab] --> B{currentUserJwtStaff?}
  B -->|Yes DA or Admin| C[StaffAnalyticsTab]
  C --> C1[detectionsRealtimeStream org-wide]
  C1 --> C2[StaffAnalyticsCalculator.fromDetections]
  C2 --> C3[StaffAnalyticsPanel donut bar trend charts]
  B -->|No Farmer| D[watch capturedPhotosRevision]
  D --> E[FutureBuilder getCapturedPhotos SQLite]
  D --> F[StreamBuilder detectionsRealtimeStream]
  E --> G[DashboardStatsCalculator.fromCapturedPhotos]
  F --> H[fromDetectionMaps if stream has data]
  G --> I[farmerWeeklyStats prefer local if has data]
  H --> I
  I --> J[Stat cards + monotonic pest chart]
```

## B2 — Seven-day chart pipeline

```mermaid
flowchart TD
  A[DashboardStats.dailyCounts last 7 days] --> B[Group by calendar day]
  B --> C[_RealLineChartPainter compute maxY]
  C --> D[Draw grid Y labels 0 at bottom]
  D --> E[buildMonotonicSmoothLinePath]
  E --> F[buildMonotonicSmoothAreaFill]
  F --> G[X axis EN or FIL day labels]
  G --> H[Peak marker dot + value badge]
  H --> I[Render in Diagnose tab PineCard]
```


## B3 — Application launch and auth

```mermaid
flowchart TD
    A[App Launch main.dart] --> B{Supabase configured?}
    B -->|No| C[ConfigRequiredScreen]
    B -->|Yes| D[IntroFlowScreen route /]
    D --> E[SplashScreen ~650ms]
    E --> F{Inactive 14+ days?}
    F -->|Yes| G[resetOnboardingComplete + signOut]
    G --> H{Onboarding complete?}
    F -->|No| H
    H -->|No| I[OnboardingScreen 3 slides]
    I --> J[_AuthGate]
    H -->|Yes| J
    J --> K{Session exists?}
    K -->|No| L[WelcomeScreen]
    L --> M[Login or Register tap]
    M --> N[ensureTermsAccepted before auth]
    N --> O[LoginScreen / RegisterScreen email+password]
    O --> P[SupabaseProfileService.upsertCurrentUserProfile]
    P --> J
    K -->|Yes| Q[UnlockGate biometric optional]
    Q --> R[PostAuthGate staff onboarding if pending]
    R --> S[NavigationGuideHost]
    S --> T[MainDashboardScreen]
    T --> U{display_name empty?}
    U -->|Yes| V[/nickname-prompt pushed]
    U -->|No| W{JWT role center nav}
    W -->|Full admin| X[DaAccessRequestsScreen]
    W -->|DA staff| Y[AdminReportsScreen pendingReply]
    W -->|Farmer| Z[startFieldFirstScan]
```


## B4 — Image capture and detection

```mermaid
flowchart TD
    subgraph ENTRY[Field-first scan entry]
        A1[startFieldFirstScan or route /camera] --> B1[AssignFieldScreen pick field]
        B1 --> C1[PhotoSourcePicker fieldName fieldId]
        C1 --> D1{Camera or Gallery?}
        D1 -->|Camera| E1[CameraModeSelector ImagePicker]
        D1 -->|Gallery| F1[_pickFromGalleryAndDetect]
    end

    subgraph INFER[On-device inference]
        E1 --> G1[_captureAndDetect]
        F1 --> G1
        G1 --> H1[InferenceService preprocess 1280px]
        H1 --> I1[TFLite assets/model/best.tflite + Dart NMS]
        I1 --> J1[PhotoResultScreen boxes count confidence]
    end

    subgraph SAVE[Save PhotoResultScreen._saveDetection]
        J1 --> K1[_ensureTaggedLocation GPS]
        K1 --> L1[fieldBoundarySaveGate geofence dialog]
        L1 --> M1[ImageStorageService.saveDetectionImage]
        M1 --> N1[insertCapturedPhoto SQLite]
        N1 --> O1[enqueueUpload status pending]
        O1 --> P1[bumpCapturedPhotos AppState]
        P1 --> Q1{fieldId set before capture?}
        Q1 -->|No| R1[AssignFieldScreen optional post-save]
        Q1 -->|Yes| S1[Skip assign]
        R1 --> S1
        S1 --> T1{Online and signed in?}
        T1 -->|Yes| U1[syncPending limit 1 immediate]
        T1 -->|No| V1[syncInBackground on resume]
    end

    subgraph CLOUD[Cloud upload separate step]
        U1 --> W1[CloudSyncService._uploadOneQueueRow]
        V1 --> W1
        W1 --> X1[DetectionService.saveDetection]
        X1 --> Y1[Storage upload + detections row has_mealybugs]
        Y1 --> Z1[linkCapturedPhotoToRemoteUpload + markUploadSynced]
    end

    subgraph RESULT[Result UI]
        J1 --> R2[Positive or Negative badge]
        R2 --> R3[What to do next card]
        R3 --> R4[Farmer reads expert advice later if staff replies]
    end
```


## B5 — Cloud synchronization

```mermaid
flowchart TD
    A[Trigger: Save scan OR MainDashboard init resume] --> B[CloudSyncService.syncPending or syncInBackground]
    B --> C{Signed in and online?}
    C -->|No| D[upload_queue and field_cache stay pending]
    C -->|Yes| E[backfillPendingUploadsForUnsyncedCaptures]
    E --> F[_syncPendingFieldsForUser field_cache to Supabase fields]
    F --> G[getPendingUploads limit 10 per batch]

    G --> H{For each upload_queue row}
    H --> I[DetectionService.saveDetection]
    I --> J[Upload image to Storage]
    I --> K[Insert detections row has_mealybugs equals count gt 0]
    K --> L{Success?}
    L -->|Yes| M[linkCapturedPhotoToRemoteUpload captured_photo.remote_id]
    M --> N[markUploadSynced queue status synced]
    L -->|No| O[markUploadFailed status pending attempts++]
    N --> H
    O --> H

    K --> P{count greater than 0?}
    P -->|Yes| Q[Positive: map analytics staff pending queue]
    P -->|No| R[Negative: history only not outbreak map]
```


## B6 — Domain model (ERD)

```mermaid
erDiagram
    AUTH_USERS ||--o| PROFILES : has
    AUTH_USERS ||--o{ FIELDS : owns
    AUTH_USERS ||--o{ DETECTIONS : creates
    AUTH_USERS ||--o{ ACCESS_REQUEST : submits
    FIELDS ||--o{ DETECTIONS : contains
    FIELDS ||--o{ FARM_INSIGHTS : has
    DETECTIONS ||--o| EXPERT_RESPONSES : may_have
    CAPTURED_PHOTO ||--o| UPLOAD_QUEUE : linked_by_local_image_path
    FIELD_CACHE ||--o| FIELDS : mirrors_when_offline
    LAND ||--o| FIELDS : boundary_polygon_local

    PROFILES {
        uuid id PK
        text phone
        text email
        text display_name
        text photo_url
        text account_intent
        timestamptz created_at
        timestamptz updated_at
    }

    FIELDS {
        uuid id PK
        uuid user_id FK
        text name
        text address
        jsonb boundary_json
        text preview_image_path
        int image_count
        timestamptz last_detection
        timestamptz created_at
        timestamptz updated_at
    }

    DETECTIONS {
        uuid id PK
        uuid user_id FK
        uuid field_id FK
        text image_url
        float confidence
        int count
        bool has_mealybugs
        jsonb detections_json
        float latitude
        float longitude
        timestamptz created_at
    }

    EXPERT_RESPONSES {
        uuid id PK
        uuid detection_id FK UK
        uuid author_id FK
        text strategy_text
        text action_type
        timestamptz created_at
        timestamptz updated_at
    }

    FARM_INSIGHTS {
        uuid id PK
        uuid field_id FK
        uuid author_id FK
        text insight_text
        timestamptz created_at
    }

    ACCESS_REQUEST {
        uuid id PK
        uuid user_id FK
        text full_name
        text organization
        text company_location
        text position
        text note
        text status
        uuid reviewer_id FK
        text review_note
        timestamptz reviewed_at
    }

    CAPTURED_PHOTO {
        int id PK
        text local_image_path
        text field_id
        text field_name
        int count
        float confidence
        text user_id
        text remote_id
        text remote_image_url
        text detections_json
        float latitude
        float longitude
        text created_at
    }

    UPLOAD_QUEUE {
        int id PK
        text local_image_path
        text field_id
        float confidence
        int count
        float latitude
        float longitude
        text name_hint
        text status
        int attempts
        text last_error
        text created_at
    }

    FIELD_CACHE {
        text id PK
        text user_id
        text name
        text address
        text boundary_json
        text sync_status
    }

    LAND {
        int id PK
        text land_name
        text polygon_coordinates
    }
```


## B7 — Component architecture

```mermaid
flowchart TD
    subgraph PRES[Presentation Layer]
        MD[MainDashboardScreen permission_screens fields staff screens]
        WEB[PineSight Admin admin/app.js]
        WID[PineCard AppScaffold staff_analytics_charts]
    end

    subgraph CORE[Core Layer]
        AS[AppState Provider]
        SCP[SupabaseClientProvider]
        JWT[admin_session currentUserJwtStaff FullAdmin Da]
    end

    subgraph SERVICES[Service Layer]
        IS[InferenceService]
        CTS[CloudSyncService]
        DSC[DashboardStatsCalculator]
        SAC[StaffAnalyticsCalculator]
        ARS[AdminReportsService]
        SNB[StaffNavBadgesService]
        EFS[ExpertFeedbackService]
        DBS[DatabaseService]
        RDS[DetectionService]
        CPRS[CapturedPhotosRemoteSync]
    end

    subgraph DATA[Data Layer]
        SQL[(SQLite captured_photo upload_queue field_cache land)]
        PG[(Postgres profiles fields detections expert_responses access_request)]
        ST[(Storage detections avatars)]
        AUTH[(Supabase Auth email password)]
    end

    MD --> AS
    MD --> DBS
    MD --> DSC
    WEB --> SCP
    AS --> CTS
    JWT --> MD
    JWT --> WEB
    IS --> MD
    CTS --> DBS
    CTS --> RDS
    ARS --> PG
    CPRS --> DBS
    DBS --> SQL
    RDS --> PG
    RDS --> ST
    SCP --> AUTH
```

## B8 — Three-layer architecture

```mermaid
flowchart TD
  UI[UI Flutter + PineSight Admin] --> SV[Service layer]
  SV --> LS[Local SQLite + images]
  SV --> CL[Supabase Auth Postgres Storage Realtime]
  SV --> IE[TFLite best.tflite 1280px on-device]
  LS --> OUT[Results to UI]
  CL --> OUT
  IE --> OUT
```


## B9 — Field management

```mermaid
flowchart TD
    subgraph LOAD[Load fields]
        A[_MyFieldsTab or FieldsListScreen] --> B[fieldsRealtimeStream + field_cache SQLite fallback]
        B --> C{currentUserJwtStaff?}
        C -->|Farmer| D[filter user_id eq uid]
        C -->|Staff| E[all fields visible via RLS]
        D --> F[Display PineCard field grid]
        E --> F
    end

    subgraph CREATE[Create field FarmDetailsScreen]
        F --> G{Add field}
        G --> H[Enter name address preview photo]
        H --> I[LandMapScreen draw boundary polygon]
        I --> J{Online?}
        J -->|Yes| K[Insert Supabase fields boundary_json]
        J -->|No| L[upsertPendingLocalField field_cache]
        L --> M[CloudSyncService._syncPendingFieldsForUser later]
        K --> F
        M --> F
    end

    subgraph VIEW[View edit delete]
        F --> N{Tap card}
        N --> O[FieldDetailScreen map + capture history]
        O --> P{Overflow menu}
        P -->|Edit| Q[EditFieldScreen]
        P -->|Delete| R[Unassign detections delete fields row]
        F --> S{Edit icon FieldsListScreen admin only}
        S --> Q
        Q --> F
    end
```


## B10 — Feedback

```mermaid
flowchart TD
    A[FeedbackScreen loads] --> B[Show feedback options]
    B --> C{User choice}

    subgraph EMAIL[Email option]
        C -->|Send via Email| D[Launch mailto intent]
        D --> E{Launch success}
        E -->|Yes| F[Email app opens]
        E -->|No| G[Show copy email dialog]
        G --> H[Copy email to clipboard]
        H --> I[Show confirmation message]
    end

    subgraph FORM[In app feedback form]
        C -->|Feedback Form| J[Navigate to FeedbackFormScreen]
        J --> K[User enters name email message]
        K --> L[Submit form]
        L --> M[Send request to Apps Script endpoint]
        M --> N{Request success}
        N -->|Yes| O[Show success snackbar]
        N -->|No| P[Show error snackbar]
        P --> Q[Allow retry]
        Q --> L
    end

    subgraph NOTE[Rate option]
        R[Rate app button not present in current screen]
    end

    F --> S[Return to feedback screen]
    I --> S
    O --> S
```


## B11 — Profile

```mermaid
flowchart TD
    A[ProfileScreen loads] --> B[Get current auth user]
    B --> C[Load profiles row]
    C --> D[Render profile UI]
    D --> E{User action}

    subgraph EDIT[Edit profile]
        E -->|Edit Profile| F[Enable edit mode]
        F --> G[Edit display name]
        F --> H[Edit phone]
        G --> I[Save]
        H --> I
        I --> J[Upsert profiles row]
        J --> C
    end

    subgraph PHOTO[Change photo]
        E -->|Change Photo| K[Choose source]
        K --> L{Camera or Gallery}
        L --> M[Pick image file]
        M --> N[Upload to avatars bucket]
        N --> O[Get public URL]
        O --> P[Update profiles photo_url]
        P --> C
    end

    subgraph BIO[Biometric]
        E -->|Biometric| Q[Check availability]
        Q --> R{Available}
        R -->|No| S[Show not available]
        R -->|Yes| T{Currently enabled}
        T -->|No| U[Enable biometric]
        T -->|Yes| V[Disable biometric]
        U --> W[Save local preference]
        V --> W
        W --> C
    end
```


## B12 — Deployment

```mermaid
flowchart TD
    subgraph DEV[Development]
        PC[Developer machine Flutter SDK]
        SCR[scripts run_debug deploy_admin_web]
    end

    subgraph TRAIN[Model training]
        YOLO[Ultralytics YOLO export]
        TFL[assets/model/best.tflite 1280 input]
    end

    subgraph MOBILE[Android device]
        APP[PINYA-PIC Flutter app]
        SQL[(SQLite offline queue field_cache)]
        LOCAL[(Local images)]
        INF[TFLite InferenceService on-device]
    end

    subgraph WEB[PineSight Admin]
        NL[Netlify static host]
        JS[admin/app.js map reports analytics]
    end

    subgraph CLOUD[Supabase]
        AUTH[Auth email password]
        PG[(Postgres RLS)]
        RT[Realtime detections expert_responses]
        ST[Storage detections avatars]
    end

    PC --> APP
    YOLO --> TFL --> INF
    APP --> SQL
    APP --> LOCAL
    APP --> AUTH
    APP --> PG
    APP --> ST
    NL --> JS
    JS --> AUTH
    JS --> PG
    JS --> RT
    PG --> RT
```


## B13 — Staff review loop

```mermaid
flowchart TD
    A[DA Admin center nav or AdminReportsScreen] --> B[CapturedPhotosRemoteSync.pullIntoLocalIfSignedIn]
    B --> C[AdminReportsService.fetchReports filter pendingReply optional]
    C --> D[groupAdminReportsByField]
    D --> E[Show field summary cards]
    E --> F{Expand field?}
    F -->|Web admin.js| G[Lazy load field detections limit 200]
    F -->|Mobile| H[Nested tiles from AdminReportItem list]
    G --> I[CapturedPhotoDetailScreen]
    H --> I
    I --> J{Positive count gt 0 and no expert reply?}
    J -->|Yes| K[ExpertFeedbackService.upsertResponse]
    J -->|No| L[View only]
    K --> M[Farmer sees advice on capture detail + notification badge]
    K --> N[Web Realtime patch debounced 400ms]
```


## Dashboard diagnose detail

```mermaid
flowchart TD
    A[MainDashboardScreen _DiagnoseTab] --> B{currentUserJwtStaff?}
    B -->|Yes DA or Admin| C[StaffAnalyticsTab]
    C --> C1[detectionsRealtimeStream org-wide]
    C1 --> C2[StaffAnalyticsCalculator.fromDetections]
    C2 --> C3[StaffAnalyticsPanel donut bar trend charts]

    B -->|No Farmer| D[watch capturedPhotosRevision]
    D --> E[FutureBuilder loadLocalStats getCapturedPhotos]
    D --> F[StreamBuilder detectionsRealtimeStream farmer uid]
    E --> G[DashboardStatsCalculator.fromCapturedPhotos]
    F --> H[fromDetectionMaps if stream non-empty]
    G --> I[farmerWeeklyStats prefer local if has data]
    H --> I
    I --> J[Stat cards + _RealLineChartPainter monotonic chart]
    J --> K[My Fields strip below]
```


## Chart rendering detail

```mermaid
flowchart TD
    A[DashboardStats.dailyCounts last 7 days] --> B[Group by calendar day]
    B --> C[_RealLineChartPainter compute maxY]
    C --> D[Draw grid Y labels 0 at bottom]
    D --> E[buildMonotonicSmoothLinePath]
    E --> F[buildMonotonicSmoothAreaFill]
    F --> G[X axis EN or FIL day labels]
    G --> H[Peak marker dot + value badge]
    H --> I[Render in Diagnose tab PineCard]
```


## Service dependencies

```mermaid
flowchart TD
    subgraph UI[UI Layer]
        MD[MainDashboardScreen _DiagnoseTab]
        AR[AdminReportsScreen]
        PRS[PhotoResultScreen permission_screens]
        CPD[CapturedPhotoDetailScreen]
        FL[FarmDetailsScreen FieldDetailScreen EditFieldScreen]
        WEB[admin/app.js Supabase JS client]
    end

    subgraph ORCH[Orchestration / calculators]
        DSC[DashboardStatsCalculator static]
        SAC[StaffAnalyticsCalculator]
        ARS[AdminReportsService]
        SNB[StaffNavBadgesService]
    end

    subgraph SERVICES[Services]
        IS[InferenceService]
        CTS[CloudSyncService]
        RDS[DetectionService]
        DBS[DatabaseService]
        EFS[ExpertFeedbackService]
        CPRS[CapturedPhotosRemoteSync]
    end

    MD --> DSC
    MD --> SNB
    MD --> CTS
    MD --> SAC
    AR --> ARS
    AR --> CPRS
    PRS --> IS
    PRS --> DBS
    PRS --> CTS
    CPD --> EFS
    FL --> DBS
    FL --> CTS
    WEB --> PG[(Postgres via Supabase JS)]

    SNB --> ARS
    CTS --> DBS
    CTS --> RDS
    CPRS --> DBS

    DBS --> SQL[(SQLite)]
    RDS --> PG
    RDS --> ST[(Storage)]
```


## Sequence: detection

```mermaid
sequenceDiagram
    participant User
    participant PSP as PhotoSourcePicker
    participant CMS as CameraModeSelector
    participant IP as ImagePicker
    participant IS as InferenceService
    participant PRS as PhotoResultScreen
    participant GS as GeoService
    participant DBS as DatabaseService
    participant ISS as ImageStorageService

    User->>PSP: Choose camera or gallery
    alt Camera path
        PSP->>CMS: Open camera mode
        User->>CMS: Tap capture
        CMS->>IP: pickImage from camera
        IP-->>CMS: image file
        CMS->>IS: runInference image bytes
    else Gallery path
        User->>PSP: Pick image
        PSP->>IS: runInference image bytes
    end
    IS->>IS: preprocess 1280px letterbox
    IS->>IS: TFLite inference + NMS
    IS-->>PRS: DetectionResult count boxes confidence
    PRS-->>User: Show boxes preview map tag location

    User->>PRS: Tap Save
    PRS->>GS: getCurrentPosition optional
    PRS->>PRS: fieldBoundarySaveGate dialog if needed
    PRS->>ISS: saveDetectionImage bytes
    ISS-->>PRS: localPath
    PRS->>DBS: insertCapturedPhoto
    PRS->>DBS: enqueueUpload
    PRS-->>User: Success snackbar saved locally
```


## Sequence: sync

```mermaid
sequenceDiagram
    participant User
    participant PRS as PhotoResultScreen
    participant DBS as DatabaseService
    participant AS as AppState
    participant CTS as CloudSyncService
    participant RDS as DetectionService
    participant ST as Supabase Storage
    participant PG as Postgres detections

    User->>PRS: Tap Save
    PRS->>DBS: insertCapturedPhoto
    PRS->>DBS: enqueueUpload
    PRS->>AS: bumpCapturedPhotos
    alt Online and signed in
        PRS->>CTS: syncPending limit 1
        CTS->>DBS: backfill + getPendingUploads
        CTS->>RDS: saveDetection from queue row
        RDS->>ST: upload image file
        RDS->>PG: insert detections has_mealybugs
        RDS-->>CTS: detection_id + image_url
        CTS->>DBS: linkCapturedPhotoToRemoteUpload
        CTS->>DBS: markUploadSynced
    else Offline or not signed in
        PRS->>CTS: syncInBackground
        Note over CTS,DBS: Retries on dashboard resume when online
    end
```


---

## Positive vs negative routing (panel rule)

| Detection result | count / has_mealybugs | Map & heatmap | Staff pending queue |
|------------------|----------------------|---------------|---------------------|
| **Positive** | count > 0 | Yes | Yes until advice saved |
| **Negative** | count = 0 | No | No |

---

*Last updated 13 June 2026. Source: `docs/diagrams/*.mmd`. Regenerate: `python scripts/combine_diagrams_md.py`*
