# Download v19 run artifacts immediately after training. Update IP/port from Vast SSH button.
param(
    [string]$Ip = "108.255.76.60",
    [int]$Port = 53424,
    [string]$RunName = "mealybug_v19_ft_from_v16_ddp"
)

$ErrorActionPreference = "Stop"
$Key = "$env:USERPROFILE\.ssh\vast_ed25519"
$Root = Split-Path $PSScriptRoot -Parent
$Local = Join-Path $Root "runs\retrain\$RunName"
$Remote = "/workspace/pine/runs/train/$RunName"

New-Item -ItemType Directory -Force -Path $Local | Out-Null
& scp -i $Key -P $Port -r "${Ip}:/workspace/pine/runs/train/$RunName/*" $Local
Write-Host "Downloaded to $Local"
Get-ChildItem (Join-Path $Local "weights") -ErrorAction SilentlyContinue | Select-Object Name, Length
