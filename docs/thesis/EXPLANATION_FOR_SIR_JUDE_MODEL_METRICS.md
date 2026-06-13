# Memorandum: Interpreting PINYA-PIC Detection Performance (for Sir Jude)

**Prepared for:** Sir Jude (Thesis Adviser)  
**Project:** PINYA-PIC — on-device mealybug detection (YOLO26s → TensorFlow Lite, Android)  
**Date:** May 2026 (updated with **mealybug_v16** interim metrics)  
**Student use:** Adapt into Chapter IV (Results) and Chapter V (Discussion); attach or email as briefing note.

> **Latest benchmark (v16, corrected test, May 2026):** mAP@0.5 **73.3%**, precision **80.6%**, recall **64.7%**, mAP@0.5:0.95 **40.7%**. Literature band **~70–74%**: see `docs/thesis/LITERATURE_mAP_70_78_BAND.md`. Panel video script: `docs/thesis/PANEL_UPDATE_VIDEO_SCRIPT.md`.

---

## 1. Purpose of this note

This memorandum explains why the reported model scores—**43.8% mAP@0.5** on the independent **test** set for the latest training run (**mealybug_v12**)—are **appropriate to report** and **normal in context**, even though they are lower than the “accuracy” percentages often seen in introductory machine-learning texts (e.g., 80–95% classification accuracy).

The PINYA-PIC system performs **object detection** (finding and localizing many small pests per image), not simple **image-level classification** (one label per photo). The evaluation protocol and literature therefore use **mAP@0.5**, **precision**, **recall**, and **F1**, not classical accuracy alone.

---

## 2. Our results in one table (fair comparison)

All models below were evaluated on the **same** Roboflow v10 benchmark (**462 test images**, **923 validation images**), at **confidence = 0.12**, **IoU = 0.45**, **input size 640×640**.

| Model | Role | Test mAP@0.5 | Test precision | Test recall | Test F1 |
|-------|------|-------------:|---------------:|------------:|--------:|
| v2 | Legacy baseline | 21.1% | 41.1% | 38.6% | 39.8% |
| v10 | Full ~17k train | 42.1% | 55.7% | 49.4% | 52.4% |
| v11 | Deployed in app (TFLite) | 43.0% | 56.2% | 49.2% | 52.5% |
| **v12** | **Latest training** | **43.8%** | **58.6%** | **51.3%** | **54.7%** |

**Key point for the adviser:** Performance **more than doubled** on the same test benchmark (21.1% → 43.8% mAP@0.5). The latest model is **not weak in isolation**; it is **strong relative to our baseline** and **aligned with a difficult detection task**.

**Recommended sentence for oral defense / email:**

> “On a held-out test set of 462 images, our latest YOLO26n model achieved **43.8% mean average precision at IoU 0.5**, with **58.6% precision** and **51.3% recall**, representing a substantial improvement over our legacy baseline (**21.1% mAP@0.5** on the same protocol).”

---

## 3. Why “low” percentages are normal (with academic support)

### 3.1 Object detection is not classification “accuracy”

In classification, accuracy is often \(\frac{TP + TN}{TP + TN + FP + FN}\) for a single label per image. In detection, each image may contain **zero to many** instances; a prediction is correct only if the **class** and **box location** both satisfy an **Intersection-over-Union (IoU)** threshold (commonly IoU ≥ 0.5). The standard summary metric is **mean Average Precision (mAP@0.5)**, formalized in large-scale benchmarks such as **Microsoft COCO** (Lin et al., 2014).

**Implication:** A “43.8% mAP@0.5” does **not** mean the model is wrong 56.2% of the time in the everyday sense. It reflects **strict box-level matching** averaged over images and categories.

### 3.2 Small objects are intrinsically harder (mealybugs)

Mealybugs on pineapple leaves are **tiny**, **low-contrast**, and often **dense**—a regime repeatedly described as challenging in the literature.

