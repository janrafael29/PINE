# V18 Wave 1 — local follow-up (after Day 1 sample)

```powershell
cd D:\old_PINE

# Optional: expand queue scan on PC (slow on CPU — prefer Vast for --limit 0)
python scripts/build_cvat_audit_queues.py --limit 400 --package 50 --imgsz 640

# After Vast download: verify baseline
Get-Content docs\thesis\assets\v18_baseline\v16_corrected_test_metrics.json
```

CVAT import folder (ready now):

```
datasets\cvat_import\Q1_false_negatives_top50\images\
```
