# Zip cleaned v10 dataset + v10 best.pt for Vast v11 fine-tune
#
# Usage:
#   .\scripts\package_v11_for_vast.ps1
# Upload vast_upload\pine_v11_train_bundle.zip, unzip, then:
#   bash scripts/vast_train_v11.sh

param(
    [string]$OutZip = "d:\old_PINE\vast_upload\pine_v11_train_bundle.zip",
    [string]$V10Dir = "mealybug.v10-8th-yolo26n.yolo26"
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

if (-not (Test-Path $V10Dir)) {
    throw "Missing $V10Dir"
}
$v10pt = "runs\retrain\mealybug_v10\weights\best.pt"
if (-not (Test-Path $v10pt)) {
    throw "Missing $v10pt - train or download mealybug_v10 first."
}

$staging = "vast_upload\staging_v11"
if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
New-Item -ItemType Directory -Path $staging -Force | Out-Null

# Copy dataset (exclude label backups to save space)
$destDs = Join-Path $staging $V10Dir
New-Item -ItemType Directory -Path $destDs -Force | Out-Null
robocopy $V10Dir $destDs /E /XD .git /XF *.cache *.txt.bak /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed: $LASTEXITCODE" }

$items = @(
    "scripts\retrain_yolo.py",
    "scripts\vast_train_v11.sh",
    "scripts\requirements-train.txt",
    $v10pt
)
foreach ($rel in $items) {
    $src = Join-Path (Get-Location) $rel
    $dest = Join-Path $staging $rel
    $parent = Split-Path $dest -Parent
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    Copy-Item $src $dest -Force
}

$outDir = Split-Path $OutZip -Parent
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
if (Test-Path $OutZip) { Remove-Item $OutZip -Force }

Write-Host "Zipping v11 bundle (cleaned labels, no .bak)..." -ForegroundColor Cyan
Compress-Archive -Path "$staging\*" -DestinationPath $OutZip -CompressionLevel Optimal

$mb = [math]::Round((Get-Item $OutZip).Length / 1MB, 1)
Write-Host ("Created {0} ({1} MB)" -f $OutZip, $mb) -ForegroundColor Green
Write-Host ""
Write-Host "Vast:" -ForegroundColor Yellow
Write-Host "  1. Upload pine_v11_train_bundle.zip"
Write-Host "  2. unzip -q pine_v11_train_bundle.zip -d pine"
Write-Host "  3. cd pine && bash scripts/vast_train_v11.sh"
Write-Host "  4. Download runs/retrain/mealybug_v11/weights/best.pt"
Write-Host ""
Write-Host "Expect ~1-3 h on RTX 5090 (50 epochs, early stop ~15 patience)."
