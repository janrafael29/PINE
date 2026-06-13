# CHAPTER IV — RESULTS AND DISCUSSION (full revised text)

**Instructions:** Replace your current Chapter IV body with the text below. Keep your existing figures (25–30) and renumber tables as noted. Update the **List of Tables** to include Tables 15–21.

**Key corrections applied:**
- Final model = **mealybug_v13afix** (not v11/v12 as deployed)
- Primary benchmark = **61.0% mAP@0.5** (native test, 1,952 images)
- Fixed comparison benchmark = **56.7% mAP@0.5** (462 images); v2→v13afix table added
- Manual expert validation (VAL1–VAL3) added with full tables — **not mAP**
- Single deploy threshold = **30% (0.30)** everywhere (removed possible/confirmed split and 20% references)
- Fixed duplicate section numbers (4.1.2 / 4.1.3 appeared twice)
- Separated field-deployment confidence (33.2% mean) from benchmark mAP
- Updated §4.4 Summary and cross-references

---

## CHAPTER IV
## RESULTS AND DISCUSSION

### 4.0 System Features and Functionalities

The PINYA-PIC mobile application was successfully implemented as a local-first, Android-based tool for documenting and reviewing mealybug infestations in pineapple plantations. The application is organized around authentication and onboarding, dashboard navigation, field management, still-image detection, saved-image history, map-based review, profile and settings flows, and cloud-backed restoration of uploaded detections. This section describes the implemented behavior of the system.

#### 4.0.1 Authentication and Onboarding

The authentication and onboarding subsystem provides a staged first-use flow. On first launch, users accept the terms and privacy requirements. After that, the application presents an introduction flow and welcome screen before registration or login. Registration and login are backed by Supabase Auth. After a successful sign-in, users without a display name are redirected to the nickname prompt, and users may also be shown an opt-in prompt for device unlock.

Device unlock is implemented as an optional post-login protection layer. Once enabled, the application requires biometric or device-credential authentication before the user can access the main dashboard on a new app run. This behavior can later be changed in Settings.

#### 4.0.2 Dashboard and Navigation

After sign-in, the user enters the Main Dashboard. The bottom navigation contains four content tabs—Home, Diagnose, My Fields, and More—plus a central Scan action that opens the photo source picker. This means the user sees five navigation items, but the central camera button is an action rather than a persistent content page.

The Home tab includes greeting text, a recent saved-images strip, a horizontal field list, and a non-editable map preview. The Diagnose tab displays summary statistics and a 7-day line chart of detection counts. The My Fields tab provides field cards and a Reminders sub-tab. The More tab provides access to educational content, settings, support pages, and related screens.

#### 4.0.3 Field and Plot Management

The implemented system is field-focused rather than plot-focused. Users can create a field, add a preview image, store an address label, and define or revise the field boundary using the map-based boundary editor. They can also edit existing fields from explicit edit buttons or menu actions in the interface. The application does not implement a separate active plot data model.

Field-related media is handled through the field detail and manage-field-photos flows. Recent detections can also be assigned to a field after capture, allowing the gallery and dashboard to remain useful even when a user did not select a field before scanning.

#### 4.0.4 Camera and Detection Pipeline

The detection pipeline is **still-image based**. When the user taps Scan, the application opens a source picker that uses the Android camera flow or gallery selection rather than a continuous live video stream. For camera capture, the application requests a still image and then runs inference on the saved bytes. For gallery images, the application can optionally ask where the photo was taken so that the user can pin the location on a map when the original image lacks GPS metadata.

After image acquisition, the application preprocesses the image through EXIF-aware orientation handling, resize/letterboxing to 640×640, normalization, and coordinate transform tracking. The bundled **mealybug_v13afix** TensorFlow Lite detector is then executed within the inference service. The output is parsed, confidence-filtered at **0.30 (30%)**, and processed with Dart-side Non-Maximum Suppression. The resulting detection set includes bounding boxes, count, and per-detection confidence values displayed on result and detail screens.

Spatial metadata is collected from available sources such as current GPS, last-known GPS, EXIF GPS, or manual map pins. The geofence service then performs a local point-in-polygon check against stored field boundaries. The finished result is saved locally to the captured-photo history and, when appropriate, inserted into the upload queue for later cloud synchronization.

#### 4.0.5 Geospatial Services

