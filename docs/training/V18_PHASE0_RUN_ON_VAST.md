# V18 Phase 0 — GPU commands (Vast)

**Start here if you have not connected yet:** `docs/training/V18_VAST_CONNECT.md`

Local CPU validation @ 1280 on 1,952 images takes **many hours** (your screenshot showed ~34 s/batch on CPU — stop and use Vast). Run these on Vast after uploading weights + dataset.

## Upload (from PC)

```powershell
# Weights + corrected labels + staging script
scp -P <PORT> runs/retrain/mealybug_v16_selffix/weights/best.pt root@<HOST>:/workspace/runs/train/mealybug_v16_selffix/weights/
scp -r datasets/mealybug_v13afix/test/{images,labels_v16_corrected} root@<HOST>:/workspace/datasets/mealybug_v13afix/test/
scp scripts/capture_v16_baseline.py scripts/label_eval_utils.py root@<HOST>:/workspace/scripts/
```

## On Vast

```bash
cd /workspace
python scripts/capture_v16_baseline.py --skip-label-fix

# Full confusion export for CVAT queues
python scripts/export_confusion_cases.py --max-images 1952 --samples-per-class 8 --conf 0.25

# Download results back to PC
# docs/thesis/assets/v18_baseline/
# docs/thesis/assets/confusion_cases_v16/
```

## Expected baseline (exit criterion)

| Metric | Target |
|--------|--------|
| mAP@0.5 | **73.3%** ± 0.5 pp |
| Precision | ~80.6% |
| Recall | ~64.7% |
| mAP@0.5:0.95 | ~40.7% |
