# Field-only Va bundle (~2.5 GB dataset + v11 weights)
#
# Usage:
#   .\scripts\package_va_field_for_vast.ps1
# Upload vast_upload\pine_va_field_bundle.zip

param(
    [string]$OutZip = "d:\old_PINE\vast_upload\pine_va_field_bundle.zip",
    [string]$DatasetDir = "datasets\mealybug_va_field"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root

if (-not (Test-Path $DatasetDir)) {
    Write-Host "Building field dataset..." -ForegroundColor Cyan
    python (Join-Path $Root "scripts\build_va_field_dataset.py")
}
if (-not (Test-Path $DatasetDir)) {
    throw "Missing $DatasetDir"
}
$v11pt = "runs\retrain\mealybug_v11\weights\best.pt"
if (-not (Test-Path $v11pt)) {
    throw "Missing $v11pt"
}

$staging = Join-Path $Root "vast_upload\staging_va_field"
$outDir = Split-Path $OutZip -Parent

if (Test-Path $staging) { Remove-Item $staging -Recurse -Force -ErrorAction SilentlyContinue }
if (Test-Path $OutZip) { Remove-Item $OutZip -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $staging -Force | Out-Null
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

$destDs = Join-Path $staging $DatasetDir
New-Item -ItemType Directory -Path (Split-Path $destDs -Parent) -Force | Out-Null
robocopy $DatasetDir $destDs /E /XD .git __pycache__ /XF *.cache *.bak /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed" }

$items = @(
    "configs\train_va.yaml",
    "scripts\retrain_yolo.py",
    "scripts\vast_train_va.sh",
    "scripts\eval_va_field.py",
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

Write-Host "Zipping Va field bundle..." -ForegroundColor Cyan
python (Join-Path $Root "scripts\zip_staging_bundle.py") --staging $staging --out $OutZip
if ($LASTEXITCODE -ne 0) { throw "zip failed" }

$mb = [math]::Round((Get-Item $OutZip).Length / 1MB, 1)
Write-Host ("Created {0} ({1} MB)" -f $OutZip, $mb) -ForegroundColor Green
Write-Host "Vast: unzip -d pine; cd pine; bash scripts/vast_train_va.sh"