Geospatial features provide spatial context for saved detections. Field boundaries are stored locally and can be mirrored to the cloud through the boundary_json field of the fields table. The map experience includes a preview map on the Home tab, a dedicated detections map screen, boundary-aware location selection, and severity-based marker rendering.

The application’s geofencing is implemented as local point-in-polygon logic rather than background operating-system geofence triggers. This means the system checks whether a coordinate falls inside a known field boundary when needed for validation, display, and field association, but it does not continuously monitor entry and exit events in the background.

The detections map also supports severity-based visualization. Severity is derived from bug count and confidence and is mapped to color and glow intensity so that users can visually identify more serious areas of concern.

#### 4.0.6 Offline Synchronization

The application follows a local-first workflow. New captures are stored locally before cloud upload. SQLite keeps the field boundary data, saved-image history, pending upload queue, and cached field metadata needed for offline use. When the device is offline, users can continue creating local records and reviewing previously saved content.

When the user is signed in and connectivity becomes available, the synchronization service attempts to upload pending records to Supabase. The upload path links local rows to remote detection identifiers and image URLs after successful upload. Synchronization is triggered through save, refresh, and dashboard-entry paths rather than through an always-running background connectivity listener.

Account-linked restoration complements offline synchronization. After sign-in, previously uploaded detections can be pulled from Supabase into the local gallery. Only records that already reached the cloud can be restored; purely offline, unsynchronized detections remain local-only and are lost after reinstallation.

#### 4.0.7 Analytics and Visualization

The Diagnose tab summarizes recent activity through three headline statistics and a 7-day trend chart. The statistics report image count, field count, and infestation rate over the recent period. The trend chart uses a smooth-curve presentation with peak highlighting to improve readability for non-technical users.

The dashboard can use either cloud-backed or local data depending on current availability. This design helps the application remain useful even when connectivity is unreliable. Figure 25 shows the Diagnose tab with sample data; the chart uses peak highlighting on the highest daily count to help users identify the most active infestation period.

**Figure 25.** Diagnose Tab: 7-Day Infestation Trend

#### 4.0.8 Feedback System

The feedback system includes two implemented paths. The first is email feedback, which opens a mail client when available and falls back to a copy-to-clipboard dialog when no mail handler is present. The second is an in-app feedback form that submits JSON payloads to a web endpoint. Both flows are guarded by online checks when needed.

This design provides a more resilient support experience than relying on only one feedback channel. If a device cannot launch a mail app, the user can still copy the destination email address. If the user prefers structured submission, the in-app form provides a direct path to the configured endpoint.

#### 4.0.9 Profile Management

The Profile page allows the user to manage display name, email, phone number, and avatar. Profile images are uploaded to Supabase Storage, and a cache-busting parameter is appended to the URL so updated images appear immediately. The page also shows profile-related status information and supports editing without leaving the application.

#### 4.0.10 Network Awareness

Network awareness is handled through both user-interface and background-synchronization checks. For user-interface flows, the application verifies that a usable network interface exists before attempting actions such as opening online-only pages or submitting web-based feedback. For background synchronization, the application uses a stricter reachability check so that synchronization proceeds only when internet access appears genuinely available.

This distinction improves usability by avoiding unnecessary blocking of UI flows when direct DNS checks fail but ordinary app traffic may still work.

#### 4.0.11 Saved Images Gallery and Account-Linked Restoration

The saved-images experience is one of the application’s central features. The Home tab shows recent captures, while the dedicated captured-photos flows provide expanded review, detail viewing, and assign-to-field actions. Each saved row can include image path, count, confidence, field association, location, and remote linkage.

After a reinstall, the application can restore already uploaded detections by inserting remotely linked rows into the local gallery. In this case, the interface may display the remote image URL when the original local file is missing. A current limitation is that per-box detection data are not restored from the server, so restored rows may lack the full historical overlay detail available in the original local capture.

---

### 4.1 Model Performance Evaluation

Object-detection performance in PINYA-PIC is reported using **three complementary evaluation types** that must not be conflated:

1. **Benchmark mAP@0.5** — Ultralytics validation on large labeled test splits (conf = 0.12, IoU = 0.45, imgsz = 640).
2. **Model evolution comparison** — Same fixed 462-image test set across training generations (v2 → v13afix).
3. **Manual expert validation** — Expert-reviewed TP/FP/FN on 12 field images at the **30% deploy threshold**; this is **not** mAP.

