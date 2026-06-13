# Upload full mealybug_v13afix train set for Wave 1-3 on Vast (~8 GB).
# Usage: .\scripts\package_train_for_vast.ps1

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
$Src = Join-Path $Root "datasets\mealybug_v13afix"
$Zip = Join-Path $Root "vast_upload\pine_v13afix_train_bundle.zip"

if (-not (Test-Path (Join-Path $Src "train\images"))) {
    throw "Missing $Src\train\images - build dataset first."
}

if (Test-Path $Zip) { Remove-Item $Zip -Force }
Write-Host "Zipping mealybug_v13afix (train+val+test) — this takes several minutes..."
Compress-Archive -Path $Src -DestinationPath $Zip -CompressionLevel Fastest
$mb = [math]::Round((Get-Item $Zip).Length / 1MB, 1)
Write-Host "Ready: $Zip ($mb MB)"
Write-Host "scp -i `$env:USERPROFILE\.ssh\vast_ed25519 -P 40050 $Zip root@219.86.90.208:/workspace/"
