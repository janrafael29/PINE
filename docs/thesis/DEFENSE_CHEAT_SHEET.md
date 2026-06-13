# THESIS DEFENSE CHEAT SHEET — Chapter IV Focus
## PINE: Pineapple Mealybug Detection App | mealybug_v13afix | YOLO26n → TFLite

---

## SECTION 1: CRITICAL NUMBERS (Memorize These)

### Model Benchmark (Automated, Large-Scale)

| Metric | Value | Split | Images | Condition |
|--------|------:|-------|-------:|-----------|
| **mAP@0.5** | **61.0%** | Native test | 1,952 | conf=0.12, IoU=0.45 |
| mAP@0.5:0.95 | 29.2% | Native test | 1,952 | conf=0.12, IoU=0.45 |
| Precision | 72.8% | Native test | 1,952 | conf=0.12 |
| Recall | 58.9% | Native test | 1,952 | conf=0.12 |
| F1 (benchmark) | 65.1% | Native test | 1,952 | conf=0.12 |
| **mAP@0.5 (fixed set)** | **56.7%** | v10 test | 462 | conf=0.12, IoU=0.45 |

### Model Evolution (All on Same 462-Image Test Set)

| Version | mAP@0.5 | Δ from prev | Key Change |
|---------|--------:|------------:|------------|
| v2 | 21.1% | — | Legacy ~2.3k images |
| v10 | 42.1% | +21.0 pp | Scaled to ~16k augmented |
| v11 | 43.0% | +0.9 pp | Label cleaning |
| v12 | 43.8% | +0.8 pp | Trained at 1024px |
| **v13afix** | **56.7%** | **+12.9 pp** | +Va field data, +fix500, cleaned labels |

**Total improvement: +35.6 pp (v2 → v13afix)**

### Expert Validation (Manual, Field Photos)

| Metric | Value | Source |
|--------|------:|--------|
| Grand F1 | **91.75%** | Mean of 3 validator averages |
| Grand Precision | **99.58%** | Only 1 FP across all images |
| Grand Recall | **85.64%** | Misses small/occluded |
| Grand Accuracy (Jaccard) | **85.40%** | TP/(TP+FP+FN) |
| Avg Confidence | **57.33%** | Mean detection box confidence |
| Total images | **21** | 7 per validator × 3 |
| Positive images | **12** | Contained mealybugs |
| Negative images | **9** | No mealybugs present |
| Pooled TP | 101 | Across 12 positive images |
| Pooled FP | 1 | Near-zero false alarm |
| Pooled FN | 21 | Missed (small/occluded) |
| Ground-truth instances | 122 | Manual expert count |

### Per-Validator Breakdown

| Validator | Precision | Recall | F1 | Accuracy | Avg Conf |
|-----------|----------:|-------:|---:|---------:|---------:|
| VAL1 | 98.75% | 78.44% | 86.92% | 77.71% | 54.50% |
| VAL2 | 100.00% | 92.56% | 95.91% | 92.56% | 57.75% |
| VAL3 | 100.00% | 85.91% | 92.41% | 85.91% | 59.75% |

### App & Deployment

| Item | Value |
|------|-------|
| Model file | mealybug_v13afix (TFLite INT8) |
| Model size | 5.42 MB |
| Input resolution | 640 × 640 px |
| Deploy threshold | **30%** (single threshold) |
| Benchmark conf | 12% (Ultralytics default) |
| NMS IoU | 0.45 |
| Inference (mid-range) | ~150 ms |
| Inference (budget) | ~280 ms |
| Field detections | 826 operations |
| Mealybugs counted | 4,670 |
| Fields tested | 12 |
| Deployment duration | 3 days |
| SUS score | 77.0 (Good) |

### Training Configuration

| Parameter | Value |
|-----------|-------|
| Architecture | YOLO26n (Ultralytics 2025) |
| Pretrained weights | yolo26n.pt (COCO) |
| Training images | 13,664 |
| Validation images | 3,904 |
| Test images | 1,952 |
| Total dataset | 19,520 (after augmentation) |
| Epochs run | 75 |
| Patience (early stop) | 15 |
| Image size (train) | 640 |
| Batch size | 16 |
| Optimizer | AdamW (Ultralytics default) |
| Seed | 42 |
| Split ratio | 70/20/10 |