The **final deployed model** is **mealybug_v13afix** (YOLO26n → TensorFlow Lite @ 640×640). Earlier YOLO11 and intermediate YOLO26n validation figures are retained only as **development history**.

#### 4.1.1 Historical Development Baselines

Earlier training experiments produced the validation metrics summarized in **Table 4**, which compares an archived YOLO11n baseline with an intermediate YOLO26n training run. These results reflect **intermediate validation during model development** and are **not** the final deployed benchmark.

**Table 4.** Development Baseline (Early YOLO11n vs. Intermediate YOLO26n Validation Metrics)

| Metric | YOLO11n (archived baseline, leg 2 epoch 34) | YOLO26n (validation during training, best epoch 49) |
|--------|---------------------------------------------:|----------------------------------------------------:|
| Precision | 0.667 | 0.707 |
| Recall | 0.462 | 0.594 |
| mAP@0.5 | 0.526 | 0.651 |
| mAP@0.5:0.95 | 0.247 | 0.297 |

The intermediate YOLO26n run achieved **65.1% mAP@0.5** on its training validation split. That value summarizes precision–recall integrated across confidence levels on the validation set used during that training run. It should **not** be cited as the final deployed model result.

**Figure 26** presents training and validation performance curves for the intermediate YOLO26n run across 50 epochs. The curves show convergence of precision, recall, mAP@0.5, and mAP@0.5:0.95. These curves document training progress only; the shipped application uses the later **mealybug_v13afix** checkpoint retrained on an expanded and refined dataset pool.

**Figure 26.** YOLO26n Training Performance Curves (Precision, Recall, mAP) — intermediate development run

Definitions of precision, recall, and mAP at IoU 0.5 and 0.5:0.95 are discussed in Section 3.3.2.1.6.

#### 4.1.2 Final Deployed Model — mealybug_v13afix

The final model deployed in PINYA-PIC is **mealybug_v13afix**, retrained through multiple dataset refinement stages on a 19,520-image pool (70/20/10 train/val/test resplit, seed 42). Two benchmark protocols were used to characterize the final checkpoint.

**Protocol A — Native holdout test (primary headline metric)**

Evaluation on the held-out test split from the **mealybug_v13afix** dataset distribution.

**Table 15.** mealybug_v13afix Native Benchmark (conf = 0.12, IoU = 0.45, imgsz = 640)

| Split | Images | Precision | Recall | F1 | mAP@0.5 | mAP@0.5:0.95 |
|-------|-------:|----------:|-------:|---:|--------:|-------------:|
| Val | 3,904 | 71.2% | 57.7% | 63.8% | 59.6% | 28.4% |
| **Test** | **1,952** | **72.8%** | **58.9%** | **65.1%** | **61.0%** | **29.2%** |

On the native test split, mealybug_v13afix achieved **61.0% mAP@0.5**. For a single-class detector, AP@0.5 equals mAP@0.5.

**Protocol B — Fixed benchmark test (462 images)**

Evaluation on a consistent Roboflow v10 export holdout used to compare model generations fairly.

**Table 16.** mealybug_v13afix on Fixed v10 Test Split (n = 462 images; same protocol)

| Metric | Value |
|--------|------:|
| Test images | 462 |
| Precision @ conf 0.12 | 64.3% |
| Recall @ conf 0.12 | 59.7% |
| F1 | 61.9% |
| **mAP@0.5** | **56.7%** |
| mAP@0.5:0.95 | 24.6% |

These two protocols answer different questions: Protocol A reports performance on the **final model’s own holdout**; Protocol B reports **comparability** against earlier checkpoints on an unchanged test set. **Table 15 should be used as the primary final-model headline**; Table 16 supports lineage comparison.

On-device behavior may differ slightly from Ultralytics PyTorch evaluation due to TensorFlow Lite export, letterboxing, and Dart-side NMS at the **0.30 deploy threshold**.

#### 4.1.3 Model Evolution — v2 through v13afix

To quantify improvement across training iterations, all models below were evaluated on the **same** Roboflow v10 export: 923 validation and **462 test** images (`mealybug.v10-8th-yolo26n.yolo26`), at conf = 0.12, IoU = 0.45, imgsz = 640.

