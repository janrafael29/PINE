# V18 Wave 1 — upload bundle for Vast GPU jobs (baseline, confusion, CVAT queues, threshold sweep).
# Usage: .\scripts\v18_wave1_bundle.ps1
#
# Upload the resulting zip + run docs/training/V18_VAST_CONNECT.md on the instance.

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
$Staging = Join-Path $Root "vast_upload\staging_v18_wave1"
$Zip = Join-Path $Root "vast_upload\v18_wave1_bundle.zip"

$weights = Join-Path $Root "runs\retrain\mealybug_v16_selffix\weights\best.pt"
$testImg = Join-Path $Root "datasets\mealybug_v13afix\test\images"
$testLbl = Join-Path $Root "datasets\mealybug_v13afix\test\labels_v16_corrected"
$dataYaml = Join-Path $Root "runs\calibration\data_v16_corrected_test.yaml"

foreach ($p in @($weights, $testImg, $testLbl, $dataYaml)) {
    if (-not (Test-Path $p)) { throw "Missing required path: $p" }
}

if (Test-Path $Staging) { Remove-Item $Staging -Recurse -Force }
$dirs = @(
    "$Staging\runs\retrain\mealybug_v16_selffix\weights",
    "$Staging\datasets\mealybug_v13afix\test\images",
    "$Staging\datasets\mealybug_v13afix\test\labels_v16_corrected",
    "$Staging\runs\calibration",
    "$Staging\scripts"
)
foreach ($d in $dirs) { New-Item -ItemType Directory -Force -Path $d | Out-Null }

Copy-Item $weights "$Staging\runs\retrain\mealybug_v16_selffix\weights\best.pt" -Force
Copy-Item "$testImg\*" "$Staging\datasets\mealybug_v13afix\test\images\" -Force
Copy-Item "$testLbl\*" "$Staging\datasets\mealybug_v13afix\test\labels_v16_corrected\" -Force

# Vast paths inside eval yaml (label_eval_utils will restage under /workspace/pine)
$yaml = Get-Content $dataYaml -Raw
$yaml = $yaml -replace 'path:.*', 'path: /workspace/pine/runs/calibration/mealybug_v16_corrected_eval'
$yaml | Set-Content "$Staging\runs\calibration\data_v16_corrected_test.yaml" -Encoding utf8

$scriptFiles = @(
    "capture_v16_baseline.py",
    "label_eval_utils.py",
    "export_confusion_cases.py",
    "build_cvat_audit_queues.py",
    "sweep_detection_threshold.py",
    "fix_test_labels.py",
    "audit_annotations.py",
    "auto_fix_annotations.py",
    "prepare_mealybug_v20_audit.py",
    "build_mealybug_v20_dataset.py",
    "requirements-train.txt",
    "v18_wave1_day1_vast.sh",
    "v18_full_pipeline_vast.sh"
)
foreach ($f in $scriptFiles) {
    Copy-Item (Join-Path $Root "scripts\$f") "$Staging\scripts\" -Force
}

if (Test-Path $Zip) { Remove-Item $Zip -Force }
python (Join-Path $Root "scripts\zip_staging_bundle.py") --staging $Staging --out $Zip
$mb = [math]::Round((Get-Item $Zip).Length / 1MB, 1)
Write-Host "Ready: $Zip ($mb MB)"
Write-Host "Next: docs/training/V18_VAST_CONNECT.md"
