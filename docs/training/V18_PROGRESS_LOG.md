# V18 Progress Log

*Weekly updates against `docs/training/V18_PANEL_REVISION_PLAN.md`.*

| Field | Value |
|-------|-------|
| Plan start | 2026-05-29 |
| **Last updated** | **2026-06-10** |
| Target finish (track) | A — full plan (~Sep 2026) |
| **85% targets plan** | `docs/training/PLAN_TO_85_ALL_METRICS.md` |
| **Current phase** | **Wave 3 — v20s training on H100** |
| Shipped model | `mealybug_v16_selffix` @ conf **0.25** |
| Pipeline status | `docs/training/V18_PIPELINE_STATUS.md` |
| Work log | `docs/work_logs/June 10 work log.md` |

---

## Metric tracker (corrected test, imgsz 1280, conf 0.001)

| Version | mAP@0.5 | Precision | Recall | mAP@0.5:0.95 | Date |
|---------|--------:|----------:|-------:|-------------:|------|
| v16 baseline | 73.3% | 80.6% | 64.7% | 40.7% | 2026-05-29 (V16 log) |
| v20s | *training* | — | — | — | 2026-06-10 |
| v20m | ⬜ | — | — | — | |

**Panel targets:** mAP@0.5 ≥85%, R ≥80%, P ≥80%, mAP@0.5:0.95 ≥55%

---

## Weekly log

### Week 0 (May 29 – Jun 4) — Phase 0

- [x] v16 weights retained (`best.pt`)
- [x] `labels_v16_corrected` generated (1,952 label files)
- [x] Eval staging + `capture_v16_baseline.py` / `label_eval_utils.py`
- [x] Confusion export @ 1952 images (Vast, 2026-06-10)
- [x] CVAT setup guide + panel response draft
- [x] Day 1 sample (150 img) + top-50 Q1–Q3 packages
- [x] Vast Phase 0 GPU run (`v18_wave1_day1_vast.sh`)
- [x] Full CVAT queues on 1,952 test images
- [ ] Baseline JSON reproduces 73.3% (first run 0% — label path)
- [ ] Threshold sweep @ 1280 downloaded to PC
- [ ] Import Q1_FN_top50 to CVAT (human)
- **Notes:** Top FN: `test_000116.jpg` (86 missed boxes).

### Week 1 (Jun 3 – Jun 11) — Phase 1 + early v20

- [x] Two-tier UI + deploy threshold 0.25 (shipped May 29)
- [x] Advisory messaging (#8)
- [x] `SYSTEM_ARCHITECTURE.md` thesis doc
- [x] Project disk cleanup 124→39 GB
- [x] Wave 1–2: `mealybug_v20_audit` + `mealybug_v20` dataset on H100
- [ ] v16 threshold sweep @ 1280 (confirm complete)
- [ ] v20s M1 eval after train
- **Notes:** v20s train started 2026-06-10 ~14:34 UTC on H100.

### Weeks 2–3 — Phase 2 (annotation audit)

- [ ] Images audited: ___ / 800
- **Notes:** CVAT import ready; human review not started.

### Weeks 4–5 — Phase 3 (field data)

- [ ] New base photos: ___ / 1500
- [ ] Field batch May 2025 merge
- **Notes:**

### Weeks 6–7 — Phase 4 (train stack)

- [ ] v20m trained + M3 gate
- [ ] TFLite export chosen: 640 / 960
- **Notes:** v20s/m accelerated on 2026-06-10 pipeline.

### Week 8+ — Phase 5–6

- [ ] v21 consensus labels (queued)
- [ ] Expert re-val (n=___)
- [ ] Thesis Ch. IV updated for v20 if promoted

---

## Blockers

| Date | Blocker | Owner | Resolution |
|------|---------|-------|------------|
| 2026-05-29 | CPU baseline val @ 1280 estimated 6+ hrs | ML lead | Use Vast GPU runbook |
| 2026-06-10 | Baseline capture 0% on Vast (no labels found) | ML lead | Fix label paths; re-run `capture_v16_baseline.py` |