**Table 17.** Model Comparison on 462-Image Test Split (conf = 0.12, IoU = 0.45)

| Model | Training data | Precision | Recall | F1 | **mAP@0.5** | mAP@0.5:0.95 |
|-------|---------------|----------:|-------:|---:|------------:|-------------:|
| v2 | Legacy ~2.3k | 41.1% | 38.6% | 39.8% | **21.1%** | 7.8% |
| v10 | v10 (~16k aug train) | 55.7% | 49.4% | 52.4% | **42.1%** | 16.7% |
| v11 | v10 (label refinement) | 56.2% | 49.2% | 52.5% | **43.0%** | 16.8% |
| v12 | v10 @ 1024 train | 58.6% | 51.3% | 54.7% | **43.8%** | 16.9% |
| **v13afix** | v13afix src pool (deployed) | **64.3%** | **59.7%** | **61.9%** | **56.7%** | **24.6%** |

**Test mAP@0.5 progression:** 21.1% → 42.1% → 43.0% → 43.8% → **56.7%** (v2 → v10 → v11 → v12 → v13afix).

The legacy v2 baseline more than **doubled** in mAP@0.5 after the full v10 training pipeline; v13afix added a further **+12.9 percentage points** over v12 on this fixed benchmark. v2 was trained on an earlier smaller split; all rows in Table 17 evaluate each checkpoint on the **same** v10 test set for fair comparison.

*Limitation:* v13afix was trained on a reshuffled 19.5k pool; some v10 benchmark images may appear in v13afix training. Table 17 should therefore be interpreted as **relative improvement**, while Table 15 reports the **primary unbiased native holdout** for the final model.

#### 4.1.4 Manual Expert Validation — Field Test Photos (VAL1–VAL3)

During on-field testing (May 2026), three validators independently reviewed application outputs on assigned image sets (four images each, 12 total). For each image, experts counted ground-truth mealybugs and compared them to detections from the deployed **v13afix** TFLite pipeline at the **30% operational threshold**.

**Method:**
- **TP:** detected box matched a real mealybug (expert judgment)
- **FP:** detection with no corresponding mealybug
- **FN:** mealybug present but not detected
- **Precision** = TP / (TP + FP); **Recall** = TP / (TP + FN); **F1** = harmonic mean
- **Accuracy** = TP / (TP + FP + FN) per image, then averaged within each validator set
- **Avg detection confidence:** mean of per-box confidence scores shown by the app (%)

These metrics reflect **expert-reviewed correctness at one operating point**. They **do not** represent mAP@0.5 and must not be converted to mAP.

**Table 18.** Validator 1 (VAL1)

| Image | Total pop. | TP | FP | FN | Precision | Recall | F1 | Accuracy | Avg conf. |
|------:|-----------:|---:|---:|---:|----------:|-------:|---:|---------:|----------:|
| 1 | 10 | 6 | 0 | 4 | 100.00% | 60.00% | 75.00% | 60.00% | 51% |
| 2 | 26 | 19 | 1 | 6 | 95.00% | 76.00% | 84.44% | 73.08% | 53% |
| 3 | 9 | 8 | 0 | 1 | 100.00% | 88.89% | 94.12% | 88.89% | 58% |
| 4 | 9 | 8 | 0 | 1 | 100.00% | 88.89% | 94.12% | 88.89% | 56% |
| **Average** | — | — | — | — | **98.75%** | **78.44%** | **86.92%** | **77.71%** | **54.50%** |

**Table 19.** Validator 2 (VAL2)

| Image | Total pop. | TP | FP | FN | Precision | Recall | F1 | Accuracy | Avg conf. |
|------:|-----------:|---:|---:|---:|----------:|-------:|---:|---------:|----------:|
| 1 | 14 | 11 | 0 | 3 | 100.00% | 78.57% | 88.00% | 78.57% | 55% |
| 2 | 12 | 11 | 0 | 1 | 100.00% | 91.67% | 95.65% | 91.67% | 47% |
| 3 | 4 | 4 | 0 | 0 | 100.00% | 100.00% | 100.00% | 100.00% | 55% |
| 4 | 3 | 3 | 0 | 0 | 100.00% | 100.00% | 100.00% | 100.00% | 74% |
| **Average** | — | — | — | — | **100.00%** | **92.56%** | **95.91%** | **92.56%** | **57.75%** |

