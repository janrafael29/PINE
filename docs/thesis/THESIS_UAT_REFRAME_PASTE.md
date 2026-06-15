# Thesis Paste — De-emphasize App UAT (Sir Jude / Panel Alignment)

**Updated:** June 13, 2026  
**Purpose:** Reframe §3.4.8 and §4.1.6 so **primary validation = held-out benchmark + dataset quality**; OMAG field audit = **supplementary context only**, not proof the app is deployment-ready.

**Apply in Word:** `Ctrl+F` each **FIND** → paste **REPLACE** or **INSERT**. Update TOC after renames.

---

## What the panel wanted (one line)

Sir Jude: validate the **training/testing dataset and detection metrics** first; do **not** treat app-based scenario UAT as the main evidence that the detector works. The middleware reposition makes **benchmark mAP/recall (Tables 5–9)** and **honest limitations** the headline; expert field audit is optional supporting material.

---

## 1. §3.4 Testing — INSERT at opening (before §3.4.1)

**INSERT** as first paragraph under **3.4 Testing**:

> Model and system evaluation in this study follow a **tiered validation hierarchy**. **Primary evidence** for detection capability comes from (1) held-out benchmark evaluation on the canonical 1,952-image test split with declared label protocols (Section 4.1.2; Tables 5–6 and Table 9), and (2) transparent reporting of dataset preparation, label correction, and known annotation limitations (Section 3.3.2.1.2 and Scope §1.3). **Secondary evidence** includes functional, usability, performance, offline, and security testing (Sections 3.4.4–3.4.7), which verify that implemented features behave as specified but do **not** establish deployment-ready detection accuracy. **Supplementary context** is provided by a small OMAG expert field audit (Section 3.4.8; results in Section 4.1.6), which illustrates how the assistive detector behaves on a limited set of real-world photos at one operating threshold; it is **not** equivalent to mAP@0.5 and must not be interpreted as proof that the model meets field-diagnostic standards.

---

## 2. §3.4.8 — RENAME (TOC + heading)

| FIND | REPLACE WITH |
|------|----------------|
| `3.4.8 Expert Application Validation` | `3.4.8 Supplementary OMAG Field Audit (Limited Context)` |
| `3.4.8.2 User Acceptance Testing Framework` | `3.4.8.2 Audit Framework and Scope Limitations` |
| `3.4.8.3.1 App-Based Testing Protocol` | `3.4.8.3.1 Field Audit Protocol` |
| `3.4.8.3.2 UAT Form Design` | `3.4.8.3.2 Audit Recording Form` |

---

## 3. §3.4.8 — REPLACE opening block (§3.4.8 through end of §3.4.8.1)

**FIND** (from start of §3.4.8 through end of §3.4.8.1 Qualifying Parameters paragraph):

> 3.4.8 Expert Application Validation  
> 3.4.8.1 Qualifying Parameters for Expert Application Validation  
> Participants for testing were experts from the Office of the Municipal Agriculturist (OMAG)…

**REPLACE entire §3.4.8 + §3.4.8.1 with:**

---

### 3.4.8 Supplementary OMAG Field Audit (Limited Context)

Following panel guidance, this subsection documents a **small, supplementary** field audit—not the **primary** validation of the detection model. Primary validation remains the held-out benchmark in Section 4.1.2 (Tables 5–6) and the complete development lineage (Table 9), together with acknowledged dataset and annotation constraints (Section 1.3). The audit answers a narrow question: *on a fixed set of field photos, how did the deployed assistive pipeline behave at one confidence setting when reviewed by OMAG domain experts?* It does **not** answer whether the system is deployment-ready, nor does it substitute for rigorous dataset review or expanded expert panels.

#### 3.4.8.1 Qualifying Parameters

Participants were three OMAG personnel with direct experience in pineapple mealybug management in Polomolok, South Cotabato. Each validator independently reviewed seven assigned field images (21 images total across three validators). This panel size satisfies minimum content-validity thresholds for researcher-developed instruments (Lynn, 1986; Polit & Beck, 2006) but is **intentionally reported as supplementary** because sample size, scenario diversity, and threshold alignment (30% audit threshold vs. 25% confirmed deploy threshold in the current release) limit generalizability.

---

## 4. §3.4.8.2 — REPLACE (shorten + de-emphasize UAT)

**FIND** (§3.4.8.2 User Acceptance Testing Framework — full section):

**REPLACE WITH:**

#### 3.4.8.2 Audit Framework and Scope Limitations

