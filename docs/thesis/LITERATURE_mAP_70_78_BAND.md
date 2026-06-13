# Literature: ~70–78% mAP band for agricultural / small pest detection

Use this block in Chapter IV (Discussion), panel slides, and the progress video.  
**PINYA-PIC v16 (corrected test):** mAP@0.5 **73.3%**, P **80.6%**, R **64.7%**, mAP@0.5:0.95 **40.7%**.

---

## Is 73.3% acceptable?

**Yes, for an interim / panel update**, when stated with protocol and literature context:

1. **In-band with pest-detection papers** on multi-class or dense small insects (~**69–74% mAP@0.5** on dedicated pest benchmarks), not with easy single-object classification.
2. **Recall (64.7%)** is the honest weakness—missed tiny/occluded mealybugs; aligns with known small-object limits (Chen et al., 2020).
3. **Report both** legacy-test (~66%) and corrected-test (**73.3%**) so examiners see transparency.
4. **Not final** until expert re-validation on v16 TFLite and any further training (v17+).

**Suggested thesis sentence:**

> On the v16-consensus corrected test split (1,952 images; 18,891 instances), mealybug_v16_selffix achieved **73.3% mAP@0.5**, comparable to published agricultural pest detectors on large-scale pest benchmarks (**69.6–74.0% mAP@0.5**; Wang et al., 2022; Zhang et al., 2022; Yu et al., 2025), while remaining below ideal recall for production scouting.

---

## Core citations (adviser + two additional)

### 1. Zhang et al. (2022) — **71.3% mAP@0.5**

Zhang, W., Huang, H., Sun, Y., & Wu, X. (2022). AgriPest-YOLO: A rapid light-trap agricultural pest detection method based on deep learning. *Frontiers in Plant Science*, *13*, 1079384. https://doi.org/10.3389/fpls.2022.1079384

- **Reported:** **71.3% mAP** on Pest24 test (24 classes, ~25k images); light-trap imagery with scale variation, dense pests, complex backgrounds.
- **Relevance:** Same “real-world pest monitoring” difficulty class as PINYA-PIC; co-author **Wu X.** links to pest-detection line of work.

### 2. Wu et al. (2019) — benchmark & difficulty (not 70% itself)

Wu, X., Zhan, C., Lai, Y.-K., Cheng, M.-M., & Yang, J. (2019). IP102: A large-scale benchmark dataset for insect pest recognition. In *Proceedings of the IEEE/CVF Conference on Computer Vision and Pattern Recognition (CVPR)* (pp. 8787–8796). https://doi.org/10.1109/CVPR.2019.00342

- **Reported (detection split, Table 6):** e.g. YOLOv3 **AP.50 = 50.64%**; FPN **AP.50 = 54.93%**; COCO-style **AP = 25.67–28.10%** (IoU 0.5:0.95).
- **Relevance:** Establishes that **insect pest detection at scale is hard**; later specialized YOLO models (Zhang, Wang, Yu) reach the **~70%+ mAP@0.5** band on richer pest datasets—not contradictions, but **progress on the same problem domain**.

### 3. Wang et al. (2022) — **69.59% mAP** *(additional reference #1)*

Wang, Y., Zhou, Q., Zhang, J., Hou, Y., & Nie, X. (2022). Pest-YOLO: A model for large-scale multi-class dense and tiny pest detection and counting. *Frontiers in Plant Science*, *13*, 973985. https://doi.org/10.3389/fpls.2022.973985

- **Reported:** **69.59% mAP**, **77.71% mean recall** on Pest24 (>20k images, 24 classes, dense/tiny pests, occlusion).
- **Relevance:** Explicitly addresses **dense and tiny** pests—closest task analogy to mealybugs on leaves.

### 4. Yu et al. (2025) — **74% mAP@0.5** *(additional reference #2)*

Yu, X., Zhang, J., Wang, Y., & Li, Y. (2025). YOLO-DCPG: A lightweight architecture with dual-channel pooling gated attention for intensive small-target agricultural pest detection. *Frontiers in Plant Science*, *16*, 1716703. https://doi.org/10.3389/fpls.2025.1716703

- **Reported:** **74% mAP@50** on Pest24 for intensive **small-target** pests.
- **Relevance:** Supports the **upper end (~74%)** of the 70–78% band for small-target agricultural detection.

---

## Optional supporting citations (small objects / surveys)

Chen, C., Gong, M., Yang, X., & Zhang, L. (2020). Recent advances in small object detection based on deep learning: A review. *Image and Vision Computing*, *97*, 103910. https://doi.org/10.1016/j.imavis.2020.103910

Lin, T.-Y., Maire, M., Belongie, S., Hays, J., Perona, P., Ramanan, D., Dollár, P., & Zitnick, C. L. (2014). Microsoft COCO: Common objects in context. In *Computer Vision – ECCV 2014* (pp. 740–755). Springer. https://doi.org/10.1007/978-3-319-10602-1_48

---

## Validation instruments (link to model—not mAP)

| Layer | Instrument | Source in thesis | Key result | Connects to model how? |
|-------|------------|------------------|------------|-------------------------|
| Usability | **SUS** (10 items, 5-point Likert) | §3.4.2–3.4.3; Brooke, 1986 | Mean **77.0** (n=10) | Users can complete scan→save workflow that **displays** model outputs |
| Expert field check | 7 images × 3 validators; TP/FP/FN at **30%** threshold | §4.1.3–4.1.4; THESIS_CHAPTER_IV_METRICS_SECTION | **91.75% F1** (v13afix era) | Operational correctness of **boxes at deploy threshold** |
| Automated benchmark | Ultralytics `yolo val`, mAP@0.5 | §4.1.1; V16_TRAINING_LOG | **73.3%** (v16 corrected test) | Detector quality on **1,952** labeled images |

**Do not** call expert F1 or SUS “mAP.”

---

## Paste-ready paragraph (Chapter IV / panel slide)

Comparable studies on **dense, small agricultural pests** report test **mAP@0.5** roughly between **70% and 74%** under field-relevant imaging: **69.6%** (Wang et al., 2022), **71.3%** (Zhang et al., 2022), and **74%** (Yu et al., 2025), on large multi-class pest datasets with occlusion and scale variation. Wu et al. (2019) earlier showed that generic detectors on the IP102 detection split achieve far lower AP, highlighting dataset and task difficulty. PINYA-PIC’s **73.3% mAP@0.5** on a single-class, corrected held-out test set is **within this published band**, while **64.7% recall** indicates remaining missed instances—consistent with small-object detection limits (Chen et al., 2020). Usability (SUS = 77.0) and expert field validation (91.75% F1 at the 30% deploy threshold, v13afix build) address whether the system is **usable and trustworthy in operation**, complementing benchmark mAP.
