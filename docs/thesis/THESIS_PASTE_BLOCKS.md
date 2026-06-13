# Thesis Paste Blocks (Word-ready)

**Updated:** June 12, 2026  
Copy each section into your thesis document. Adjust heading numbers to match your chapter structure.

---

## Abstract (replace or append closing sentences)

PINYA-PIC is implemented as a **mealybug detection collector and decision-support middleware**, not a deployment-ready field diagnostic. The mobile application uses an on-device YOLO26s TensorFlow Lite model (`mealybug_v16_selffix`) to flag possible mealybug presence in geotagged leaf images and automatically submits each scan as a per-image report. Positive detections feed outbreak maps and Department of Agriculture (DA) / OMAG analytics; negative scans remain in the audit log but are excluded from map visualization. On the corrected held-out test protocol, the shipped model achieved 73.3% mAP@0.5 and 64.7% recall—below the panel’s deployability targets despite a full revision cycle (v20–v22). The system demonstrates feasibility as a scouting and reporting aid but requires further field validation, additional hard-case imagery, and expert consultation before any deployment claim.

---

## Chapter I — Positioning paragraph (Background or Scope)

PINYA-PIC operates as a **detection collector and agricultural decision-support middleware** bridging farmers and extension authorities. Farmers capture geotagged images that are analyzed on-device; every upload is logged, but only **confirmed positive detections** (mealybug present at confidence ≥ 0.25) contribute to outbreak maps and authority-facing analytics. DA/OMAG personnel, as superusers, review consolidated reports, view farm-level analytics, and provide remedial guidance linked to individual captures. The application does not diagnose plant health and does not replace manual inspection or extension diagnosis.

---

## Chapter III — New subsection (System role & reporting)

### Detection collector and reporting workflow

Each farmer upload creates one row in the cloud `detections` table (image, timestamp, geolocation, mealybug count, and `has_mealybugs` flag). This constitutes an automatic per-image report. **Positive reports** (`has_mealybugs = true`) appear on the outbreak map and in DA analytics. **Negative reports** are retained in history tables for audit but are excluded from map and analytics visualization to avoid false outbreak signals. DA/OMAG superusers access all accredited farmers’ fields and reports through PineSight Admin (web) or mobile admin mode (`app_metadata.admin = true`). Expert advice per report is stored in `expert_responses`; optional farm-level guidance is stored in `farm_insights`.

---

## Chapter IV — Results summary (v16 vs revision cycle)

**Table X.** *Corrected held-out test metrics for YOLO26 model versions (1,952 images, 18,891 instances; imgsz = 1280; conf = 0.001; IoU = 0.6; v16-corrected labels).*

| Model | mAP@0.5 | Precision | Recall | mAP@0.5:0.95 |
|-------|--------:|----------:|-------:|-------------:|
| v16 (shipped) | 73.3% | 80.6% | 64.7% | 40.7% |
| v20s | 61.6% | 73.6% | 55.4% | 31.4% |
| v20m | 63.5% | 76.9% | 57.0% | 33.4% |
| v21 | 64.6% | 78.1% | 59.6% | 33.7% |
| v21m | 62.2% | 73.3% | 57.1% | 31.9% |
| v22 | 64.3% | 77.6% | 58.3% | 33.8% |
| Panel target | ≥85% | ≥80% | ≥80% | ≥55% |

After a full label-audit and retraining pipeline (v20 through v22), **no revision model exceeded v16** on the locked corrected test. Therefore **v16 remains the thesis and application model**. The results support an honest conclusion: the prototype is promising for assisted scouting and data collection but **does not meet minimum deployability thresholds** for standalone field diagnosis.

### Limitations

1. Recall (64.7%) remains below the panel target (≥80%), implying a substantial risk of missed infestations if used without visual verification.  
2. Strict localization (mAP@0.5:0.95 = 40.7%) indicates inconsistent bounding-box quality.  
3. Training at 1280 px and deployment at 640 px introduces a resolution mismatch.  
4. Historical label noise and under-annotation limited gains from automated relabeling.  
5. Expert field validation at the operational threshold (0.25) was not completed; prior expert F1 was reported at 0.30 only.  
6. The system is a **middleware collector**, not a replacement for DA/OMAG inspection or treatment decisions.

### Positive vs negative operational definitions

A **positive detection** is a confirmed mealybug instance at confidence ≥ 0.25 (only mealybugs are detected). A **negative detection** is zero confirmed mealybugs at save time. Negative scans are stored but excluded from outbreak maps and analytics.

---

## Chapter V — Recommendations

1. **Expert consultation** — Farmers should verify detections with DA/OMAG personnel before applying control measures; the implemented expert-reply feature supports this workflow.  
2. **Expand the detection collector** — Continue per-image auto-reporting, positive-only outbreak visualization, and DA analytics (implemented June 2026).  
3. **Field data collection** — Acquire ≥2,500 additional hard-case field images with rigorous annotation for future model improvement.  
4. **Expert re-validation** — Conduct extension-led validation at deploy confidence 0.25 on ≥50 field images.  
5. **Model research** — Future work may revisit YOLO26n/s/m comparisons and training-resolution alignment with TFLite export; the v20–v22 cycle demonstrated that relabeling alone did not close the metrics gap on the held-out test.  
6. **Do not claim deployability** until recall, mAP@0.5, and strict localization meet agreed panel thresholds.

---

## Panel response letter — addendum (June 12, 2026)

Since the panel review, we completed the H100 revision pipeline (v20–v22). None of the revision models beat v16 on the corrected held-out test. We therefore retained v16 in the application and reframed the system as a **detection collector and decision-support middleware** with the following new capabilities: positive-only outbreak maps with field heatmaps, DA/OMAG analytics dashboard, per-image automatic reporting, and expert reply on positive captures (web and mobile admin). We continue to report that the model is **not deployment-ready** at current recall and strict mAP. We recommend expert consultation and expanded field imagery as the primary path forward.

---

## Demo accounts (internal note — remove from thesis)

| Role | Email |
|------|-------|
| DA / OMAG superuser | morgajanrafael1793@gmail.com |
| Farmer (test) | morillo3580225@gmail.com |

Farmer test field on live DB: **Angelei** (owner: anji).