The audit instrument was adapted from scenario-based software verification practice (Gothelf & Seiden, 2016; International Software Testing Qualifications Board, 2018) and object-detection reporting conventions (Everingham et al., 2010; Padilla et al., 2020). It records instance-level true positives, false positives, and false negatives per image so that precision, recall, and F1 can be summarized for **transparency**.

**Scope limitations (explicit):**

1. **Not primary model validation** — Benchmark mAP@0.5, precision, and recall on the 1,952-image held-out test (Section 4.1.2) are the authoritative detection metrics for this study.  
2. **Not app acceptance testing** — Functional correctness of registration, sync, maps, and middleware workflows is covered in Sections 3.4.4–3.4.7 and usability testing (Section 3.4.3); this audit evaluates **only** bounding-box behavior on assigned photos.  
3. **Small sample** — Twenty-one images cannot represent the full variability of lighting, occlusion, life stage, and annotation quality in the training corpus.  
4. **Threshold mismatch** — The audit used a **30%** confidence setting; the shipped application uses a **25%** confirmed threshold with a 0.12–0.24 manual-check band (Section 3.3.2.1.5). Metrics are **not** directly comparable to Table 5 without re-audit at 0.25.  
5. **Collector framing** — PINYA-PIC is positioned as a detection **collector and middleware** (Section 1.3); even favorable audit scores would not justify a deployment-ready diagnostic claim.

---

## 5. §3.4.8.3.1 — REPLACE opening (field audit protocol)

**FIND** (first paragraph of §3.4.8.3.1 App-Based Testing Protocol):

> The field validation protocol was structured as a synchronous, independent audit…

**REPLACE first paragraph WITH:**

> The field audit protocol was structured as an independent, image-level review. Validators opened the application, captured or reviewed assigned pineapple scenes, manually counted visible mealybugs, and compared expert counts to application indicators (true positive, false positive, false negative). Negative-control images (TC-05, TC-06) recorded whether the app correctly registered zero confirmed mealybugs. This procedure provides **illustrative** field context only; it was **not** used to certify the training dataset or to assert that the model meets extension-grade diagnostic standards.

**KEEP** the bullet list (Scenario Scanning through Mathematical Consistency Audit) — it remains useful methodology detail.

---

## 6. §3.4.8.3.2 — ADD one sentence after form description

**INSERT** after the paragraph ending *"…final qualitative status determination (Pass/Fail)."*:

> The form is retained in Appendix F for reproducibility; panel review emphasized that **dataset quality and held-out benchmark metrics**, not this form alone, should govern conclusions about model readiness.

---

## 7. §3.4.8.3.3 — ADD closing limitation paragraph

**INSERT** at end of §3.4.8.3.3 (after TN discussion):

> Aggregated audit metrics (Section 4.1.6, Table 10) are reported for completeness and to document OMAG engagement in the middleware workflow. They **must not** be equated with mAP@0.5, cited as the primary success criterion for the capstone, or used to offset recall below panel deployability targets (Section 4.1.2, Table 9).

---

## 8. §4.1.6 — RENAME + REPLACE opening

| FIND | REPLACE WITH |
|------|----------------|
| `4.1.6 Manual Expert Validation (Field-Based)` | `4.1.6 Supplementary OMAG Field Audit Results (Not Primary Validation)` |

**FIND** (first two paragraphs of §4.1.6):

> This evaluation was conducted using expert-reviewed field samples (VAL1–VAL3)…  
> This 21-image review (seven images per validator) complements the structured User Acceptance Testing (UAT) protocol in Section 3.4.8…

**REPLACE WITH:**

#### 4.1.6 Supplementary OMAG Field Audit Results (Not Primary Validation)

This section reports results from the **supplementary** OMAG field audit described in Section 3.4.8. Three validators each reviewed seven field images (21 total). Four images per validator contained mealybugs (positive scenarios); three were negative controls (healthy plant or non-target insects).

**Primary detection performance for this study is defined by held-out benchmark evaluation** of mealybug_v16_selffix on 1,952 test images: **73.3% mAP@0.5**, **80.6% precision**, **64.7% recall**, and **40.7% mAP@0.5:0.95** under v16-consensus corrected ground truth (Table 5). Those figures—and the failed post-panel revision cycle (Table 9)—are the basis for the conclusion that the model is an **assistive pilot**, not deployment-ready. The audit below adds **field-context illustration only**.

Validators applied a **30%** confidence setting during the audit. The current application uses **25%** confirmed detections (manual-check hints at 0.12–0.24). Audit metrics are **not** mAP@0.5 and have **not** been re-computed at the 25% deploy threshold.

---

## 9. Table 10 — REPLACE caption + ADD footnote

**FIND** (Table 10 title):

> Table 10 Expert Validation Results (VAL1–VAL3)

**REPLACE WITH:**

