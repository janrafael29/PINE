# Train mealybug_v12 (1024 px, 200 epochs)

Experimental high-resolution run using the hyperparameters you specified. **Run on Vast** (24GB GPU recommended for **batch 8 @ 1024**).

## Preset (source of truth)

`configs/train_v12_highres.yaml` — loaded by `--preset v12-highres`.

| Setting | Value | Notes |
|---------|-------|--------|
| Epochs | 200 | |
| Image size | 1024 | Train only; app still uses 640 unless you change `AppConstants.inputSize` |
| Batch | **8** | Raise with `BATCH=16` on 40GB+ if stable |
| Optimizer | AdamW | |
| lr0 | 0.0005 | |
| lrf | 0.01 | |
| LR schedule | Cosine (`cos_lr: true`) | |
| Warmup | 2 epochs | |
| Weight decay | 0.0005 | |
| Patience | 0 | Disables early stopping (full 200 epochs) |
| Dropout | 0.15 | |
| cls / box / dfl | 1.5 / 7.5 / 1.5 | |
| close_mosaic | 15 | |
| Val conf / IoU | 0.30 / 0.70 | Training-time validation only |
| Weights | `mealybug_v11/best.pt` | Fine-tune from shipped model |
| Data | `mealybug.v10-8th-yolo26n.yolo26/data.yaml` | ~17k aug |

## Dry-run (check config on PC)

```powershell
cd D:\old_PINE
python scripts/retrain_yolo.py --preset v12-highres --dry-run
```

## Vast (step-by-step)

See **`docs/training/VAST_V12_GUIDE.md`** for instance filters, disk, and SSH. Short version:

1. Package on Windows:

   ```powershell
   cd D:\old_PINE
   .\scripts\package_v12_for_vast.ps1
   ```

2. Rent GPU on [cloud.vast.ai](https://cloud.vast.ai) (≥24 GB VRAM, ≥50 GB disk).

3. Upload `vast_upload\pine_v12_train_bundle.zip`, unzip to `pine/`, run `bash scripts/vast_train_v12.sh`.

3. Download `runs/retrain/mealybug_v12/weights/best.pt`

4. Export TFLite at **640** for the current app:

   ```powershell
   python scripts/retrain_yolo.py --export-only runs/retrain/mealybug_v12/weights/best.pt --export-imgsz 640
   copy runs\retrain\mealybug_v12\weights\best_float32.tflite assets\model\best.tflite
   ```

5. Re-benchmark:

   ```powershell
   python scripts/evaluate_model_accuracy.py --model runs/retrain/mealybug_v12/weights/best.pt --data mealybug.v10-8th-yolo26n.yolo26/data.yaml --conf 0.12 --out runs/calibration/mealybug_v12_eval.json
   python scripts/sweep_detection_threshold.py --model runs/retrain/mealybug_v12/weights/best.pt
   ```

## Important caveats

1. **VRAM:** Default **batch 8** at 1024. Use `BATCH=16` only on large GPUs if training is stable.
2. **Mobile:** Training at 1024 does not require 1024 inference. Export at **640** to match `AppConstants.inputSize` and keep ~150–280 ms inference.
3. **Val conf 0.30** is for **training validation**, not app deploy (app uses **0.22 / 0.28** after v11 sweep).
4. **Time:** 200 epochs on 16k images may take **many hours** (estimate 12–24+ h depending on GPU and batch).
5. **Thesis:** If v12 beats v11 on **test mAP**, update Chapter IV; until then v11 remains the reported shipped model.

## Override single flags

```powershell
python scripts/retrain_yolo.py --preset v12-highres --batch 8 --epochs 50 --name mealybug_v12_smoke
```
