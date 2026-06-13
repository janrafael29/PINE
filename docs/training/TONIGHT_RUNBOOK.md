# V18 Overnight Runbook — 10 June 2026

**Status:** Phase 0 done on H100; **v20s training in progress.** Leave the Vast instance running.

---

## On the H100 (SSH)

```bash
ssh -i ~/.ssh/vast_ed25519 -p 40050 root@219.86.90.208
tail -f /workspace/pine/runs/v18_pipeline/pipeline.log
```

**Expected overnight:**

| Step | Status |
|------|--------|
| Phase 0 (baseline, confusion, queues, sweep) | ✅ |
| Wave 1 — `mealybug_v20_audit` | ✅ |
| Wave 2 — `mealybug_v20` dataset | ✅ |
| Wave 3a — **v20s** train | 🔄 |
| Wave 3b — **v20m** train | ⬜ After v20s |
| M1/M3 eval | ⬜ Morning |

**Do not destroy the instance** until logs show completion or a hard error.

---

## On your PC (morning)

1. **Download** artifacts — see `docs/training/V18_PIPELINE_STATUS.md` § Download  
2. **CVAT** — import `datasets/cvat_import/Q1_false_negatives_top50/` if not started  
3. **Verify** baseline JSON — if still 0% mAP, re-run `capture_v16_baseline.py` with fixed label paths on Vast  
4. **Check** `runs/retrain/mealybug_v20s/results.csv` after download

---

## If something failed

Paste last 30 lines of:

```bash
tail -30 /workspace/pine/runs/v18_pipeline/pipeline.log
```

---

*Supersedes the 2026-06-09 “TONIGHT” draft.*
