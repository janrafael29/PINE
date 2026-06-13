# PINYA-PIC v2.2 — Complete flowchart set (Supabase)

> User-facing app name: **PINYA-PIC** (repository folder may still be **PINE**).

**Diagram freshness (Apr 2026):** The flows below are the structural baseline. The live app also includes a **post-login navigation guide** (spotlight overlay on the dashboard, sequence steps, optional “show every time / once” preference), **dark-mode–aware** screens across camera/add-photo, disease content, fields, and profile, and a **post-scan “What to do next”** card on the detection result view. On-device detection uses **`assets/model/best.tflite`** with **Dart NMS** and default balanced thresholds documented in **`RUN.md`** §11.

## 1) User Authentication and Onboarding

```mermaid
flowchart TD
    A[App Launch] --> B{Terms and Privacy Accepted}
    B -->|No| C[TermsAcceptanceScreen]
    C --> D{User Accepts}
    D -->|No| E[Stay on Terms or Exit]
    D -->|Yes| F[Save SharedPreferences flags]
    F --> G[IntroFlowScreen]
    B -->|Yes| G

    G --> H[Splash Screen]
    H --> I{Onboarding Complete}
    I -->|No| J[OnboardingScreen]
    J --> K[Mark onboarding complete]
    K --> L[AuthGate]
    I -->|Yes| L

    L --> M[Stream auth state change]
    M --> N{Session Exists}
    N -->|No| O[WelcomeScreen]
    O --> P[Login or Register]
    P --> Q[Supabase sign in or sign up]
    Q --> R[Upsert profile row]
    R --> S[MainDashboardScreen]

    N -->|Yes| T[MainDashboardScreen]
    T --> U{Display name empty}
    U -->|Yes| V[NicknamePromptScreen]
    V --> W[Upsert profiles display_name]
    W --> T
    U -->|No| X[Dashboard tabs]
```

## 2) Camera and Detection Flow (Two Paths)

```mermaid
flowchart TD
    subgraph INIT[Initialization]
        A1[DetectionScreen initState] --> B1[DetectionFlowController initialize]
        B1 --> C1[InferenceService initialize]
        B1 --> D1[DatabaseService initialize SQLite]
        B1 --> E1[CameraService initialize]
        B1 --> F1[GeoService check permissions]
    end

    subgraph CAPTURE[Capture]
        G1[User taps Capture] --> H1[captureAndDetect]
        H1 --> I1[CameraService takePicture]
        I1 --> J1[Image bytes]
    end

    subgraph INFER[Inference]
        J1 --> K1[runInference]
        K1 --> L1[Preprocess image]
        L1 --> M1[TFLite YOLO]
        M1 --> N1[Parse output]
        N1 --> O1[Apply NMS]
        O1 --> P1[DetectionResult]
    end

    subgraph LOCATION[Location and geofence]
        P1 --> Q1[getCurrentPosition]
        Q1 --> R1{GPS success}
        R1 -->|No| S1[Failure outcome]
        S1 --> T1[Show error and retry]
        T1 --> G1
        R1 -->|Yes| U1[get lat lng]
        U1 --> V1[getAllLands]
        V1 --> W1[findLandForPoint]
    end

    subgraph PATHA[Path A standalone local only]
        W1 --> X1[saveDetectionImage]
        X1 --> Y1[insertDetection to SQLite detection]
        Y1 --> Z1[Success outcome]
    end

    subgraph PATHB[Path B field linked save flow]
        W1 --> A2[insertCapturedPhoto]
        A2 --> B2[enqueueUpload]
        B2 --> C2[syncInBackground]
        C2 --> D2[Success outcome]
    end

    subgraph RESULT[Result display]
        Z1 --> E2[Update UI]
        D2 --> E2
        E2 --> F2[Draw boxes]
        E2 --> G2[Show coordinates]
        E2 --> H2[Show land name]
        E2 --> I2[Show outside boundary warning]
    end
```

## 3) Offline Sync and Connectivity