- Chen et al. (2020) state that **small object detection is an extremely challenging problem** and review why deep detectors struggle with limited spatial information, occlusion, and clutter.  
- Yu et al. (2026) summarize that YOLO-based detectors require **specialized adaptations** for small targets because of **complexity and diversity of real-world scenes**.  
- Surveys on small-object detection note that **AP for small objects (AP_S)** under the COCO protocol is typically **much lower** than for medium or large objects, and that researchers should not expect classification-like scores (Khan et al., 2025; Chen et al., 2020).

**Implication:** Moderate mAP on field-style imagery is **expected** for micro-pests, not evidence of a failed project.

### 3.3 Agricultural pest detection literature reports a wide range—and stresses difficulty

Peer-reviewed pest-detection work often reports **custom metrics** and **controlled imaging**; scores vary widely by dataset and task.

- **Wang et al. (2022)** (*Pest-YOLO*, *Frontiers in Plant Science*) explicitly list pest-detection challenges: **imbalanced samples**, **dense and tiny individuals**, and **inter-individual adhesion**. Their improved model reaches **69.59% mAP** on the **multi-class Pest24** dataset—under conditions different from our single-class, mobile, in-field pineapple use case.  
- **Yu et al. (2025)** (*YOLO-DCPG*) target **intensive small-target** pests and report **74% mAP@50** on Pest24 with a specialized lightweight architecture—again on a benchmark designed for pest detection research, not necessarily comparable to our test split without the same data and protocol.  
- **Mafuwe et al. (2026)** (*Scientific Reports*) show that **hyperparameters strongly affect** precision, recall, and mAP for pest detectors on sticky-trap imagery, underscoring that reported numbers are **protocol-dependent**, not universal “accuracy.”

**Implication:** Comparing PINYA-PIC to a **90%+** figure from another paper is only valid when the **same dataset, split, IoU, confidence, and task** are used. Our **internal** comparison (v2 → v12 on one test set) is methodologically sound.

### 3.4 Harder benchmarks yield lower absolute scores (COCO lesson)

Lin et al. (2014) show that strong detectors trained on one benchmark can exhibit a **large performance drop** when evaluated on a more difficult dataset (e.g., PASCAL-trained models evaluated on COCO). COCO baseline detection mAP values are **far below** naive “accuracy” expectations for non-experts.

**Implication:** Using a **rigorous held-out test set** (462 images) **honestly lowers** headline numbers but **increases** scientific credibility—preferred for thesis work.

### 3.5 Mobile deployment trades peak score for practicality

PINYA-PIC uses **YOLO26n** (nano) exported to **TensorFlow Lite** for **offline** use on farmer phones. Lightweight models trade capacity for **speed, size, and RAM** (Yu et al., 2025; Wang et al., 2022). Higher mAP often requires larger backbones or cloud inference, which is outside our design goals.

**Implication:** **43.8% test mAP@0.5** with on-device inference is a **defensible engineering outcome**, not a failed attempt to match datacenter-scale models.

### 3.6 Operational thresholds differ from benchmark confidence

The app uses **confidence 0.22** (possible detections) and **0.28** (confirmed counts) from a validation sweep, while benchmark mAP in this thesis uses **conf = 0.12** (common for cross-study comparison). That does not change the mAP headline but explains why **field usability** can differ from a single benchmark table.

---

## 4. What we are *not* claiming

- We do **not** claim “90% accuracy” unless we define the metric precisely (e.g., precision at a fixed threshold).  
- We do **not** claim mealybug detection is solved; **recall ~51%** on test means many labeled instances are still missed under strict matching.  
- We do **not** claim Roboflow test scores equal **in-field** performance on all farmer photos; domain gap remains a **limitation** and future work (field batches, label review, optional v12 deployment).

---

## 5. Conclusion (for Sir Jude)

The PINYA-PIC detection pipeline should be judged by:

