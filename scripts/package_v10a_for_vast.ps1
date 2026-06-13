# Zip v10+field dataset + v11 checkpoint + v10a train scripts for Vast.ai
#
# Usage:
#   .\scripts\package_v10a_for_vast.ps1
# Upload vast_upload\pine_v10a_train_bundle.zip, unzip, then:
#   cd pine && bash scripts/vast_train_v10a.sh

param(
    [string]$OutZip = "d:\old_PINE\vast_upload\pine_v10a_train_bundle.zip",
    [string]$DatasetDir = "datasets\mealybug_v10_plus_annotations"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root

if (-not (Test-Path $DatasetDir)) {
    throw "Missing $DatasetDir. Run merge_annotations_into_v10.py first."
}
$v11pt = "runs\retrain\mealybug_v11\weights\best.pt"
if (-not (Test-Path $v11pt)) {
    throw "Missing $v11pt"
}

$staging = Join-Path $Root "vast_upload\staging_v10a"
$outDir = Split-Path $OutZip -Parent

if (Test-Path $staging) {
    Remove-Item $staging -Recurse -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}
if (Test-Path $OutZip) { Remove-Item $OutZip -Force -ErrorAction SilentlyContinue }

New-Item -ItemType Directory -Path $staging -Force | Out-Null
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

$destDs = Join-Path $staging $DatasetDir
New-Item -ItemType Directory -Path (Split-Path $destDs -Parent) -Force | Out-Null
robocopy $DatasetDir $destDs /E /XD .git __pycache__ /XF *.cache *.bak /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed: $LASTEXITCODE" }

$items = @(
    "configs\train_v10a.yaml",
    "scripts\retrain_yolo.py",
    "scripts\vast_train_v10a.sh",
    "scripts\compare_v10a_v12.py",
    "scripts\requirements-train.txt",
    $v11pt
)
foreach ($rel in $items) {
    $src = Join-Path $Root $rel
    if (-not (Test-Path $src)) { throw "Missing $rel" }
    $dest = Join-Path $staging $rel
    $parent = Split-Path $dest -Parent
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    Copy-Item $src $dest -Force
}

Write-Host "Zipping v10a bundle..." -ForegroundColor Cyan
python (Join-Path $Root "scripts\zip_staging_bundle.py") --staging $staging --out $OutZip
if ($LASTEXITCODE -ne 0) { throw "Python zip failed." }

$mb = [math]::Round((Get-Item $OutZip).Length / 1MB, 1)
Write-Host ("Created {0} ({1} MB)" -f $OutZip, $mb) -ForegroundColor Green
Write-Host ""
Write-Host "Vast:" -ForegroundColor Yellow
Write-Host "  1. Upload pine_v10a_train_bundle.zip"
Write-Host "  2. unzip -q pine_v10a_train_bundle.zip -d pine"
Write-Host "  3. cd pine; bash scripts/vast_train_v10a.sh"
Write-Host "  4. Download runs/retrain/mealybug_v10a/weights/best.pt"
Write-Host "  5. python scripts/compare_v10a_v12.py"
