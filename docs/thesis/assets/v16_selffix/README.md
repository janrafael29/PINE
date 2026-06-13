# mealybug_v16_selffix — presentation graphs

Generated from `runs/retrain/mealybug_v16_selffix/results.csv`.

| File | Description |
|------|-------------|
| `v16_selffix_training_curves.png` | 2×2: box/cls loss, P/R, mAP — **training val** (~66% peak) |
| `v16_selffix_map_progression.png` | mAP@0.5, precision, recall vs epoch — **training val** |
| `v16_test_benchmark_73.3.png` | **Held-out TEST** — legacy ~66% vs corrected **73.3%** (+ P/R/mAP50-95) |
| `v16_test_headline_73.3.png` | Summary card for **73.3%** headline |

**Regenerate:**

```powershell
cd D:\old_PINE
python scripts/plot_v16_panel_graphs.py
```

**Panel slides:** `docs/thesis/panel_video_slides.html` (slides 5–6)

**Note:** Best **val** mAP@0.5 during training ≈ **66.3%** (epoch 67). **Test** mAP@0.5 on corrected labels = **73.3%** (different split/protocol).
