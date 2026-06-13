# PINYA-PIC — Revision List (with Explanations)

*Use this for panel updates / Chapter 4 “updates” section.*

| Revision / Update | What changed (implementation) | Explanation (why we changed it / impact) |
|---|---|---|
| **Model benchmark updated to v16 (headline)** | v16 corrected test result: **73.3% mAP@0.5**, **80.6% precision**, **64.7% recall**, **40.7% mAP@0.5:0.95** on **1,952** held-out test images (18,891 instances after corrected GT). | Shows the latest highest detector performance under fair evaluation. This is the main update the panel asked for. |
| **Transparent reporting: legacy vs corrected test** | We report both: **~66% mAP@0.5** (legacy labels) vs **73.3%** (corrected test labels). | Prevents over-claiming and explains why the same model can score differently under under-annotated vs corrected ground truth. |
| **Label-quality audit (GroundingDINO)** | Training label audit found many missing boxes (under-annotation). | Object detection mAP depends strongly on ground-truth completeness; missing boxes unfairly penalize correct detections. |
| **Training annotation fix (DINO consensus)** | Added **+17,277** missing boxes on training set; trained v15 as stronger base. | Improved ground-truth quality leads to better learning signal → improves downstream performance. |
| **Self-training refinement (v15 → v16)** | Added **+2,744** boxes using high-confidence v15 predictions; fine-tuned into v16. | Captures remaining missed pests in training annotations to improve recall and generalization. |
| **Fair test-label correction for evaluation** | Test-set corrected using v16 consensus (conf ≥ 0.45) → 18,891 instances, then standard `yolo val`. | Provides a defensible “fair test” protocol consistent with what the detector can realistically detect (avoids impossible GT). |
| **App shipped model updated** | App now points to `assets/model/best.tflite` and sets `shippedModelId = mealybug_v16_selffix`. | Keeps the deployed build aligned with the latest model used in reporting and support logs. |
| **System architecture doc** | `docs/thesis/SYSTEM_ARCHITECTURE.md` — stack tables + Mermaid diagrams (Jun 2026). | Single thesis reference for Flutter, Supabase, TFLite, and ML pipeline. |
| **V20 training pipeline** | Audited labels + from-scratch YOLO26s/m on H100 (2026-06-10). | Data-first revision after v19 failure; see `docs/V20_TRAINING_LOG.md`. |
| **Deployment threshold standardized** | `detectionThreshold = 0.25` (app operational floor). | Slightly lower than 0.30 to improve recall; may increase false positives — users verify visually before control. |
| **Input size aligned for v16 deployment** | `inputSize = 640` in app constants (matches the exported on-device TFLite input). | Ensures the app’s model input matches the shipped TensorFlow Lite model for consistent detection behavior. |
| **Capture flow updated to “field-first”** | Camera → **Choose Field (or Unassigned)** → Camera/Gallery → Analyzing → Results → Save. | Reduces post-processing steps and ensures saved scans are already associated with the correct field. |
| **Guest option added** | Welcome screen now includes **“Continue as guest”** (scan-only). | Lowers onboarding friction for demos/panel and for first-time users; lets them try scanning without account setup. |
| **Terms & Privacy acceptance gate** | Terms/Privacy acceptance required before guest/login/sign-up; saved via local preferences. | Required for compliance/ethical handling of data; ensures users consent before using the system. |
| **Guest-mode restrictions clearly enforced** | Guest scans show “not saved” messaging; account-required features prompt sign-in. | Prevents confusion: guest mode is demo/try-scan only, while tracking/history requires an account. |
| **Out-of-bounds check before saving** | Before Save: check if GPS point is **inside selected field boundary**; if outside → modal **“Out of bounds / Labas sa piniling field”** and block saving. | Prevents incorrect field records and improves data integrity (scans should belong to the correct field location). |
| **Location-required guard** | If no GPS/tagged location available, app blocks save and prompts user to enable GPS or tap map. | Ensures saved records have reliable geotags for mapping, history, and field analytics. |
| **Offline-first saving + upload queue** | Save always writes locally first; if online and logged in, upload sync runs; otherwise queued for later. | Makes the app usable in real farms with unstable connectivity while still supporting cloud sync when possible. |
| **Severity-based “Insights” implemented** | App computes severity from count/confidence and shows one of 5 insights: none/low/medium/high/critical with guidance. | Connects detection output to actionable next steps, improving usefulness beyond “just a number.” |
| **Field history analytics page added (new)** | Added **Field history** screen: range filters (7/30/90/all), summary stats, daily counts chart, recent scans list. | Implements the “historical data” objective: users/panel can see trends per field over time using saved captures. |
| **Panel update materials prepared** | Updated slides (`panel_video_slides.html`), graphs regenerated, and a 3–5 minute update-video script. | Makes it easy to present updates clearly and consistently, with citations and correct metric interpretation. |
| **Confusion-case qualitative analysis (Ch. IV)** | Script `export_confusion_cases.py` exports TP / FP / FN / poor-localization crops from v16 @ conf 0.30 on corrected test labels → `docs/thesis/CONFUSION_CASES_V16.md` + `docs/thesis/assets/confusion_cases_v16/`. | Panel guidance #7: honest, transparent error analysis beyond aggregate mAP/recall. |
| **Decision-support advisory messaging** | Centralized in `lib/data/detection_advisory_messages.dart`; app no longer implies “healthy plant” on negative scans. Negative: “No mealybug detected **in this image**” + rescan/manual inspect. Positive: “**Possible** mealybug detected — verify visually before control.” | Panel guidance #8: safer UX aligned with 64.7% recall — model output is scouting support, not final diagnosis. |
| **V18 panel revision plan** | `docs/training/V18_PANEL_REVISION_PLAN.md` + `V18_PROGRESS_LOG.md` — phased plan for guidance #1–#6 (recall, data, labels, aug, imgsz, YOLO26 n/s/m). | Roadmap to resubmission with dates, commands, and success tiers. |
| **85% all-metrics plan** | `docs/training/PLAN_TO_85_ALL_METRICS.md` — v20 label audit → hard data → YOLO26m → gated self-train v21 → ensemble fallback. | Explicit path to panel targets: mAP@0.5 ≥85%, R ≥80%, mAP@0.5:0.95 ≥55%. |

## Notes (for panel)
- This is still **work in progress**; results may change with continued training and re-validation on v16 deployed build.
- Do not equate **mAP**, **F1**, and **SUS**—they measure different evaluation questions.