> **Table 10** *Supplementary OMAG field audit summary (VAL1–VAL3; audit threshold 30%; not mAP)*

**ADD** immediately under the table (footnote or note paragraph):

> *Note.* Primary model validation = Table 5 (held-out corrected test). This table summarizes a 21-image OMAG audit at 30% confidence (12 positive images pooled: TP = 101, FP = 1, FN = 21; 122 ground-truth instances; 9 negative images). Grand-average F1 (91.75%) **does not** indicate deployment readiness and **must not** be compared to mAP@0.5 without protocol alignment. Equivalent audit at the operational 25% threshold is recommended future work (Section 5.1.3).

---

## 10. §4.1.6 — REPLACE closing paragraph (after aggregation formulas)

**FIND** (paragraph ending with *"9 negative images contained no mealybugs."*):

**REPLACE WITH:**

> The grand-average F1 of 91.75%, precision of 99.58%, and recall of 85.64% describe **expert-reviewed instance matching on 21 selected field photos**, not benchmark detection on the full test split. High precision with materially lower recall on the held-out test (64.7%, Table 5) illustrates that **small convenience samples can overstate operational performance**. For capstone conclusions, the authors prioritize Table 5 and Table 9, acknowledge annotation and dataset limitations raised during panel review, and position this audit as **supporting context** for the middleware collector—not as proof of field-ready diagnosis.

---

## 11. §4.4 Summary — de-emphasize expert F1 in opening

**FIND** (sentence in §4.4):

> Manual expert validation on 21 field images reported 91.75% F1 at the 30% expert-validation threshold (Table 10).

**REPLACE WITH:**

> Primary detection evaluation on the held-out corrected test (Table 5) reported 73.3% mAP@0.5 and 64.7% recall—below panel deployability targets. A supplementary 21-image OMAG field audit (Table 10; 30% audit threshold) is reported for transparency only and is not treated as primary validation.

---

## 12. Abstract — qualify expert F1 sentence

**FIND:**

> Expert validation on field images reached 91.75% F1, 99.58% precision, and 85.64% recall at a 30% confidence threshold.

**REPLACE WITH:**

> Held-out benchmark evaluation (primary) achieved 73.3% mAP@0.5 and 64.7% recall on corrected test labels. A supplementary 21-image OMAG field audit (30% audit threshold; not mAP) reported 91.75% F1 for illustrative context only.

---

## 13. §1.3 Scope — ADD one bullet under limitations

**INSERT** in limitations list (after Validation metrics caveat or Confirmed detection threshold):

> **Supplementary vs. primary validation:** Held-out benchmark metrics (Section 4.1.2) are the primary basis for detection claims. The OMAG field audit (Sections 3.4.8 and 4.1.6) is a small supplementary sample and must not be interpreted as deployment validation or as a substitute for dataset review.

---

## 14. §5.1.3 — strengthen recommendation (already partially there)

**FIND** (if present):

> Expanded Expert Validation Panel

**ENSURE** recommendation reads:

> **Expanded expert and dataset validation** — Future work should prioritize peer-reviewed expansion and audit of training and test annotations (the bottleneck identified during panel review), held-out benchmarking at the operational 25% threshold, and a larger geographically distributed OMAG panel (≥50 field images). Supplementary 21-image audit results (Table 10) should not be extrapolated to deployment claims.

---

## 15. Appendix F title (optional)

| FIND | REPLACE WITH |
|------|----------------|
| `EXPERT VALIDATION INSTRUMENT (UAT FORM)` | `SUPPLEMENTARY OMAG FIELD AUDIT FORM (Appendix F; not primary validation)` |
| `USER ACCEPTANCE TESTING (UAT) - MOBILE APPLICATION VALIDATION FORM` | `OMAG FIELD AUDIT — ASSISTIVE DETECTION RECORDING FORM` |

---

## Checklist after paste

- [ ] §3.4 opens with **tiered validation hierarchy**
- [ ] §3.4.8 renamed; UAT language reduced; **5 scope limitations** present
- [ ] §4.1.6 renamed; opens with **Table 5 as primary**; closes with **not deployment proof**
- [ ] Table 10 caption + footnote updated
- [ ] Abstract and §4.4 do **not** lead with 91.75% F1 as headline success
- [ ] TOC updated for renamed sections
- [ ] Defense script: say *"primary = Table 5; Table 10 is supplementary audit only"*

---

## One sentence for oral defense

> "Our **primary** validation is the held-out 1,952-image benchmark in Table 5; the OMAG 21-image audit in Table 10 is **supplementary context** at a different threshold and sample size—we do not use it to claim the model is deployment-ready."