**Table 20.** Validator 3 (VAL3)

| Image | Total pop. | TP | FP | FN | Precision | Recall | F1 | Accuracy | Avg conf. |
|------:|-----------:|---:|---:|---:|----------:|-------:|---:|---------:|----------:|
| 1 | 14 | 12 | 0 | 2 | 100.00% | 85.71% | 92.31% | 85.71% | 65% |
| 2 | 6 | 5 | 0 | 1 | 100.00% | 83.33% | 90.91% | 83.33% | 52% |
| 3 | 9 | 8 | 0 | 1 | 100.00% | 88.89% | 94.12% | 88.89% | 74% |
| 4 | 7 | 6 | 0 | 1 | 100.00% | 85.71% | 92.31% | 85.71% | 48% |
| **Average** | — | — | — | — | **100.00%** | **85.91%** | **92.41%** | **85.91%** | **59.75%** |

**Table 21.** Overall Expert Validation Summary

| Source | Precision | Recall | F1 | Accuracy | Avg detection confidence |
|--------|----------:|-------:|---:|---------:|-------------------------:|
| VAL1 | 98.75% | 78.44% | 86.92% | 77.71% | 54.50% |
| VAL2 | 100.00% | 92.56% | 95.91% | 92.56% | 57.75% |
| VAL3 | 100.00% | 85.91% | 92.41% | 85.91% | 59.75% |
| **Grand average** | **99.58%** | **85.64%** | **91.75%** | **85.40%** | **57.33%** |

Pooled counts across all 12 images: TP = 101, FP = 1, FN = 21 (122 ground-truth instances).

Manual expert validation yielded a grand-average **F1 of 91.75%**, **precision of 99.58%**, and **recall of 85.64%**, with mean detection confidence **57.33%**. These results complement—but do not replace—the benchmark mAP values in Tables 15 and 17.

#### 4.1.5 Deploy Confidence Threshold

The deployed application uses a **single confidence threshold of 0.30 (30%)** for all user-visible detections: bounding-box display, mealybug count, severity score, and saved records (`AppConstants.detectionThreshold`). There is no separate “possible” vs. “confirmed” tier in the current UI.

Benchmark mAP reporting uses **conf = 0.12**, following common practice for comparing detectors across studies. The 30% deploy threshold was chosen to balance sensitivity and usability for small, low-contrast mealybugs in field photos (see Section 3.3.2.1.5). An optional **Accuracy mode** in settings can use a lower threshold for users who prioritize recall.

**Table 5.** Deploy vs. Benchmark Confidence Settings

| Setting | Value | Purpose |
|---------|------:|---------|
| Deploy filter (app) | **0.30 (30%)** | Show boxes, count, severity, save |
| Benchmark mAP (Ultralytics) | 0.12 | Cross-model comparison (Tables 15–17) |
| NMS IoU | 0.45 | Duplicate box suppression |

Per-detection confidence shown in the UI (0–100%) is **not** the same quantity as mAP@0.5.

#### 4.1.6 Inference Performance

Implementation testing on representative Android devices reported approximate inference times of **150 ms** on a mid-range device and **280 ms** on a budget device after warm-up. These figures are indicative, not exhaustive benchmarks.

The application performs **still-image detection**, not continuous video processing, which reduces sustained computational load. Response times in the 150–280 ms range fall within user-acceptable latency for touch-based mobile interactions (Ritter et al., 2015; Stach et al., 2024).

**Table 6.** Inference Time by Device

| Device class | Indicative inference time (ms) |
|--------------|-------------------------------:|
| Mid-range Android (6–8 GB RAM, mid-tier SoC) | 150 |
| Budget Android (3–4 GB RAM, entry-level SoC) | 280 |

#### 4.1.7 Model Size Optimization

The bundled TensorFlow Lite model used in the mobile application has a documented size of approximately **5.42 MB**, supporting efficient packaging and installation on farmer-grade devices.

**Table 7.** Model Size After Export

| Format | Size (MB) |
|--------|----------:|
| Bundled TensorFlow Lite model (mealybug_v13afix) | 5.42 |

---

### 4.2 Usability Evaluation Results

#### 4.2.1 Participant Demographics