1. **Standard detection metrics** (mAP@0.5, precision, recall, F1) on a **declared test split**;  
2. **Improvement over our own baseline** on the **same protocol** (21.1% → 43.8% test mAP@0.5); and  
3. **Alignment with published evidence** that **small, dense agricultural pests** are among the hardest targets for real-time detectors.

**43.8% mAP@0.5 (test)** for v12 is therefore **credible and defensible** for a capstone/thesis on a **mobile, offline, small-object** pest screening tool—not a sign that the model “failed,” but a sign that the evaluation is **honest and appropriate** to the task.

---

## 6. References (APA 7th edition)

Chen, C., Gong, M., Yang, X., & Zhang, L. (2020). Recent advances in small object detection based on deep learning: A review. *Image and Vision Computing*, *97*, 103910. https://doi.org/10.1016/j.imavis.2020.103910

Khan, M. A., Alhaisoni, M., Alharbi, S., Alshater, A., Alqahtani, T., Alqahtani, M., … Alshorman, N. (2025). Advancements in small-object detection (2023–2025): Approaches, datasets, benchmarks, applications, and practical guidance. *Applied Sciences*, *15*(22), 11882. https://doi.org/10.3390/app152211882

Lin, T.-Y., Maire, M., Belongie, S., Hays, J., Perona, P., Ramanan, D., Dollár, P., & Zitnick, C. L. (2014). Microsoft COCO: Common objects in context. In *Computer Vision – ECCV 2014* (pp. 740–755). Springer. https://doi.org/10.1007/978-3-319-10602-1_48

Mafuwe, K., Dulam, R. V. S., Kambhamettu, C., & Hoffmann, M. P. (2026). Comparative hyperparameter optimization of object detection models for precision monitoring of cucumber beetles and similar insects on yellow sticky cards. *Scientific Reports*. https://doi.org/10.1038/s41598-026-51483-1

Redmon, J., Divvala, S., Girshick, R., & Farhadi, A. (2016). You only look once: Unified, real-time object detection. In *Proceedings of the IEEE Conference on Computer Vision and Pattern Recognition* (pp. 779–788). https://doi.org/10.1109/CVPR.2016.91

Ultralytics. (2024). *YOLO26 documentation and model overview*. https://docs.ultralytics.com/ (Access for framework/version cited in thesis.)

Wang, Y., Zhou, Q., Zhang, J., Hou, Y., & Nie, X. (2022). Pest-YOLO: A model for large-scale multi-class dense and tiny pest detection and counting. *Frontiers in Plant Science*, *13*, Article 973985. https://doi.org/10.3389/fpls.2022.973985

Yu, H., Liu, J., & Lin, M. (2026). A comprehensive literature review on YOLO-based small object detection: Methods, challenges, and future trends. *Computers, Materials & Continua*, *87*(1), Article 7. https://doi.org/10.32604/cmc.2025.074191

Yu, X., Zhang, J., Wang, Y., & Li, Y. (2025). YOLO-DCPG: A lightweight architecture with dual-channel pooling gated attention for intensive small-target agricultural pest detection. *Frontiers in Plant Science*, *16*, Article 1716703. https://doi.org/10.3389/fpls.2025.1716703

---

## 7. Optional footnote for thesis (copy-paste)

> Classical classification accuracy (proportion of correct labels over all labels) was not used as the primary metric because PINYA-PIC performs instance-level object detection with variable counts per image; performance was evaluated using mAP@0.5, precision, recall, and F1 on held-out validation and test splits, following conventions established in the COCO benchmark (Lin et al., 2014) and consistent with agricultural pest-detection studies that emphasize small, dense targets (Chen et al., 2020; Wang et al., 2022).

---

*Internal data sources: `docs/training/MODEL_COMPARISON_V2_V10_V11_V12.md`, `runs/calibration/model_comparison_eval.json`, `runs/calibration/mealybug_v12_eval.json`, `docs/thesis/THESIS_CHAPTER_IV_MODEL_PERFORMANCE_DISCUSSION.md`.*
