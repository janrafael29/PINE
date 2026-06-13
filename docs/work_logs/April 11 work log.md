# Work log — April 11, 2026

Detailed record of ML export tooling fixes, TFLite inspection updates, and release-build notes for the **PINE** project.

---

## 1. Context

- **Environment:** Windows 10, Python 3.13.2, project venv at `D:\PINE\.venv`
- **Hardware (training):** NVIDIA GeForce RTX 3050 Ti Laptop GPU (4 GB VRAM)
- **Stack:** Ultralytics 8.4.21, PyTorch 2.6.0+cu124, TensorFlow 2.21.0, Flutter/Android release builds (**training defaults have since moved to YOLO26n** in `scripts/retrain_yolo.py`; this log’s metrics are **YOLO11n**).

---

## 2. YOLO training — log interpretation (documentation)

> **Apr 2026 note:** This section describes a **YOLO11n** run. New training uses **YOLO26n** by default (`scripts/retrain_yolo.py`).

### 2.1 Initial training output

- **Resume:** Training continued from `runs\retrain\mealybug_v2\weights\last.pt` toward **50 total epochs** (e.g. from ~epoch 14).
- **Settings:** `batch=1`, `imgsz=640`, `cache=disk`, CUDA, dataset `datasets\data.yaml`.
- **Warnings understood:**
  - **Box vs segment count mismatch:** Mixed detect/segment style labels; Ultralytics uses **boxes only** and drops segments for detection training.
  - **Duplicate labels removed:** Automatic deduplication on a few images.
  - **`optimizer=auto`:** Ignores manual `lr0`; chose **AdamW** with learning rate **0.002**.

### 2.2 End-of-training metrics (epochs 47–50)

- **Validation set:** 923 images, 8105 instances.
- **Metrics:** Precision (P), Recall (R), mAP50, mAP50-95 — final **best.pt** validation approximately **P 0.565, R 0.402, mAP50 0.439, mAP50-95 0.209**.
- **Optimizer stripped from checkpoints:** Smaller `last.pt` / `best.pt` files; weights remain valid.
- **Artifacts:** `best.pt`, `last.pt`, ONNX export path during later TFLite pipeline.

---

## 3. TFLite export failures and fixes

### 3.1 Failure A — TensorFlow / `tf_keras` mismatch

**Symptom:**

```text
AttributeError: module 'tensorflow._api.v2.compat.v2.__internal__' has no attribute 'register_load_context_function'
```

**Cause:**

- TensorFlow **2.21.0** was installed for Python 3.13 compatibility.
- Ultralytics’ export path calls `check_requirements` with **`tf_keras<=2.19.0`**, triggering **pip AutoUpdate** that installed **`tf_keras` 2.15.0**.
- That standalone `tf_keras` build expects older TensorFlow internal APIs that are not present in TF 2.21.

**Mitigation (venv):**

```powershell
python -m pip install "tf_keras>=2.21,<2.22"
```

**Code changes (`scripts/retrain_yolo.py`):**

- **`_tf_keras_import_ok()`** — Import-time check with a clear pip hint if the mismatch appears.
- **`_configure_ultralytics_export_env()`** — Before TFLite export:
  - `ULTRALYTICS_SKIP_REQUIREMENTS_CHECKS=1`
  - `YOLO_AUTOINSTALL=false`  
  Stops Ultralytics from downgrading `tf_keras` during export (training behavior unchanged unless export runs in the same process).
- **`export_to_tflite()`** — Wraps `model.export()` in **`AttributeError`** handling for the same `register_load_context_function` message.

### 3.2 Failure B — `onnx2tf` TopK / NumPy scalar

**Symptom:**

```text
TypeError: only 0-dimensional arrays can be converted to Python scalars
```

at `onnx2tf\ops\TopK.py` (`int(k_tensor)` when `k` is a non-0-d NumPy array, e.g. shape `(1,)`).

**Cause:** YOLO → ONNX produces TopK with `k` as a constant array; **`onnx2tf` 1.28.8** used `int(ndarray)`, which NumPy rejects.

**Fix (`scripts/retrain_yolo.py`):**

- **`_onnx2tf_topk_py_path()`** — Resolves `Lib\site-packages\onnx2tf\ops\TopK.py` from `sys.executable` **without** importing `onnx2tf` (importing would trigger unrelated `onnx_graphsurgeon` / ONNX helper issues during discovery).
- **`_patch_onnx2tf_topk_on_disk()`** — Idempotent on-disk replacement:

  - From: ternary using `int(k_tensor)` for `np.ndarray`
  - To: `int(np.asarray(k_tensor).reshape(-1)[0])` for arrays, else `tf.cast(..., tf.int32)`

- After patching, clears **`sys.modules`** entries for `onnx2tf` so a reload picks up the change.
- **`TypeError`** handler on export for the “0-dimensional arrays” message with a short recovery hint.

**Package note:** **`onnx2tf` 1.29.24** was briefly tried; PyPI metadata pins a conflicting stack (e.g. older TF). Staying on **`onnx2tf` 1.28.x** (Ultralytics range `>=1.26.3,<1.29.0`) plus the local TopK patch is the stable approach.

### 3.3 Export verification

- Successful pipeline: **PyTorch → ONNX → SavedModel → `best_float16.tflite`** (~4.79 MB).
- Output layout aligned with training log: input **`(1, 3, 640, 640)`** BCHW in PT; TFLite **NHWC** **`[1, 640, 640, 3]`**, output **`[1, 300, 6]`**.

**Commands:**