---

## SECTION 2: KEY DISTINCTIONS (Don't Confuse These)

### mAP@0.5 vs Expert F1 — COMPLETELY DIFFERENT METRICS

| | mAP@0.5 (61.0%) | Expert F1 (91.75%) |
|--|------------------|-------------------|
| **What it measures** | Area under Precision-Recall curve at IoU≥0.5 across ALL confidence levels | Binary correct/incorrect per detection at the 30% threshold |
| **Evaluator** | Automated (Ultralytics val) | Human expert (visual judgment) |
| **Strictness** | Box must overlap ≥50% IoU | "Is box on a mealybug?" (lenient) |
| **Sample size** | 1,952 images | 12 positive images |
| **Confidence range** | All scores ≥0.12 | Only scores ≥0.30 |
| **Can you compare them?** | **NO. NEVER.** | **NO. NEVER.** |

### conf=0.12 vs conf=0.30

| | 0.12 (Benchmark) | 0.30 (Deploy) |
|--|-------------------|---------------|
| Purpose | Standard mAP evaluation | User-facing detection filter |
| Precision | 72.8% | ~99% (expert validation) |
| Recall | 58.9% | ~60% (lower, more filtered) |
| Who sees it | Researcher only | Farmer in the app |
| Why this value | Ultralytics default for PR curve | Tuned for low FP in field |

### Accuracy (Jaccard) vs Classical Accuracy

| | Our "Accuracy" | Classical Accuracy |
|--|----------------|-------------------|
| Formula | TP/(TP+FP+FN) | (TP+TN)/(TP+TN+FP+FN) |
| Includes TN? | No | Yes |
| Why no TN? | TN is infinite in object detection | Only works for classification |
| Also known as | Jaccard Index, Threat Score, CSI | Standard classification accuracy |
| Reference | Padilla et al. (2020), Everingham et al. (2010) | — |

---

## SECTION 3: FORMULAS

### Per-Image Metrics (Expert Validation)

```
Precision = TP / (TP + FP)
Recall    = TP / (TP + FN)
F1        = 2 × (Precision × Recall) / (Precision + Recall)
Accuracy  = TP / (TP + FP + FN)     [Jaccard Index]
```

### Validator Average (Macro-Average)

```
Validator_Metric = (1/n) × Σ(Image_Metric_i)   for i = 1..n images
```

### Grand Average (Mean of Validator Averages)

```
Grand_Metric = (VAL1_avg + VAL2_avg + VAL3_avg) / 3
```

### Example Calculation (VAL1, Image 1)

```
Population = 10 mealybugs (ground truth)
Detections = 6 boxes (all correct)
TP = 6, FP = 0, FN = 10 - 6 = 4

Precision = 6/(6+0)   = 100.0%
Recall    = 6/(6+4)   = 60.0%
F1        = 2×(1.0×0.6)/(1.0+0.6) = 75.0%
Accuracy  = 6/(6+0+4) = 60.0%
```

### mAP@0.5 (Conceptual)

```
1. Sort all detections by confidence (descending)
2. For each detection: if IoU with ground-truth box ≥ 0.5 → TP, else → FP
3. Compute cumulative Precision and Recall at each rank
4. AP = Area under the interpolated P-R curve
5. mAP = mean AP across all classes (= AP for single-class detector)
```

---

## SECTION 4: ANTICIPATED HARD QUESTIONS & ANSWERS

### Q: "61% mAP is low. Other studies get 90%+."

**A:** "Those studies detect larger objects (apples, leaves, birds) on high-resolution images with large models. Mealybugs are 10–30px, clustered, semi-transparent, and we use a 5.4MB Nano model for mobile. Published small-pest benchmarks (Song et al., 2025; Li et al., 2023) report 45–65% mAP — our 61% is within or above that range. The practical impact is confirmed by expert validation at 91.75% F1."

### Q: "Data leakage — v10 test images may be in v13afix training."

**A:** "Valid concern, acknowledged in our limitations. The v10 test (462 imgs) is 3.4% of v13afix training (13,664). Even worst-case, this is too small to inflate mAP by 12.9pp. Moreover, the guaranteed-clean native test (1,952 imgs) shows 61.0% — HIGHER than the potentially-leaked set (56.7%). If leakage helped, the leaked set would score higher, not lower."

