# Option A field-day helper: local YOLO pre-label (no Roboflow credits)
# Usage:
#   .\scripts\field_day_option_a.ps1 -Source "D:\field_photos\2026-05-21"
#   .\scripts\field_day_option_a.ps1 -Source "..." -Conf 0.25 -MarkEmpty

param(
    [Parameter(Mandatory = $true)]
    [string]$Source,
    [string]$Model = "d:\old_PINE\runs\retrain\mealybug_v2\weights\best.pt",
    [double]$Conf = 0.25,
    [switch]$MarkEmpty,
    [switch]$MergeAfterReview
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent

$py = "$root\.venv\Scripts\python.exe"
if (-not (Test-Path $py)) { $py = "python" }

$argsList = @(
    "$root\scripts\auto_label_yolo.py",
    "--source", $Source,
    "--model", $Model,
    "--conf", $Conf,
    "--mark-empty"
)
if (-not $MarkEmpty) {
    $argsList = $argsList | Where-Object { $_ -ne "--mark-empty" }
}

Write-Host "=== Option A: auto-label with local YOLO ===" -ForegroundColor Cyan
& $py @argsList
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$manifest = Get-ChildItem "$root\field_batches" -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Write-Host ""
Write-Host "Batch folder: $($manifest.FullName)" -ForegroundColor Green
Write-Host ""
Write-Host "NEXT (manual review):" -ForegroundColor Yellow
Write-Host "  1. Open CVAT (https://app.cvat.ai) or Label Studio — import images + YOLO labels"
Write-Host "  2. Fix missed mealybugs and delete false-positive boxes"
Write-Host "  3. Merge into datasets/train:"
Write-Host "     $py $root\scripts\merge_field_batch.py --batch `"$($manifest.FullName)`""
Write-Host ""
Write-Host "OPTIONAL Roboflow (no Label Assist):" -ForegroundColor Yellow
Write-Host "  Upload reviewed batch only (~200 imgs) via browser for cloud backup"
Write-Host ""
Write-Host "TRAIN (after merge):" -ForegroundColor Yellow
Write-Host "  See RUN.md section 6 — retrain_yolo.py or Vast GPU when dataset is ready"

if ($MergeAfterReview) {
    Write-Host "MergeAfterReview set — running merge (skip if not reviewed yet)." -ForegroundColor Magenta
    & $py "$root\scripts\merge_field_batch.py" --batch $manifest.FullName
}
