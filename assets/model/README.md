# Bundled on-device model

| Field | Value |
|-------|--------|
| **Model ID** | `mealybug_v16_selffix` |
| **Asset** | `best.tflite` (float32) |
| **Source weights** | `runs/retrain/mealybug_v16_selffix/weights/best.pt` |
| **Export** | `python scripts/retrain_yolo.py --export-only runs/retrain/mealybug_v16_selffix/weights/best.pt --export-imgsz 1280` |
| **Inference input** | **1280×1280** letterbox (`AppConstants.inputSize`) |
| **Deploy threshold** | **0.25** |

**Expect:** slower scans and higher RAM than 640px v13. Best on plant close-ups; turn off Accuracy mode for people/indoor photos.

Regenerate:

```powershell
python scripts/retrain_yolo.py --export-only runs/retrain/mealybug_v16_selffix/weights/best.pt --export-imgsz 1280
copy runs\retrain\mealybug_v16_selffix\weights\best_saved_model\best_float32.tflite assets\model\best.tflite
```

Then **full restart** the app (hot reload does not reload TFLite).

`AppConstants.inputSize` must stay **1280** to match this export.
