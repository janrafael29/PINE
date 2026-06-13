# Package v13afix dataset + v12 weights for Vast
param(
    [string]$OutZip = "d:\old_PINE\vast_upload\pine_v13afix_train_bundle.zip"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root

python (Join-Path $Root "scripts\build_v13afix_dataset.py") --augment-field --fix-corrupt --split 0.7 0.2 0.1
foreach ($f in @("datasets\mealybug_v13afix", "runs\retrain\mealybug_v12\weights\best.pt")) {
    if (-not (Test-Path $f)) { throw "Missing $f" }
}

$staging = Join-Path $Root "vast_upload\staging_v13afix"
if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
if (Test-Path $OutZip) { Remove-Item $OutZip -Force }
New-Item -ItemType Directory -Path $staging -Force | Out-Null

robocopy datasets\mealybug_v13afix (Join-Path $staging "datasets\mealybug_v13afix") /E /XD .git /XF *.cache /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed" }

@(
    "configs\train_v13afix.yaml",
    "scripts\retrain_yolo.py",
    "scripts\vast_train_v13afix.sh",
    "scripts\requirements-train.txt",
    "runs\retrain\mealybug_v12\weights\best.pt"
) | ForEach-Object {
    $dest = Join-Path $staging $_
    New-Item -ItemType Directory -Path (Split-Path $dest -Parent) -Force | Out-Null
    Copy-Item $_ $dest -Force
}

python (Join-Path $Root "scripts\zip_staging_bundle.py") --staging $staging --out $OutZip
$mb = [math]::Round((Get-Item $OutZip).Length / 1MB, 1)
Write-Host "Created $OutZip ($mb MB)"
Write-Host "Vast: unzip -d pine; cd pine; bash scripts/vast_train_v13afix.sh"