Twelve independent pineapple farmers from Polomolok, South Cotabato, participated in the usability evaluation. They were recruited based on inclusion criteria: minimum five years of farming experience, direct experience with mealybug infestations, and varied technology experience. **Table 8** summarizes their demographics.

**Table 8.** Participant Demographics

| ID | Age | Farming Exp. (yrs) | Technology Comfort | Smartphone OS |
|----|----:|-------------------:|:-------------------|:--------------|
| P01 | 45 | 20 | Basic | Android |
| P02 | 32 | 8 | Advanced | Android |
| P03 | 52 | 30 | Basic | Android |
| P04 | 38 | 15 | Intermediate | Android |
| P05 | 48 | 22 | Basic | Android |
| P06 | 41 | 18 | Intermediate | Android |
| P07 | 29 | 5 | Advanced | Android |
| P08 | 55 | 35 | Basic | Android |
| P09 | 35 | 12 | Advanced | Android |
| P10 | 50 | 25 | Basic | Android |
| P11 | 43 | 22 | Advanced | Android |
| P12 | 39 | 17 | Intermediate | Android |

Age ranged from 29 to 55 years (mean = 42.3). Farming experience ranged from 5 to 35 years (mean = 19.1). Technology comfort was self-reported as basic (5), intermediate (3), or advanced (4). All participants used Android smartphones.

#### 4.2.2 SUS Scores for Valid Respondents (n = 10)

Although 12 farmers participated overall, only **10 valid completed SUS questionnaires** were available for quantitative scoring. **Table 9** presents individual scores.

**Table 9.** SUS Scores for Valid Respondents (n = 10)

| ID | SUS Score |
|----|----------:|
| P01 | 67.5 |
| P02 | 95.0 |
| P03 | 65.0 |
| P04 | 85.0 |
| P05 | 65.0 |
| P06 | 80.0 |
| P07 | 95.0 |
| P08 | 65.0 |
| P09 | 87.5 |
| P10 | 65.0 |

The mean SUS score was **77.0** (SD = 12.9). **Table 10** shows the distribution.

**Table 10.** SUS Score Distribution

| Score range | Interpretation | Count | Percentage |
|-------------|----------------|------:|-----------:|
| 90–100 | Excellent | 2 | 20% |
| 80–89 | Good | 3 | 30% |
| 70–79 | Acceptable | 0 | 0% |
| 60–69 | Marginal | 5 | 50% |
| <50 | Poor | 0 | 0% |

The mean score of **77.0** exceeds the industry average of 68 (Sauro, 2011), indicating above-average perceived usability. No valid respondent rated the application as “Poor.”

#### 4.2.3 Per-Question Analysis

**Table 11** presents mean scores per SUS item (n = 10).

**Table 11.** Mean Scores per SUS Item

| Item | Statement | Mean |
|-----:|-----------|-----:|
| 1 | I think that I would like to use this system frequently. | 4.4 |
| 2 | I found the system unnecessarily complex. *(reverse)* | 4.2 |
| 3 | I thought the system was easy to use. | 4.5 |
| 4 | I think that I would need the support of a technical person. *(reverse)* | 4.2 |
| 5 | I found the various functions well integrated. | 4.4 |
| 6 | I thought there was too much inconsistency. *(reverse)* | 4.3 |
| 7 | I would imagine most people would learn to use this quickly. | 4.3 |
| 8 | I found the system very cumbersome. *(reverse)* | 4.2 |
| 9 | I felt very confident using the system. | 4.3 |
| 10 | I needed to learn a lot before I could get going. *(reverse)* | 4.3 |

Highest-rated items were Q3 (easy to use, 4.5), Q1 (would use frequently, 4.4), and Q5 (functions integrated, 4.4).

#### 4.2.4 Qualitative Feedback Analysis

*(Keep your existing qualitative themes: offline functionality, field editing, chart peak highlighting, geo errors, feedback buttons, camera detection, network awareness, device unlock, cloud gallery, severity map — no factual changes required.)*

#### 4.2.5 Task Completion Analysis

All 12 participants completed all tasks. **Table 12** summarizes average completion times.

**Table 12.** Task Completion Times

