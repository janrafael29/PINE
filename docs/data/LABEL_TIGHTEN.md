# Label tightening & click-to-label

**Standalone PC system** (not the Flutter app). Docs: [`labeling_system/README.md`](../labeling_system/README.md), [`labeling_system/SCOPE.md`](../labeling_system/SCOPE.md), [`labeling_system/REANNOTATE_4K.md`](../labeling_system/REANNOTATE_4K.md).

Quick commands:

```powershell
# Re-annotate original ~4k (not 17k aug)
python labeling_system\tools\init_reannotate_4k.py --source "D:\your_original_4k"
python labeling_system\tools\click_app.py

# Tighten loose boxes on an existing export
python labeling_system\tools\tighten_batch.py --root mealybug.v10-8th-yolo26n.yolo26 --dry-run
```

Legacy paths `scripts\label_tighten.py` and `scripts\click_label_app.py` still forward to `labeling_system/tools/`.
