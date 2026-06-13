# Thesis v16 — Final Status

*Latest draft — May 2026*

---

## Verdict: **ready for defense**

v16 metrics, Table 3 vs Table 5, model size (~37 MB), and APK context are aligned. Optional polish below only.

---

## Size reference (for panel questions)

| What | Size | Where in thesis |
|------|------|-----------------|
| **TFLite model** (`best.tflite`, v16) | **~37 MB** | Table 10, §4.1.6, Appendix H |
| **Earlier build** (historical) | ~5.42 MB | §4.1.6 opening sentence (OK as contrast) |
| **Release APK** (arm64-v8a, whole app) | **~79 MB** | Not in thesis yet — optional note in §3.5.3 |
| **Split APK per ABI** (thesis §3.4.5) | ~29–36 MB download | Historical comparison vs universal ~85 MB |

**Panel line:** “Table 10 is the detector file only (~37 MB). The ~79 MB APK is the full Flutter app plus native libraries and assets—not the model alone.”

---

## Optional polish (not blocking)

| Location | Issue | Suggested fix |
|----------|--------|----------------|
| Table 10 title | “After Quantization” | Use **“Deployed TensorFlow Lite Model (float32)”** — v16 export is not int8-quantized |
| §4.1.6 last sentence | “relatively small model size” for ~37 MB | **“acceptable for on-device deployment”** (avoids panel pushback on “small”) |
| §3.5.3 or §3.4.5 | APK size not stated | One sentence: release `app-arm64-v8a-release.apk` ≈ **79 MB** (includes app + bundled assets) |
| §3.4.8.3.3 | “True Negatives **(FN)**” | **(TN)** |
| List of Tables | Table 10 title | Match renamed table caption |

---

## Verified correct

- Abstract, §1.3, Tables 5–6, §4.1.2, §4.4, Ch V — v16 / 73.3% / ~66%
- Table 3 — 0.717 / 0.528 (intermediate only)
- §3.3.2.1.6 — 71.7%, Tables 5–6 reference
- §4.1.1 — Tables 5–6
- Table 10 — ~36.4–37 MB
- Appendix H — ~37 MB
- §5.1.3 — held-out benchmarking wording

---

## Code / APK (defense build)

`lib/core/constants.dart` → `best.tflite`, `mealybug_v16_selffix`, 640px, 25% threshold.

Rebuild APK after constants change so the demo matches the thesis.

**Note:** If `assets/model/v13afix_best.tflite` remains in the project, the APK may still bundle both models (~46 MB assets). Removing the legacy file before release shrinks install size slightly; only `best.tflite` is required for v16.

---

## Panel one-liners

| Question | Answer |
|----------|--------|
| Final model? | **mealybug_v16_selffix** |
| Headline mAP? | **73.3%** — 1,952 images, **18,891** corrected GT boxes |
| Why ~66%? | Same images, **legacy** labels (Table 6) |
| 56.7% vs 73.3%? | Different test set (462 vs 1,952) and label protocol |
| Model size? | **~37 MB** TFLite (Table 10) |
| Why is APK ~79 MB? | **Whole application**, not the model file alone |
| 33.2% in field? | UI confidence at **25%** threshold — not mAP |
| Expert 91.75% F1? | **21 field images** — not mAP |
