# Zip v10 dataset + v11 checkpoint + v12 train scripts for Vast.ai
#
# Usage:
#   .\scripts\package_v12_for_vast.ps1
# Upload vast_upload\pine_v12_train_bundle.zip, unzip, then:
#   cd pine && bash scripts/vast_train_v12.sh

param(
    [string]$OutZip = "d:\old_PINE\vast_upload\pine_v12_train_bundle.zip",
    [string]$V10Dir = "mealybug.v10-8th-yolo26n.yolo26"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root

if (-not (Test-Path $V10Dir)) {
    throw "Missing $V10Dir"
}
$v11pt = "runs\retrain\mealybug_v11\weights\best.pt"
if (-not (Test-Path $v11pt)) {
    throw "Missing $v11pt - train or download mealybug_v11 first."
}

$staging = Join-Path $Root "vast_upload\staging_v12"
$outDir = Split-Path $OutZip -Parent

# Remove stale staging / broken zip (Compress-Archive can leave locked temps)
if (Test-Path $staging) {
    Remove-Item $staging -Recurse -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}
if (Test-Path $OutZip) { Remove-Item $OutZip -Force -ErrorAction SilentlyContinue }
Get-ChildItem (Join-Path $Root "vast_upload") -Filter "*.zip.tmp" -ErrorAction SilentlyContinue | Remove-Item -Force

New-Item -ItemType Directory -Path $staging -Force | Out-Null
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

$destDs = Join-Path $staging $V10Dir
New-Item -ItemType Directory -Path $destDs -Force | Out-Null
# Exclude caches/backups only (keep YOLO label .txt files)
robocopy $V10Dir $destDs /E /XD .git __pycache__ /XF *.cache *.bak /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed: $LASTEXITCODE" }

$items = @(
    "configs\train_v12_highres.yaml",
    "scripts\retrain_yolo.py",
    "scripts\vast_train_v12.sh",
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

Write-Host "Zipping v12 bundle (Python zipfile, avoids Compress-Archive locks)..." -ForegroundColor Cyan

python (Join-Path $Root "scripts\zip_staging_bundle.py") --staging $staging --out $OutZip
if ($LASTEXITCODE -ne 0) {
    throw "Python zip failed. Close Explorer/Cursor tabs on vast_upload\staging_v12, then retry."
}

$mb = [math]::Round((Get-Item $OutZip).Length / 1MB, 1)
Write-Host ("Created {0} ({1} MB)" -f $OutZip, $mb) -ForegroundColor Green
Write-Host ""
Write-Host "Vast:" -ForegroundColor Yellow
Write-Host "  1. Upload pine_v12_train_bundle.zip"
Write-Host "  2. unzip -q pine_v12_train_bundle.zip -d pine"
Write-Host "  3. cd pine && bash scripts/vast_train_v12.sh"
Write-Host "  4. Download runs/retrain/mealybug_v12/weights/best.pt"
