# Build a small v19 retry bundle (v16 starter weights + configs). Dataset stays on Vast (use existing zip).
# Usage: .\scripts\v19_retry_bundle.ps1

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
$Staging = Join-Path $Root "vast_upload\staging_v19_retry"
$Zip = Join-Path $Root "vast_upload\v19_retry_bundle.zip"

$v16 = Join-Path $Root "runs\retrain\mealybug_v16_selffix\weights\best.pt"
if (-not (Test-Path $v16)) { throw "Missing v16 weights: $v16" }

if (Test-Path $Staging) { Remove-Item $Staging -Recurse -Force }
New-Item -ItemType Directory -Force -Path "$Staging\runs\retrain\mealybug_v16_selffix\weights" | Out-Null
New-Item -ItemType Directory -Force -Path "$Staging\scripts" | Out-Null

Copy-Item $v16 "$Staging\runs\retrain\mealybug_v16_selffix\weights\best.pt" -Force
Copy-Item (Join-Path $Root "vast_download\config\data_v15.yaml") "$Staging\data_v15.yaml" -Force
Copy-Item (Join-Path $Root "scripts\requirements-train.txt") "$Staging\scripts\" -Force
Copy-Item (Join-Path $Root "scripts\fix_test_labels.py") "$Staging\scripts\" -Force

# Vast path inside yaml
(Get-Content "$Staging\data_v15.yaml") -replace 'path:.*', 'path: /workspace/pine/datasets/mealybug_v13afix' | Set-Content "$Staging\data_v15.yaml"

if (Test-Path $Zip) { Remove-Item $Zip -Force }
Compress-Archive -Path "$Staging\*" -DestinationPath $Zip -CompressionLevel Optimal
$mb = [math]::Round((Get-Item $Zip).Length / 1MB, 1)
Write-Host "Ready: $Zip ($mb MB)"