```mermaid
flowchart TD
    subgraph SAVE[Save from field flow]
        A[User taps Save] --> B[insertCapturedPhoto]
        B --> C[enqueueUpload]
        C --> D[status pending attempts zero]
        D --> E[syncInBackground]
    end

    subgraph MONITOR[Connectivity checks]
        E --> F[CloudSyncService]
        F --> G{auth currentUser exists}
        G -->|No| H[Return cannot upload]
        G -->|Yes| I[DNS lookup]
        I --> J{Online}
        J -->|No| K[Leave queue pending]
        K --> L[Wait and retry later]
        L --> F
    end

    subgraph SYNC[Pending uploads]
        J -->|Yes| M[syncPending]
        M --> N[getPendingUploads limit 10]
        N --> O{More records}
        O -->|No| P[Sync complete]
        O -->|Yes| Q[Process next record]
        Q --> R[Check local image file]
        R --> S{File exists}
        S -->|No| T[markUploadFailed]
        T --> U{Attempts below max}
        U -->|Yes| O
        U -->|No| V[Mark failed permanent]
        V --> O
        S -->|Yes| W[DetectionService saveDetection]
        W --> X[Upload to Storage detections bucket]
        X --> Y[Insert row into detections]
        Y --> Z[Update fields metadata if field id]
        Z --> AA{Success}
        AA -->|Yes| AB[markUploadSynced]
        AB --> O
        AA -->|No| T
    end

    subgraph STATUS[Current indicator behavior]
        AC[SyncStatusIndicator] --> AD[Static green cloud icon]
        AD --> AE[Tooltip Supabase cloud]
        AF[No multi state indicator in code]
    end
```

## 4) Dashboard Statistics Flow

```mermaid
flowchart TD
    subgraph LOAD[Load data]
        A[MainDashboardScreen loads] --> B[Get user id from auth]
        B --> C[Query public detections]
        C --> D[Filter by user_id]
        D --> E[Order by created_at desc]
        E --> F[Detection records]
    end

    subgraph LOCALALT[Local optional path]
        G[Query SQLite captured_photo] --> H[Local records]
    end

    subgraph CALC[Calculate stats]
        F --> I[fromDetectionMaps]
        H --> J[fromCapturedPhotos]
        I --> K[Build DashboardStats]
        J --> K
        K --> L[imageCount]
        L --> M[fieldCount]
        M --> N[infestationRate]
        N --> O[dailyCounts]
    end

    subgraph DISPLAY[Render]
        O --> P[Display stat cards]
        P --> Q[Render line chart painter]
        Q --> R[Catmull Rom to Bezier]
        R --> S[Grid and day labels]
        S --> T[Gradient fill]
        T --> U[Peak guide dot label]
        U --> V[Render My Fields section]
        V --> W[Long press edit support]
    end
```

## 5) Field Management Flow

```mermaid
flowchart TD
    subgraph LOAD[Load fields]
        A[My Fields tab] --> B[Get user id]
        B --> C[Stream Supabase fields]
        C --> D[Filter user_id equals uid]
        D --> E[Order by created_at]
        E --> F[Display field cards]
    end

    subgraph CREATE[Create field]
        F --> G{Add field action}
        G --> H[Navigate FarmDetailsScreen]
        H --> I[Enter name and address]
        I --> J[Pick or capture preview image]
        J --> K[Upload preview image]
        K --> L[Insert public fields row]
        L --> F
    end

    subgraph VIEW[View field]
        F --> M{Tap field card}
        M --> N[Navigate FieldDetailScreen]
        N --> O[Stream detections by field_id]
        O --> P[Show field details history]
    end

    subgraph EDIT[Edit field long press]
        F --> Q{Long press field card}
        Q --> R[Navigate EditFieldScreen]
        R --> S[Load Supabase fields row by id]
        S --> T{Owner check user_id}
        T -->|No| U[Show no access]
        U --> F
        T -->|Yes| V[Editable form]
        V --> W[Edit name]
        V --> X[Edit address]
        V --> Y[Update preview image]
        Y --> Z{Image source}
        Z -->|Camera| AA[Take photo]
        Z -->|Gallery| AB[Pick photo]
        AA --> AC[Upload image]
        AB --> AC
        AC --> AD[Set preview_image_path]
        W --> AE[Save]
        X --> AE
        AD --> AE
        AE --> AF[Update fields row]
        AF --> AG[Keep user_id unchanged]
        AG --> AH[Back to list]
        AH --> F
    end
```

## 6) Entity Relationship Diagram

```mermaid
erDiagram
    AUTH_USERS ||--o| PROFILES : has
    AUTH_USERS ||--o{ FIELDS : owns
    AUTH_USERS ||--o{ DETECTIONS : creates
    LAND_SQLITE ||--o{ DETECTION_SQLITE : contains

    PROFILES {
        uuid id PK
        text phone
        text email
        text display_name
        text photo_url
        timestamptz created_at
        timestamptz updated_at
    }

    FIELDS {
        uuid id PK
        uuid user_id FK
        text name
        text address
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
        float latitude
        float longitude
        timestamptz created_at
    }

    LAND_SQLITE {
        int id PK
        text land_name
        text polygon_coordinates
        text created_at
    }

    DETECTION_SQLITE {
        int id PK
        text image_path
        float latitude
        float longitude
        int land_id FK
        int bug_count
        float confidence_score
        text timestamp
    }

    UPLOAD_QUEUE {
        int id PK
        text local_image_path
        int confidence
        int count
        text field_id
        float latitude
        float longitude
        text status
        int attempts
        text last_error
        text created_at
    }

    CAPTURED_PHOTO {
        int id PK
        text local_image_path
        text field_name
        text field_id
        int confidence
        int count
        float latitude
        float longitude
        text user_id
        text created_at
        text exported_at
    }
```

