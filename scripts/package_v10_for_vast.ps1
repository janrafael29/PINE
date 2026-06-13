# Zip full v10 dataset (~17.5k) + scripts + v2 checkpoint for Vast.ai
# WARNING: ~2 GB on disk; zip ~1.5-2 GB; upload may take 20-60 min.
#
# Usage:
#   .\scripts\package_v10_for_vast.ps1
#   Upload vast_upload\pine_v10_train_bundle.zip to Vast, unzip, then:
#   bash scripts/vast_train_v10.sh

param(
    [string]$OutZip = "d:\old_PINE\vast_upload\pine_v10_train_bundle.zip",
    [string]$V10Dir = "mealybug.v10-8th-yolo26n.yolo26"
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

if (-not (Test-Path $V10Dir)) {
    throw "Missing $V10Dir - download/extract Roboflow v10 YOLO export first."
}

$staging = "vast_upload\staging_v10"
if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
New-Item -ItemType Directory -Path $staging -Force | Out-Null

# Fixed data.yaml is already in repo (train/images not ../train/images)
$items = @(
    $V10Dir,
    "scripts\retrain_yolo.py",
    "scripts\vast_train_v10.sh",
    "scripts\requirements-train.txt",
    "runs\retrain\mealybug_v2\weights\best.pt"
)
foreach ($rel in $items) {
    $src = Join-Path (Get-Location) $rel
    if (-not (Test-Path $src)) {
        Write-Warning "Skip missing: $rel"
        continue
    }
    $dest = Join-Path $staging $rel
    $parent = Split-Path $dest -Parent
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    if ((Get-Item $src).PSIsContainer) {
        Copy-Item $src $dest -Recurse -Force
    } else {
        Copy-Item $src $dest -Force
    }
}

Get-ChildItem $staging -Recurse -Filter "*.cache" -ErrorAction SilentlyContinue | Remove-Item -Force

$outDir = Split-Path $OutZip -Parent
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
if (Test-Path $OutZip) { Remove-Item $OutZip -Force }

Write-Host "Zipping v10 dataset (this may take several minutes)..." -ForegroundColor Cyan
Compress-Archive -Path "$staging\*" -DestinationPath $OutZip -CompressionLevel Optimal

$mb = [math]::Round((Get-Item $OutZip).Length / 1MB, 1)
Write-Host "Created $OutZip ($mb MB)" -ForegroundColor Green
Write-Host ""
Write-Host "Vast steps:" -ForegroundColor Yellow
Write-Host "  1. Upload zip to instance"
Write-Host "  2. unzip -q pine_v10_train_bundle.zip -d pine"
Write-Host "  3. cd pine; bash scripts/vast_train_v10.sh"
Write-Host "  4. scp best.pt back, export TFLite on PC"
Write-Host ""
Write-Host "Expect ~2-5 h train on RTX 5090 (16k train, 100 epochs, early stop likely)."
