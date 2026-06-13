# Download all H100 training artifacts to runs/h100_backup/ and sync eval JSONs to docs/.
# Excludes full datasets (multi-GB); includes weights, logs, consensus, eval metrics.
param(
    [string]$VastHost = "219.86.90.208",
    [int]$Port = 40050,
    [string]$Key = "$env:USERPROFILE\.ssh\vast_ed25519",
    [string]$RemoteRoot = "/workspace/pine",
    [string]$LocalBackup = "D:\old_PINE\runs\h100_backup",
    [string]$Date = (Get-Date -Format "yyyy-MM-dd")
)

$ErrorActionPreference = "Stop"
$TarName = "h100_artifacts_$Date.tar.gz"
$RemoteTar = "/tmp/$TarName"
$Ssh = @("-i", $Key, "-p", $Port, "-o", "ConnectTimeout=30", "-n", "root@${VastHost}")
$Scp = @("-i", $Key, "-P", $Port, "-o", "ConnectTimeout=30")

New-Item -ItemType Directory -Force -Path $LocalBackup | Out-Null
New-Item -ItemType Directory -Force -Path "D:\old_PINE\docs\thesis\assets\v18_baseline" | Out-Null

Write-Host "=== Creating tarball on H100 ===" -ForegroundColor Cyan
$tarCmd = @"
cd $RemoteRoot && tar czf $RemoteTar \
  docs/thesis/assets/v18_baseline \
  runs/detect/runs/retrain \
  runs/retrain \
  runs/consensus \
  runs/v21_pipeline \
  runs/v18_pipeline \
  runs/audit \
  runs/calibration \
  runs/phase0.log runs/phase0_fix.log 2>/dev/null; \
ls -lh $RemoteTar
"@
ssh @Ssh $tarCmd

Write-Host "=== Downloading $TarName (~1-1.5 GB) ===" -ForegroundColor Cyan
scp @Scp "root@${VastHost}:$RemoteTar" "$LocalBackup\$TarName"

Write-Host "=== Extracting to $LocalBackup ===" -ForegroundColor Cyan
tar -xzf "$LocalBackup\$TarName" -C "$LocalBackup"

Write-Host "=== Syncing eval metrics to docs/thesis/assets/v18_baseline ===" -ForegroundColor Cyan
$src = "$LocalBackup\docs\thesis\assets\v18_baseline"
if (Test-Path $src) {
    Copy-Item -Path "$src\*" -Destination "D:\old_PINE\docs\thesis\assets\v18_baseline\" -Recurse -Force
}

Write-Host "=== Manifest ===" -ForegroundColor Green
Get-ChildItem $LocalBackup -Recurse -File | Group-Object Extension | Sort-Object Count -Descending | Select-Object -First 15 Name, Count
$total = (Get-ChildItem $LocalBackup -Recurse -File | Measure-Object -Property Length -Sum).Sum
Write-Host "Total backup size: $([math]::Round($total/1GB, 2)) GB under $LocalBackup"
Write-Host "Done. Tarball kept at: $LocalBackup\$TarName"