## 7) Service Dependency Graph

```mermaid
flowchart TD
    subgraph CORE[Core Layer]
        SL[ServiceLocator]
        AS[AppState Provider]
        SC[SupabaseClientProvider]
    end

    subgraph UI[UI Layer]
        DS[DetectionScreen]
        MD[MainDashboardScreen]
        FL[FieldsListScreen]
        EF[EditFieldScreen]
        FD[FieldDetailScreen]
        PS[ProfileScreen]
        FS[FeedbackScreen]
    end

    subgraph ORCH[Orchestration]
        DFC[DetectionFlowController]
        DSC[DashboardStatsCalculator]
    end

    subgraph SERVICES[Service Layer]
        CS[CameraService]
        IS[InferenceService]
        GS[GeoService]
        GFS[GeoFenceService]
        ISS[ImageStorageService]
        DBS[DatabaseService SQLite]
        CTS[CloudSyncService]
        RDS[DetectionService]
        BIO[BiometricService]
    end

    subgraph DATA[Data Layer]
        SQL[(SQLite)]
        PG[(Supabase Postgres)]
        ST[(Supabase Storage)]
    end

    SC --> MD
    SC --> FL
    SC --> PS
    DS --> DFC
    MD --> DSC
    DFC --> CS
    DFC --> IS
    DFC --> GS
    DFC --> GFS
    DFC --> ISS
    DFC --> DBS
    DSC --> PG
    CTS --> DBS
    CTS --> ISS
    CTS --> RDS
    FS --> CTS
    RDS --> ST
    RDS --> PG
    DBS --> SQL
    IS --> TFLITE[TFLite YOLO]
    GS --> GPS[GPS]
```

## 8) Sequence Diagram: Detection Flow

```mermaid
sequenceDiagram
    participant User
    participant DS as DetectionScreen
    participant DFC as DetectionFlowController
    participant CS as CameraService
    participant IS as InferenceService
    participant GS as GeoService
    participant GFS as GeoFenceService
    participant ISS as ImageStorageService
    participant DBS as DatabaseService

    User->>DS: Tap Capture
    DS->>DFC: captureAndDetect
    DFC->>CS: takePicture
    CS-->>DFC: imageBytes
    DFC->>IS: runInference imageBytes
    IS->>IS: preprocess
    IS->>IS: model inference
    IS->>IS: parse output and NMS
    IS-->>DFC: detection result
    DFC->>GS: getCurrentPosition

    alt GPS Success
        GS-->>DFC: lat lng
        DFC->>DBS: getAllLands
        DBS-->>DFC: lands
        DFC->>GFS: findLandForPoint
        GFS-->>DFC: geofence result
        DFC->>ISS: saveDetectionImage
        ISS-->>DFC: imagePath
        DFC->>DBS: insertDetection
        DBS-->>DFC: detectionId
        DFC-->>DS: success outcome
        DS-->>User: render boxes and location
    else GPS Failure
        GS-->>DFC: error
        DFC-->>DS: failure outcome
        DS-->>User: show error and retry
    end
```

## 9) Sequence Diagram: Offline Sync

```mermaid
sequenceDiagram
    participant User
    participant PR as PhotoResultFlow
    participant DBS as DatabaseService
    participant CTS as CloudSyncService
    participant RDS as DetectionService
    participant ST as SupabaseStorage
    participant PG as PostgresDetections

    User->>PR: Tap Save
    PR->>DBS: insertCapturedPhoto
    DBS-->>PR: photoId
    PR->>DBS: enqueueUpload
    DBS-->>PR: queued
    PR->>CTS: syncInBackground

    CTS->>CTS: check auth user and online state
    alt Online and user exists
        CTS->>DBS: getPendingUploads limit 10
        DBS-->>CTS: pending rows
        loop For each pending row
            CTS->>CTS: check local image file
            alt File exists
                CTS->>RDS: saveDetection image and metadata
                RDS->>ST: upload image
                ST-->>RDS: imageUrl
                RDS->>PG: insert detection row
                PG-->>RDS: success
                RDS-->>CTS: upload success
                CTS->>DBS: markUploadSynced
            else File missing
                CTS->>DBS: markUploadFailed
            end
        end
    else Offline or no user
        CTS-->>CTS: no action queue remains pending
    end
```

