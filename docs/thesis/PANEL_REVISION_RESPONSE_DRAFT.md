# Panel Revision Response — Draft (Morga et al. / PINYA-PIC)

*Phase 0.5 — adapt for formal resubmission letter.*

**Date:** 2026-05-29 (updated 2026-06-10)  
**Re:** Major revision — model performance, deployability, and advisory design

---

Dear Members of the Panel,

Thank you for the detailed and constructive assessment of PINYA-PIC. We accept the core conclusion: the system is **technically promising as a preliminary prototype** but **not yet acceptable as a deployable field diagnostic** at the current recall and strict localization performance. We have revised our claims accordingly and begun a structured **V18 improvement cycle** documented in `docs/training/V18_PANEL_REVISION_PLAN.md`.

---

## 1. What we agree with

- **Recall (64.7%)** is the primary weakness for a pest-scouting tool; missed infestations are more harmful than cautious false alarms.  
- **mAP@0.5:0.95 (40.7%)** indicates bounding boxes are not consistently tight enough for strong localization claims.  
- The application must **not** imply that a negative scan means a healthy plant.  
- Minimum deployability requires stronger evidence: improved recall, better localization, field validation, and responsible UX.

---

## 2. Actions already completed

| Panel guidance | Action |
|----------------|--------|
| **#7 — Confusion cases** | Exported TP/FP/FN/poor-localization examples; thesis section in `docs/thesis/CONFUSION_CASES_V16.md` |
| **#8 — Advisory safeguards** | App messaging updated to decision-support language (`detection_advisory_messages.dart`) |
| **#1 (partial) — Threshold** | Deploy confidence lowered from 0.30 → **0.25**; two-tier UI (confirmed ≥0.25 + manual-check overlay 0.12–0.24) |

### Progress since 10 June 2026

| Item | Status |
|------|--------|
| Phase 0 on Vast H100 (confusion export, CVAT queues) | ✅ |
| Full 1,952-image confusion cases for thesis | ✅ `docs/thesis/CONFUSION_CASES_V16.md` |
| Audited + auto-fixed training labels (`mealybug_v20`) | ✅ |
| **v20s** train from scratch (YOLO26s @ 1280) | 🔄 On H100 |
| Thesis system architecture document | ✅ `docs/thesis/SYSTEM_ARCHITECTURE.md` |
| v16 baseline JSON repro @ 1280 | ⚠️ Pending label-path fix on Vast |

---

## 3. Planned revisions (V18 cycle)

We are executing a **data-first** plan in six phases:

1. **Recall & threshold** — v16 sweep @ 1280; two-tier UI (confirmed + “check manually”)  
2. **Hard-case data** — complete 510-image field batch; collect ≥1,500 new base photos  
3. **Annotation audit** — CVAT review of 800+ failure-case images; pseudo-label spot-check  
4. **Field-realistic augmentation** — brightness, blur, rotation; no harmful copy-paste until labels are clean  
5. **Training size** — train @ 1280; compare TFLite export @ 640 vs 960  
6. **Model comparison** — YOLO26n / s / m on the same v18 dataset  

**Target timeline:** focused track — completion **~August 2026**; minimum revision track — **~mid-July 2026**.

---

## 4. Performance targets

We will re-evaluate against the panel’s suggested targets on the **same corrected held-out test protocol** (1,952 images; v16-consensus labels):

| Metric | Current (v16) | Target |
|--------|---------------|--------|
| mAP@0.5 | 73.3% | ≥ 85% |
| Precision | 80.6% | ≥ 80% |
| Recall | 64.7% | ≥ 80% |
| mAP@0.5:0.95 | 40.7% | ≥ 55–60% |

We will report results transparently even if all targets are not met, and we will **not** claim field-ready deployment without meeting agreed minimums and expanded expert validation (≥50 field images at deploy threshold).

---

## 5. Positioning statement (for thesis and demo)

> PINYA-PIC is a **mobile decision-support prototype** for mealybug scouting. It assists farmers with visual hints and record-keeping; it is **not** a substitute for manual inspection or extension diagnosis.

---

Respectfully submitted,

*[Proponents’ names]*  
*[Program / date]*

---

*Supporting artifacts: `docs/training/V18_PANEL_REVISION_PLAN.md`, `docs/training/V18_PROGRESS_LOG.md`, `docs/thesis/assets/v18_baseline/`.*
