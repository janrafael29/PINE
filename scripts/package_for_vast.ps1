# Zip datasets + checkpoint + scripts for Vast.ai upload
param(
    [string]$OutZip = "d:\old_PINE\vast_upload\pine_train_bundle.zip"
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot\..

$staging = "vast_upload\staging"
if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
New-Item -ItemType Directory -Path $staging -Force | Out-Null

# Copy tree (exclude huge caches)
$items = @(
    "datasets",
    "scripts\retrain_yolo.py",
    "scripts\vast_train.sh",
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

# Strip label caches if present
Get-ChildItem $staging -Recurse -Filter "*.cache" -ErrorAction SilentlyContinue | Remove-Item -Force

$outDir = Split-Path $OutZip -Parent
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
if (Test-Path $OutZip) { Remove-Item $OutZip -Force }
Compress-Archive -Path "$staging\*" -DestinationPath $OutZip -CompressionLevel Optimal

$mb = [math]::Round((Get-Item $OutZip).Length / 1MB, 1)
Write-Host "Created $OutZip ($mb MB)"
Write-Host "Upload to Vast, unzip, then: bash scripts/vast_train.sh"