## 10) Deployment Diagram

```mermaid
flowchart TD
    subgraph DEV[Development Environment]
        PC[Developer machine]
        IDE[VS Code or Cursor]
        FLUTTER[Flutter SDK]
        DARTDEFINE[Supabase dart define values]
        ADB[ADB]
    end

    subgraph TRAIN[Training Environment]
        YOLO[Ultralytics YOLO training]
        DATASET[Training dataset]
        MODEL[TFLite model export]
    end

    subgraph MOBILE[Mobile Device]
        APP[Flutter app]
        UI[Screens and widgets]
        SVC[Service layer]
        SQLITE[(SQLite pine db)]
        LOCALIMG[(Local image storage)]
        INFER[TFLite runtime]
        HW[Camera GPS Biometric]
    end

    subgraph CLOUD[Supabase]
        SA[Supabase Auth]
        PG[(Postgres with RLS)]
        SB[Supabase Storage]
        B1[detections bucket]
        B2[avatars bucket]
    end

    IDE --> FLUTTER
    FLUTTER --> DARTDEFINE
    PC --> APP
    ADB --> APP
    YOLO --> DATASET
    YOLO --> MODEL
    MODEL --> INFER
    APP --> UI
    UI --> SVC
    SVC --> SQLITE
    SVC --> LOCALIMG
    SVC --> INFER
    SVC --> HW
    SVC --> SA
    SVC --> PG
    SVC --> SB
    SB --> B1
    SB --> B2
```

## 11) Component Architecture Diagram

```mermaid
flowchart TD
    subgraph PRES[Presentation Layer]
        SCREENS[Screens auth dashboard camera fields profile feedback]
        WIDGETS[Widgets sync indicator custom controls charts]
        NAV[Navigation routes and auth gate]
        THEME[Theme material and colors]
    end

    subgraph CORE[Core Layer]
        SL[ServiceLocator]
        AS[AppState with Provider]
        SCP[SupabaseClientProvider]
    end

    subgraph SERVICES[Service Layer]
        subgraph ORCH[Orchestration]
            DFC[DetectionFlowController]
            DSC[DashboardStatsCalculator]
        end
        subgraph CORE_SVC[Core services]
            CS[CameraService]
            IS[InferenceService]
            GS[GeoService]
            GFS[GeoFenceService]
        end
        subgraph DATA_SVC[Data services]
            DBS[DatabaseService]
            RDS[DetectionService]
            ISS[ImageStorageService]
            CTS[CloudSyncService]
        end
        BIO[BiometricService]
    end

    subgraph DATA[Data Layer]
        SQLITE[(SQLite detection captured_photo upload_queue land)]
        SHPREF[(SharedPreferences)]
        PG[(Postgres profiles fields detections)]
        ST[(Storage detections avatars)]
        AUTH[(Supabase Auth)]
    end

    PRES --> CORE
    PRES --> SERVICES
    SL --> SERVICES
    SCP --> SERVICES
    AS --> PRES
    SERVICES --> DATA
    DFC --> CS
    DFC --> IS
    DFC --> GS
    DFC --> GFS
    DFC --> ISS
    DFC --> DBS
    DSC --> PG
    DBS --> SQLITE
    DBS --> SHPREF
    RDS --> PG
    RDS --> ST
    CTS --> DBS
    CTS --> RDS
    SCP --> AUTH
```

## 12) Feedback Flow

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

## 13) Profile Management Flow

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

## 14) Chart Rendering Flow

```mermaid
flowchart TD
    A[RealLineChartPainter] --> B[Receive dailyCounts]
    B --> C[Receive date labels]
    C --> D[Compute point count]
    D --> E[Find peak index and value]
    E --> F[Start paint]

    subgraph GRID[Draw grid]
        F --> G[Draw horizontal grid lines]
        G --> H[Draw y axis labels]
    end

    subgraph AXIS[Draw x axis labels]
        H --> I[Build day labels]
        I --> J{Language mode}
        J -->|Filipino| K[Use Filipino day names]
        J -->|English| L[Use English day names]
    end

    subgraph CURVE[Draw smooth curve]
        K --> M[Build smooth path]
        L --> M
        M --> N[Catmull Rom to Bezier]
        N --> O[Stroke curve]
    end

    subgraph AREA[Draw area fill]
        O --> P[Build area path]
        P --> Q[Apply gradient fill]
    end

    subgraph PEAK[Draw peak marker]
        Q --> R[Draw guide line]
        R --> S[Draw peak dot]
        S --> T[Draw peak value label]
    end

    T --> U[Render chart in diagnose tab]
```