### Q: "Only 3 validators, 21 images — statistically weak."

**A:** "Acknowledged. 95% CI for grand F1: 91.75% ± 5.15% → [86.6%, 96.9%]. We don't rely solely on this. It complements the 1,952-image automated benchmark. The validators are domain experts (OMAG staff), not random users. The 7-scenario design covers key environmental variations."

### Q: "Why no architecture comparison (MobileNet, EfficientDet)?"

**A:** "We compared YOLO26n vs YOLO11n (65.1% vs 52.6%, same data), justifying YOLO26n within the ecosystem. Full multi-architecture ablation was infeasible given compute constraints and the need for TFLite-compatible export pipeline. Literature consistently shows YOLO outperforms SSD/EfficientDet on small agricultural pests. Acknowledged as future work."

### Q: "How do you know it converged? Did you tune hyperparameters?"

**A:** "Early stopping triggered at epoch 75 (patience=15, best weights saved at ~epoch 60). Validation loss plateaued. Hyperparameters used Ultralytics defaults, which are community-validated on COCO. Data quality (not HP tuning) drove our improvements across versions — evidenced by v10→v13afix gains coming from dataset changes, not architecture/HP changes."

### Q: "Your precision is near-perfect but recall is only 60%. Isn't that a problem?"

**A:** "It's a deliberate design choice. In agricultural advisory tools, a false positive (telling farmers pests exist when they don't) causes unnecessary pesticide application — economic and environmental harm. A missed detection is less costly because farmers recheck periodically and the app is a screening aid, not a replacement for manual inspection. We explicitly traded recall for precision via the 30% threshold."

### Q: "Why conf=0.12 for benchmarks but 0.30 for deployment?"

**A:** "They serve different purposes. conf=0.12 is the Ultralytics default for computing the full Precision-Recall curve — it lets all but the lowest-confidence detections participate in mAP calculation, enabling fair comparison with literature. conf=0.30 is the operational filter that controls what the farmer sees — tuned for near-zero false positives in practice."

### Q: "IoU=0.5 is too strict for tiny objects. A 1px shift ruins it."

**A:** "Correct — this is why our mAP@0.5:0.95 is only 29.2% (the higher IoU thresholds are brutal for small objects). We report both metrics. mAP@0.5 is the community standard for comparability. For practical purposes, expert validation (which uses lenient 'is the box on the bug?' criteria) confirms 91.75% F1. Future work could report mAP@0.25."

### Q: "What if the farmer takes a blurry/dark photo?"

**A:** "The model will produce lower confidence scores or miss detections. The 30% threshold naturally filters uncertain predictions. The app includes guidance for capture quality, and the offline-first design allows immediate retake. In field testing, experts achieved 57% average confidence — indicating the model is appropriately cautious under real conditions."

### Q: "Modified waterfall is wrong for ML. Why not agile?"

**A:** "The waterfall structure governs the thesis deliverables (proposal → design → implementation → testing → defense). The ML pipeline within implementation was iterative — 12 model versions (v2→v13afix) with data-driven feedback loops. 'Modified' captures this hybrid: sequential thesis milestones, iterative technical development."

### Q: "40% miss rate could harm farmers — what's your liability?"

**A:** "The app is positioned as a detection AID, not a diagnostic replacement. It's analogous to a medical screening tool — high specificity ensures flagged areas need attention, while periodic manual inspection catches what the tool misses. The app explicitly does not recommend treatment; it flags presence for the farmer's judgment. 60% detection in a single photo still provides actionable intelligence that farmers lack without the tool."

---

## SECTION 5: DATASET LINEAGE (Know Your Data Story)

```
v2 (Legacy)
 └─ ~2,328 images, mixed quality, inconsistent labels
     │
v10 (Major upgrade)
 └─ 16,175 train images from Roboflow
 └─ Systematic augmentation (flip, rotate, brightness, mosaic)
 └─ 923 val / 462 test (FIXED benchmark set)
     │
v11 (Label cleaning)
 └─ Same images as v10, cleaned annotations
 └─ Removed duplicate/overlapping/incorrect boxes
     │
v12 (Resolution boost)
 └─ Trained at 1024px (vs 640px for v10/v11)
 └─ Minor gains (+0.8pp mAP)
     │
v13afix (Final deployed)
 └─ Added "Va" field dataset (Polomolok farms)
 └─ Added "fix500" (500 real deployment images, augmented)
 └─ Additional label cleaning pass
 └─ 13,664 train / 3,904 val / 1,952 test
 └─ Total pool: 19,520 images (with augmentation)
```