| Task | Average time (min) |
|------|-------------------:|
| Create user account | 2.3 |
| Log in with biometrics | 0.5 |
| Create new field | 1.8 |
| Edit existing field (edit button / menu) | 0.4 |
| Capture photo and detect | 0.9 |
| Interpret trend chart | 0.3 |
| Submit feedback (email fallback) | 0.7 |
| Offline detection | 1.1 |
| Online sync after reconnection | 0.5 |
| Enable device unlock and verify | 0.4 |
| Toggle Filipino language | 0.2 |
| View saved images gallery | 0.3 |

#### 4.2.6 Correlation Analysis

**Table 13** shows Pearson correlations between SUS scores and demographics (n = 10 valid SUS respondents).

**Table 13.** Correlation with SUS Score

| Variable | Pearson *r* | *p*-value |
|----------|------------:|----------:|
| Technology comfort | 0.62 | 0.03* |
| Age | −0.18 | 0.62 |
| Farming experience | −0.12 | 0.74 |

Technology comfort correlated positively with SUS score (*r* = 0.62, *p* < 0.05). Age and farming experience showed no significant correlation.

---

### 4.3 Real-World Deployment Statistics

Following usability evaluation, PINYA-PIC was deployed for a three-day field test (May 9–11, 2026) in Polomolok, South Cotabato. The deployment covered **14 registered accounts** and **12 active fields**. This dataset is **distinct** from the 12-person SUS sample (Section 4.2) and from the 12-image expert validation set (Section 4.1.4).

#### 4.3.1 Overall Detection Metrics

A total of **826 detection operations** were performed. The model counted **4,670 mealybugs** across all fields. The **mean per-detection confidence** was **33.2%**, with field-level means from 25.9% to 37.7%. The highest single-image confidence was 75% (1 mealybug); the highest count in one image was 22 mealybugs (35% mean confidence). **Table 14** summarizes per-field results.

**Table 14.** Summary of Field Detections (May 9–11, 2026)

| Farmer | Field | Detections | Total mealybugs | Avg confidence (%) |
|--------|-------|----------:|---------------:|-------------------:|
| Fedelbert | Fedelbert | 115 | 691 | 34.2 |
| Albert | albert | 87 | 409 | 32.2 |
| Adonis | Adonis | 76 | 297 | 32.8 |
| Paulino | Paulino | 76 | 486 | 34.6 |
| Florina | Florina | 73 | 192 | 25.9 |
| Apreel | Apreel | 69 | 232 | 32.4 |
| Merlyn | Merlyn | 67 | 563 | 35.2 |
| Jojo | Jojo | 67 | 301 | 32.7 |
| Rebbecca | Rebbecca | 55 | 370 | 34.5 |
| George | George | 48 | 490 | 37.7 |
| Moso | Moso | 48 | 490 | 37.7 |
| Joever | Joever | 45 | 149 | 31.5 |
| **Total / Mean** | — | **826** | **4,670** | **33.2** |

These statistics describe **operational usage** of the deployed **mealybug_v13afix** detector. They show that the system consistently flagged infestations in every field during the test window. The moderate mean confidence (33.2%) is expected for small, clustered mealybugs under variable field lighting and distance; it reflects **per-box scores shown in the UI**, not mAP@0.5.

#### 4.3.2 Confidence Score Distribution

Across 826 operations, most detections fell in the **20–40%** confidence band, with a tail extending to 75%. A small fraction scored below 10%, reflecting difficult visual conditions.

Because the deploy filter is **30%**, boxes below that threshold are not shown or counted in the app. The deployment mean of **33.2%** is therefore consistent with filtering near the operating point. This distribution supports operational use of the **0.30 threshold**; it does **not** substitute for labeled benchmark evaluation (Tables 15–17) or expert TP/FP/FN review (Tables 18–21).

#### 4.3.3 Geotagging and Spatial Consistency

Every detection record included valid latitude and longitude (approx. 6.29–6.35°N, 125.07–125.14°E), consistent with Polomolok. All fields in Supabase contained valid boundary_json polygons for geofencing checks.

#### 4.3.4 Synchronization and Offline Operation

All 826 detections synchronized successfully to Supabase during the test window (upload_queue empty). Average capture-to-cloud latency was under 2 seconds. Offline-first behavior was validated in separate functional testing (Section 3.4.6).

#### 4.3.5 Comparison with Benchmark and Expert Validation Metrics

Three metric families must be kept separate:

