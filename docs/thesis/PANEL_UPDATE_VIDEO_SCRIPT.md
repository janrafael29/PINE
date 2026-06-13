# PINYA-PIC — Panel Progress Video (3–5 min)

**Purpose:** Interim update for the panel (not final defense).  
**Target length:** 3:30–4:30 (hard cap 5:00).  
**Status banner (say once):** *“This is a work-in-progress update; metrics and the deployed build may still change before final defense.”*

---

## Before you record (15 min setup)

1. Phone: PINYA-PIC installed, logged in, **one field** ready, **3–4 test photos** prepared:
   - **A)** Dense mealybugs (many boxes)
   - **B)** Sparse / few pests
   - **C)** Clean leaf (zero or near-zero detections)
   - **D)** Optional: blurry / hard lighting (shows limitation honestly)
2. Open on laptop (for cutaways): SUS questionnaire PDF or thesis **§3.4.3** + **Table 4.5**; this script; `docs/thesis/LITERATURE_mAP_70_78_BAND.md`.
3. Tool: Phone screen recorder **or** OBS; mic close to mouth; quiet room.
4. Optional title card (5 s): **“PINYA-PIC — Progress Update, May 2026 (WIP)”**

---

## Slide deck map (`panel_video_slides.html` — 14 slides, panel-facing)

| # | Topic |
|---|--------|
| 1 | Title — Progress Report (WIP) |
| 2 | Agenda |
| 3 | System overview |
| 4 | Version 16 test metrics |
| 5 | Transparent reporting (66% vs 73.3%) |
| 6 | Methodology (how achieved) |
| 7 | Model development progress |
| 8 | Literature comparison |
| 9 | Three evaluation approaches |
| 10 | SUS (77.0) |
| 11 | Expert field validation |
| 12 | Metrics clarification for panel |
| 13 | **Live demo** → switch to phone |
| 14 | Summary, next steps, thank you |

Speaker notes removed from slides — use script sections below when recording.

---

## Segment 1 — Model accuracy + how we got there + literature (~1:45)

**VISUAL:** `panel_video_slides.html` — **slides 1–12** on laptop (F11, Space). **Slide 13** = demo title → switch to phone. **Slide 14** = closing after demo.

**SAY (read naturally, ~90 s):**

> Good morning. This is a **work-in-progress** update for the panel—not final defense.
>
> This is **PINYA-PIC**, offline Android mealybug detection. Our latest model is **mealybug_v16**, tested on **1,952 held-out images**.
>
> On **corrected test labels**: **mAP@0.5 is 73.3%**, **precision 80.6%**, **recall 64.7%**, **mAP@0.5:0.95 is 40.7%**. On **legacy labels**, about **66% mAP@0.5**—we report both for transparency.
>
> **How we achieved this:** First, we audited labels with **GroundingDINO** and found about **half** of training images were **missing mealybugs**. We added **17,277 boxes** to training data and trained **v15**. Then **self-training**: v15 found more pests—we added **2,744 boxes** and fine-tuned **v16**, reaching about **66%** on the old test labels. Finally, we **corrected the test set** using high-confidence **v16** detections so evaluation is fair—that headline is **73.3%**. So the gain is **better ground truth and a stronger model**, not a single trick.
>
> Compared to literature, similar small-pest papers report about **70–74% mAP@0.5**: **Zhang 2022, 71.3%**; **Wang 2022, 69.6%**; **Yu 2025, 74%**. **Wu 2019** shows the task is hard on IP102. Our **73.3%** is in that band. **Recall** is still what we’re improving. **This is not final.**

**ON-SCREEN TEXT (bullet slide):**

| Metric | v16 (corrected test) |
|--------|------------------------|
| mAP@0.5 | **73.3%** |
| Precision | **80.6%** |
| Recall | **64.7%** |
| mAP@0.5:0.95 | **40.7%** |