---

## SECTION 6: DEFENSE TACTICS

### Opening Line (if asked to summarize Ch. 4)

> "Chapter 4 evaluates the system through three complementary lenses: automated benchmark testing on 1,952 images yielding 61% mAP@0.5, manual expert validation on 21 field images yielding 91.75% F1, and usability testing with 10 participants yielding a SUS score of 77. Together, these confirm the system meets its objective as a practical mobile detection aid for pineapple mealybugs."

### If They Challenge Your Numbers

1. **Pause.** Don't rush.
2. **Clarify which metric** they're asking about (mAP vs F1 vs confidence).
3. **Acknowledge** any valid limitation honestly.
4. **Triangulate** — point to 2–3 other evidence sources.
5. **Contextualize** — compare to published baselines, state your constraints.

### If You Don't Know

> "That's an excellent question. Based on our current evaluation, I don't have that specific data point, but I can reason about it from [related evidence]..."

Never fabricate. Never guess numbers. Always redirect to what you DO know.

### Body Language Tips

- Maintain eye contact with the questioner
- Nod while they ask (shows you're listening)
- Take a breath before answering (shows confidence)
- If you need time: "Let me think about that for a moment..."
- Point to specific tables/figures in your document

---

## SECTION 7: TABLE QUICK-REFERENCE (Where Things Are)

| Table # | Content | Section |
|---------|---------|---------|
| Table 4 | Early YOLO11n vs YOLO26n training comparison | §4.1.1 |
| Table 5 | v13afix native test metrics (61.0% mAP) | §4.1.1 |
| Table 6 | v13afix on fixed v10 test (56.7% mAP) | §4.1.2 |
| Table 7 | Inference speed comparison | §4.1.3 |
| Table 8 | Performance comparison v2→v13afix | §4.1.4 |
| Table 9 | Expert validation grand average | §4.1.5 |
| Table 14 | 826 detection operations deployment stats | §4.3 |

---

## SECTION 8: REFERENCES TO CITE VERBALLY

- **Song et al., 2025** — Small pest detection benchmarks (45–65% mAP for nano models)
- **Padilla et al., 2020** — Object detection metrics survey (why no TN)
- **Everingham et al., 2010** — PASCAL VOC benchmark (IoU=0.5 standard)
- **Ritter et al., 2015** — Human response time thresholds (200–300ms acceptable)
- **Powers, 2011** — Precision, Recall, F1 definitions
- **ISTQB, 2018** — Independent testing principles (UAT design)
- **Ultralytics, 2025** — YOLO26 architecture and default parameters

---

## SECTION 9: WORST-CASE SCENARIO QUESTIONS

If a panelist goes truly adversarial:

| Attack | Your Shield |
|--------|-------------|
| "This isn't novel" | "The novelty is the integrated system — offline mobile detection + geospatial mapping + severity scoring for Philippine pineapple farms. No existing tool serves this specific agricultural context." |
| "Why not just use a pretrained model?" | "Pretrained COCO models don't include mealybug classes. Fine-tuning on domain-specific data is mandatory. Our 12-iteration improvement demonstrates this." |
| "Your sample sizes are too small for publication" | "This is an undergraduate thesis, not a journal submission. The evaluation is appropriate for the degree level. We acknowledge sample size as a limitation and recommend larger studies." |
| "61% means your model is unreliable" | "Unreliable would mean inconsistent. Our precision is 99.58% — what it detects is almost always correct. 61% mAP reflects *completeness* (recall-sensitive), not *reliability* (precision-sensitive)." |
| "What's new here vs existing pest detection apps?" | "Offline-first operation (no internet required), local-only data storage, geofenced deployment zones, severity classification, and specific optimization for pineapple mealybugs in Philippine agricultural context." |

---

*Print this double-sided. Highlight your weakest areas. Practice saying the numbers out loud.*