| Metric family | Example value | What it measures |
|---------------|--------------:|------------------|
| Benchmark mAP@0.5 | **61.0%** (Table 15) | Box-level accuracy vs. labels on 1,952-image test split |
| Fixed-benchmark mAP@0.5 | **56.7%** (Table 16–17) | Same, on 462-image comparison set |
| Expert validation F1 | **91.75%** (Table 21) | Expert TP/FP/FN on 12 field images @ 30% threshold |
| Deployment mean confidence | **33.2%** (Table 14) | Average per-box UI score during 826 operations — **not mAP** |

Field confidence statistics indicate **how confidently the model scored retained boxes in production use**. They must not be reported as mAP or as “81% accuracy.” The expert validation F1 (91.75%) reflects human review on a small labeled subset and likewise must not be labeled mAP.

---

### 4.4 Summary of Results

PINYA-PIC was successfully implemented and evaluated as a functional system for agricultural pest monitoring in low-connectivity environments.

**Model performance.** The deployed **mealybug_v13afix** detector achieved **61.0% mAP@0.5** on its native held-out test split (1,952 images) and **56.7% mAP@0.5** on a fixed 462-image comparison set—substantial improvement over the legacy v2 baseline (21.1% mAP@0.5). Manual expert validation on 12 field images reported **91.75% F1**, **99.58% precision**, and **85.64% recall** at the **30% deploy threshold**; this expert review complements but does not replace mAP. Historical development metrics (Table 4; mAP@0.5 = 0.526 for YOLO11n) document earlier training stages only.

**System architecture.** Local-first storage (SQLite), optional Supabase sync, geotagging, geofencing, severity mapping, network reachability, device unlock, Filipino language support, and account-linked gallery restoration were implemented and functionally verified.

**Usability.** Twelve farmers participated; **10 valid SUS responses** yielded a mean score of **77.0** (SD = 12.9), above the industry benchmark of 68. All task scenarios were completed successfully.

**Field deployment.** Over three days (May 9–11, 2026), **826 detection operations** counted **4,670 mealybugs** across **12 fields**, with a mean per-detection confidence of **33.2%**. Geotagging, boundary data, and cloud sync operated consistently.

Overall, PINYA-PIC provides on-device mealybug detection, spatial tracking, and accessible visualization suitable for pineapple farmers in Polomolok. Results support its use as a **decision-support and screening tool**, with benchmark mAP, expert validation, and operational deployment statistics reported under clearly separated definitions.

---

## Also update elsewhere in the thesis

### Abstract — add after SUS sentence

> On a held-out labeled test set (1,952 images), the final mealybug_v13afix detector achieved **61.0% mAP@0.5**; manual expert validation on 12 field images yielded **91.75% F1**.

### Chapter I §1.3 Scope — replace validation caveat paragraph with:

> Final model benchmark: **61.0% mAP@0.5** on the native mealybug_v13afix test split; **56.7% mAP@0.5** on a fixed 462-image comparison set. Earlier validation figures (e.g., mAP@0.5 = 0.526) are historical development baselines only.

### Chapter V §5.0 Conclusion — replace outdated mAP emphasis with Table 15 / 16 / 21 values (see §4.4 above).

### User Manual §4.4 — change:

> ~~A confidence score of 20% or higher is the minimum threshold~~

**To:**

> Detections are shown only when confidence is **30% or higher**. Higher percentages indicate greater model certainty.

### List of Tables — add

| Table | Title |
|-------|-------|
| 15 | mealybug_v13afix Native Benchmark |
| 16 | mealybug_v13afix on Fixed 462-Image Test Split |
| 17 | Model Comparison v2 through v13afix (462-image test) |
| 18 | Manual Expert Validation — VAL1 |
| 19 | Manual Expert Validation — VAL2 |
| 20 | Manual Expert Validation — VAL3 |
| 21 | Overall Expert Validation Summary |

### Table of Contents — fix §4.1 numbering

```
4.1 Model Performance Evaluation
  4.1.1 Historical Development Baselines
  4.1.2 Final Deployed Model — mealybug_v13afix
  4.1.3 Model Evolution — v2 through v13afix
  4.1.4 Manual Expert Validation (VAL1–VAL3)
  4.1.5 Deploy Confidence Threshold
  4.1.6 Inference Performance
  4.1.7 Model Size Optimization
```