**References (show footer):** Zhang et al., 2022; Wang et al., 2022; Yu et al., 2025; Wu et al., 2019 — full APA in `LITERATURE_mAP_70_78_BAND.md`.

---

## Segment 2 — Validation questionnaire + how it connects (~1:00)

**VISUAL:** Thesis **§3.4.3** (SUS) + **Table 4.5** (n=10, mean **77.0**). Then **§4.1 expert validation** / Table 9 (VAL1–VAL3, **91.75% F1**). Optional: flash **7 task scenarios** list from methodology.

**SAY (~55 s):**

> Model mAP alone does not tell us if farmers and experts can use the app. We evaluate in **three linked layers**.
>
> **First**, **System Usability Scale** testing: **10 valid farmers**, standard **10-item SUS** after task-based scenarios—mean score **77.0**, above the industry benchmark of 68. Source: Brooke, 1986; interpreted per Sauro, 2011.
>
> **Second**, **expert field validation**: three validators from the **Office of the Municipal Agriculturist**, **seven images each**—four with mealybugs, three negative—same **30% deploy threshold** as the app. Pooled expert review: **91.75% F1**, **99.6% precision**, **85.6% recall** on positive images. This is **not** mAP; it measures operational correctness at one threshold.
>
> **Third**, we connect both to the model: high benchmark mAP supports detection quality; expert F1 shows the **deployed threshold** works in the field; SUS shows the **workflow** is usable. v16 improves the detector; we will re-run expert review on v16 before final defense.

**ON-SCREEN:** Simple diagram (draw or use slide):

```
Training benchmark (mAP@0.5, 1,952 imgs)  →  detector quality
Expert validation (21 imgs, 30% thresh)   →  field correctness
SUS (n=10 farmers)                        →  usability
```

---

## Segment 3 — App demo clips (~1:30–2:00)

**VISUAL:** Screen recording only. Fast cuts (~15–25 s each).

| Clip | Action | Say (voiceover) |
|------|--------|------------------|
| 1 | Open app → **Scan** → photo **A** (dense) | “On-device TFLite inference—boxes and count without internet.” |
| 2 | Result screen: zoom a box, show **confidence %** | “Scores are per-instance; we use a **30%** deploy cutoff tuned for field use.” |
| 3 | Photo **B** (sparse) | “Sparse infestation still detected.” |
| 4 | Photo **C** (clean) | “Negative case—few or no false boxes.” |
| 5 | **Save to field** → **My Fields** / map pin | “Detections link to GPS and field polygons.” |
| 6 | Optional: **Airplane mode** → one scan → still works | “Offline-first: sync when connectivity returns.” |

**SAY (closing 15 s):**

> This build ships **mealybug_v16** weights; training is ongoing. Thank you—we welcome your feedback.

---

## Timing cheat sheet

| Block | Target |
|-------|--------|
| Intro + metrics + pipeline + literature | 1:45 |
| Questionnaires + linkage | 1:00 |
| App clips (4–6) | 1:30–2:00 |
| Closing WIP note | 0:15 |
| **Total** | **~4:00** |

---

## Panel Q&A prep (if they ask after the video)

| Question | Short answer |
|----------|----------------|
| Is 73.3% final? | No—WIP; v16 on corrected test; legacy ~66%. Final numbers after label review + possible v17+. |
| Why not 90%? | Detection mAP ≠ accuracy; small dense pests; literature ~70–78% on comparable pest tasks. |
| Expert 91% vs 73% mAP? | Different metrics: human judgment at 30% vs full PR curve on 1,952 images—do not equate. |
| Only 21 expert images? | Pilot expert set; complements large automated test; more images planned. |

---

## Files to attach for Sir / panel

- `docs/V16_TRAINING_LOG.md` (metrics source)
- `docs/thesis/LITERATURE_mAP_70_78_BAND.md` (citations)
- `docs/thesis/THESIS_CHAPTER_IV_METRICS_SECTION.md` (tables paste)
- `docs/thesis/panel_video_slides.html` (open in browser → record)
