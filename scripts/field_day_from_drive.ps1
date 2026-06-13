# Field day: collect team Drive folders → auto-label → (you review) → augment → merge
#
# 1. Sync/download your Drive parent folder to PC, e.g.:
#      D:\PINYA field day 2026-05-19\
#        era\  ghaz\  jan\  ...  FOR VALIDATION\  datasets\
#
# 2. Run:
#      .\scripts\field_day_from_drive.ps1 -Source "D:\PINYA field day 2026-05-19"
#
# 3. Review labels in CVAT, then:
#      .\scripts\field_day_from_drive.ps1 -Source "..." -AugmentAndMerge -Batch field_batches\...

param(
    [Parameter(Mandatory = $true)]
    [string]$Source,
    [string]$Model = "d:\old_PINE\runs\retrain\mealybug_v2\weights\best.pt",
    [double]$Conf = 0.25,
    [int]$AugmentCopies = 3,
    [switch]$MarkEmpty,
    [switch]$SkipCollect,
    [switch]$SkipLabel,
    [string]$Batch = "",
    [switch]$AugmentAndMerge
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$py = "$root\.venv\Scripts\python.exe"
if (-not (Test-Path $py)) { $py = "python" }

$staging = $null
if (-not $SkipCollect) {
    Write-Host "=== Collect team folders ===" -ForegroundColor Cyan
    & $py "$root\scripts\collect_field_photos.py" --source $Source
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $staging = Get-ChildItem "$root\field_staging" -Directory |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    Write-Host "Staging: $($staging.FullName)" -ForegroundColor Green
}

if (-not $SkipLabel) {
    $labelSource = if ($staging) { $staging.FullName } else { $Source }
    Write-Host "=== Auto-label (Option A) ===" -ForegroundColor Cyan
    $argsList = @(
        "$root\scripts\auto_label_yolo.py",
        "--source", $labelSource,
        "--model", $Model,
        "--conf", $Conf
    )
    if ($MarkEmpty) { $argsList += "--mark-empty" }
    & $py @argsList
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$batchDir = $Batch
if (-not $batchDir) {
    $latest = Get-ChildItem "$root\field_batches" -Directory |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latest) { $batchDir = $latest.FullName }
}

if ($AugmentAndMerge) {
    if (-not $batchDir) {
        Write-Error "No field_batches folder found. Pass -Batch path after review."
    }
    Write-Host "=== Augment reviewed batch (~$($AugmentCopies + 1)x) ===" -ForegroundColor Cyan
    & $py "$root\scripts\augment_yolo_subset.py" --batch $batchDir --copies-per-image $AugmentCopies
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host "=== Merge into datasets/train ===" -ForegroundColor Cyan
    & $py "$root\scripts\merge_field_batch.py" --batch $batchDir
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host "DONE — manual steps:" -ForegroundColor Yellow
Write-Host "  1. Review/fix labels in CVAT (import images + YOLO from field_batches\...)"
Write-Host "  2. FOR VALIDATION copies are in field_staging\*_for_validation (expert QA)"
Write-Host "  3. After review:"
Write-Host "     .\scripts\field_day_from_drive.ps1 -Source `"$Source`" -AugmentAndMerge -Batch `"$batchDir`" -SkipCollect -SkipLabel"
Write-Host ""
Write-Host "Adding to full ~17k:" -ForegroundColor Yellow
Write-Host "  - This merge updates local datasets/train (current train set)."
Write-Host "  - For Roboflow v11: upload reviewed batch in browser, Generate 4x, export YOLO zip."
Write-Host "  - Re-train on Vast after current run finishes (or start mealybug_field_v11)."
