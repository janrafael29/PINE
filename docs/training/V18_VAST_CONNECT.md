# V18 — Connect to Vast.ai (first time)

**Why:** Your PC has **no CUDA**. Local CPU jobs (threshold sweep, baseline @ 1280) take **many hours per run**. Everything in `v18_wave1_day1_vast.sh` should run on a Vast GPU instance.

**Stop local CPU sweeps** (Ctrl+C in the terminal) — they will not finish in reasonable time.

---

## What you can do on PC without Vast (already done)

| Item | Status |
|------|--------|
| App advisory messaging (#8) | ✅ |
| Two-tier UI + threshold 0.25 (#1 partial) | ✅ |
| CVAT Q1–Q3 top-50 packages | ✅ |
| Flutter tests | ✅ |
| Phase 0 on H100 (2026-06-10) | ✅ confusion + queues; verify baseline JSON |
| v20s training | 🔄 `docs/training/V18_PIPELINE_STATUS.md` |

**Live instance:** `root@219.86.90.208` port `40050`

---

## Step 1 — Rent a Vast instance

1. Go to [vast.ai](https://vast.ai) → **Console** → **Search**
2. Filters: **CUDA**, **≥ 30 GB disk**, **PyTorch** template (or Ubuntu + CUDA 12)
3. **GPU:** 1× H100 SXM, 4090, or 5090 all work — H100 finishes wave-1 jobs in **~30–60 min**
4. Click **Rent** → copy **SSH IP**, **port**, and connect command from the instance page

Minimum disk: **≥ 20 GB** free (bundle ~800 MB + outputs).

---

## Step 2 — Build upload bundle on PC

```powershell
cd D:\old_PINE
.\scripts\v18_wave1_bundle.ps1
```

Creates: `vast_upload\v18_wave1_bundle.zip` (~800 MB — test images + v16 weights + scripts)

**If full train dataset is already on Vast** from v15/v16 runs (`/workspace/pine/datasets/`), you can skip re-uploading train data; this bundle is only for **eval / audit / sweep**.

---

## Step 3 — Upload to Vast

Your PC already has Vast keys at `C:\Users\user\.ssh\`:

| File | Use |
|------|-----|
| **`vast_ed25519`** | **Use this** — same key as v15/v16/v19 Vast runs |
| `vast_key` | Alternate Vast key (if `vast_ed25519` fails, try this one) |
| `id_ed25519` | General SSH key |

Paste your instance **IP** and **port** from the Vast **SSH** button:

```powershell
$key = "$env:USERPROFILE\.ssh\vast_ed25519"   # C:\Users\user\.ssh\vast_ed25519
$ip = "YOUR_VAST_IP"
$port = YOUR_SSH_PORT

ssh -i $key -p $port root@$ip "mkdir -p /workspace/pine"
scp -i $key -P $port D:\old_PINE\vast_upload\v18_wave1_bundle.zip root@${ip}:/workspace/
```

---

## Step 4 — On Vast: unpack and install

```bash
cd /workspace
apt-get update -qq && apt-get install -y -qq unzip
unzip -q -o v18_wave1_bundle.zip -d /workspace/pine
cd /workspace/pine

pip install -q -U ultralytics opencv-python-headless pyyaml
chmod +x scripts/v18_wave1_day1_vast.sh
```

---

## Step 5 — Run GPU jobs

**Phase 0 only** (eval v16 — no training):

```bash
cd /workspace/pine
bash scripts/v18_wave1_day1_vast.sh
```

**Full pipeline to 85%** (needs train bundle uploaded first):

```bash
# After pine_v13afix_train_bundle.zip is unzipped to /workspace/pine/datasets/
cd /workspace/pine
nohup bash scripts/v18_full_pipeline_vast.sh > runs/v18_pipeline/nohup.log 2>&1 &
tail -f runs/v18_pipeline/pipeline.log
```

**Expected runtime:** Phase 0 ~1–3 hr; full pipeline ~12–24 hr on H100.

| Job | Output |
|-----|--------|
| Baseline val @ 1280 | `docs/thesis/assets/v18_baseline/v16_corrected_test_metrics.json` |
| Confusion export (1,952 imgs) | `docs/thesis/assets/confusion_cases_v16/` |
| Full CVAT queues + Q1–Q3 packages | `runs/audit/cvat_queues/`, `datasets/cvat_import/` |
| Threshold sweep @ 1280 | `runs/calibration/threshold_sweep_v16_1280.json` |

---

## Step 6 — Download results to PC

```powershell
$ip = "YOUR_VAST_IP"
$port = YOUR_SSH_PORT
$key = "$env:USERPROFILE\.ssh\vast_ed25519"   # C:\Users\user\.ssh\vast_ed25519

scp -i $key -P $port -r root@${ip}:/workspace/pine/docs/thesis/assets/v18_baseline D:\old_PINE\docs\thesis\assets\
scp -i $key -P $port -r root@${ip}:/workspace/pine/docs/thesis/assets/confusion_cases_v16 D:\old_PINE\docs\thesis\assets\
scp -i $key -P $port -r root@${ip}:/workspace/pine/runs/audit/cvat_queues D:\old_PINE\runs\audit\
scp -i $key -P $port -r root@${ip}:/workspace/pine/runs/calibration/threshold_sweep_v16_1280.json D:\old_PINE\runs\calibration\
scp -i $key -P $port -r root@${ip}:/workspace/pine/datasets/cvat_import D:\old_PINE\datasets\
```

---

## Step 7 — Destroy instance

When downloads are verified, **stop/destroy** the Vast instance to avoid extra charges.

---

## If you already have `/workspace/pine` from v16 training

You may only need to upload **scripts + corrected labels** (small), not the full test images:

```powershell
scp -i $key -P $port -r D:\old_PINE\scripts\capture_v16_baseline.py root@${ip}:/workspace/pine/scripts/
scp -i $key -P $port -r D:\old_PINE\scripts\v18_wave1_day1_vast.sh root@${ip}:/workspace/pine/scripts/
scp -i $key -P $port -r D:\old_PINE\datasets\mealybug_v13afix\test\labels_v16_corrected root@${ip}:/workspace/pine/datasets/mealybug_v13afix/test/
```

Then SSH in and run `bash scripts/v18_wave1_day1_vast.sh`.

---

## Parallel work while Vast runs

You do **not** need GPU for:

1. **CVAT** — import `datasets/cvat_import/Q1_false_negatives_top50/` and start FN review
2. **APK** — `flutter build apk --release` (local Gradle)
3. **Thesis** — paste panel response from `docs/thesis/PANEL_REVISION_RESPONSE_DRAFT.md`