```powershell
python scripts/retrain_yolo.py --export-only D:\PINE\runs\retrain\mealybug_v2\weights\best.pt
```

---

## 4. TFLite inspection script (`scripts/inspect_tflite.py`)

### 4.1 Problem

`tf.lite.Interpreter(...).allocate_tensors()` failed on **`best_float16.tflite`**:

```text
RuntimeError: tensorflow/lite/kernels/conv.cc:360 ... CONV_2D ... failed to prepare
```

**Reason:** Float16 graph feeds **CONV_2D** with **FP16** activations; the **desktop CPU** TFLite path does not accept that combination for this graph. **LiteRT** (`ai_edge_litert`) hit the same prepare error — not a corrupt file, but an interpreter limitation for local CPU smoke tests.

### 4.2 Solution

1. **Fallback:** Parse the **FlatBuffer schema** with **`ai_edge_litert.schema_py_generated.Model`** to print input/output **names, shapes, types** without allocating tensors.
2. **Fast path:** If the filename contains **`float16`** (case-insensitive), **skip importing TensorFlow** entirely — avoids oneDNN / deprecation / XNNPACK noise.
3. **CLI:** **`--schema-only`** for float16 models renamed (e.g. `best.tflite`).
4. **Environment:** `TF_CPP_MIN_LOG_LEVEL=2` when the TF interpreter path is used.

**Example output (schema path):**

- Input: `'images'`, shape `[1, 640, 640, 3]`, type **FLOAT16**
- Output: `'output0'`, shape `[1, 300, 6]`, type **FLOAT16**

**Commands:**

```powershell
python scripts/inspect_tflite.py D:\PINE\runs\retrain\mealybug_v2\weights\best_float32.tflite
python scripts/inspect_tflite.py assets\model\best.tflite --schema-only
```

---

## 5. Flutter / Android release build

### 5.1 Version bump (automated session)

- **`scripts/bump_pubspec_version.ps1`** was run with **`-Major`** during an automated attempt; **`pubspec.yaml`** updated to **`6.0.0+2019`** (current state in repo).

### 5.2 Build script (`scripts/build_release_auto_version.ps1`)

- Parameters: **`SupabaseUrl`**, **`SupabaseAnonKey`**, **`Target`** (`apk` | `aab`), **`SplitPerAbi`**, optional **`Major`**, **`Minor`**, **`Clean`**.
- Flow: optional `flutter clean` → bump version → `flutter pub get` → `flutter build` with `--dart-define=SUPABASE_URL` and `--dart-define=SUPABASE_ANON_KEY`.

### 5.3 Plain `flutter build apk --release` (without defines)

- **Java note** from `android_intent_plus` (unchecked operations): benign unless the build fails.
- **Icon tree-shaking:** normal size reduction for MaterialIcons.
- **Caveat:** Without **`--dart-define`**, Supabase compile-time constants from the script are **not** injected; use the PowerShell script (or equivalent defines) for production builds that depend on them.

**Recommended release command (example pattern):**

```powershell
.\scripts\build_release_auto_version.ps1 `
  -SupabaseUrl "https://<project>.supabase.co" `
  -SupabaseAnonKey "<anon_jwt>" `
  -Target apk `
  -SplitPerAbi `
  -Clean
```

(Add **`-Major`** / **`-Minor`** only when you intend to bump those segments.)

---

## 6. Security / hygiene

- **Supabase anon keys** were used in local commands; they are client-exposed by design but should not be posted in **public** channels. Rotate in the Supabase dashboard if exposure is a concern.
- **Patch persistence:** Reinstalling **`onnx2tf`** overwrites **`TopK.py`**. Re-running **`export_to_tflite`** re-applies the patch when the old pattern is detected.

---

## 7. Files touched (summary)

| File | Changes |
|------|--------|
| `scripts/retrain_yolo.py` | Export env guards, TopK on-disk patch, `tf_keras` preflight, error handling, `import os` |
| `scripts/inspect_tflite.py` | Schema inspection, `float16` fast path, `--schema-only`, TF log level |
| `pubspec.yaml` | Version **6.0.0+2019** (from Major bump in session) |
| `.venv\Lib\site-packages\onnx2tf\ops\TopK.py` | Patched locally (regenerated on pip reinstall unless export re-runs) |

---

## 8. Follow-ups (optional)

- [ ] Commit **`pubspec.yaml`** after intentional version bumps so CI/history stay aligned.
- [ ] Copy the exported TFLite into **`assets/model/best.tflite`** and rebuild (prefer **`best_float32.tflite`** if your phone can’t initialize float16-input kernels).
- [ ] Confirm Flutter `InferenceService` expectations match the exported model’s I/O (we standardized on **float32 I/O** for on-device robustness).
- [ ] Consider **`flutter build apk --release --split-per-abi`** for smaller per-ABI artifacts when not using the script.
- [ ] Upgrade **Ultralytics** when convenient (`pip install -U ultralytics`) to pick up upstream export/requirements improvements.

---

## 9. Quick reference commands

```powershell
# Export TFLite (after training)
python scripts/retrain_yolo.py --export-only D:\PINE\runs\retrain\mealybug_v2\weights\best.pt

# Inspect TFLite I/O (works for both float16/float32 exports)
python scripts/inspect_tflite.py D:\PINE\runs\retrain\mealybug_v2\weights\best_float32.tflite

# Repair tf_keras if something downgrades it again
python -m pip install "tf_keras>=2.21,<2.22"
```

---

*End of work log — April 11, 2026.*
