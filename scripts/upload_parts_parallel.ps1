# Upload split parts to Vast in parallel scp streams (resumable: re-run skips done parts).
# Usage: .\scripts\upload_parts_parallel.ps1 [-Streams 5]
param(
    [int]$Streams = 5,
    [string]$PartsDir = "D:\old_PINE\vast_upload\pine_v13afix_train_bundle_parts",
    [string]$RemoteDir = "/workspace/upload_parts",
    [string]$SshHost = "root@219.86.90.208",
    [int]$Port = 40050
)

$ErrorActionPreference = "Continue"
$key = "$env:USERPROFILE\.ssh\vast_ed25519"
# Keepalives kill hung connections instead of waiting forever (this instance's sshd is flaky)
$sshOpts = @("-o", "ConnectTimeout=20", "-o", "ServerAliveInterval=10", "-o", "ServerAliveCountMax=3", "-o", "BatchMode=yes")

Write-Host "Creating remote dir..."
ssh -i $key -p $Port @sshOpts -n $SshHost "mkdir -p $RemoteDir"

Write-Host "Listing remote parts..."
$remoteList = ssh -i $key -p $Port @sshOpts -n $SshHost "ls -l $RemoteDir 2>/dev/null" | Out-String
$remoteSizes = @{}
foreach ($line in $remoteList -split "`n") {
    $cols = ($line -split '\s+') | Where-Object { $_ }
    if ($cols.Count -ge 9 -and $cols[-1] -like "*.part*") { $remoteSizes[$cols[-1]] = [long]$cols[4] }
}

$parts = Get-ChildItem $PartsDir -Filter "*.part*" | Sort-Object Name
$todo = @($parts | Where-Object { $remoteSizes[$_.Name] -ne $_.Length })
Write-Host "Parts: $($parts.Count) total, $($todo.Count) to upload, $Streams parallel streams"
if ($todo.Count -eq 0) { Write-Host "Nothing to do."; exit 0 }

$queue = [System.Collections.Queue]::new()
$todo | ForEach-Object { $queue.Enqueue($_.FullName) }
$jobs = @()

while ($queue.Count -gt 0 -or @($jobs | Where-Object State -eq 'Running').Count -gt 0) {
    # Collect finished jobs; re-queue failures
    foreach ($j in @($jobs | Where-Object State -ne 'Running')) {
        $code = Receive-Job $j -ErrorAction SilentlyContinue | Select-Object -Last 1
        if ($code -ne 0) {
            Write-Host ("[{0}] RETRY {1} (exit {2})" -f (Get-Date -Format HH:mm:ss), $j.Name, $code) -ForegroundColor Yellow
            $queue.Enqueue($j.Name)
        } else {
            Write-Host ("[{0}] done  {1}" -f (Get-Date -Format HH:mm:ss), (Split-Path $j.Name -Leaf)) -ForegroundColor Green
        }
        Remove-Job $j -Force
    }
    $jobs = @($jobs | Where-Object State -eq 'Running')

    while (@($jobs).Count -lt $Streams -and $queue.Count -gt 0) {
        $file = $queue.Dequeue()
        $name = Split-Path $file -Leaf
        Write-Host ("[{0}] start {1}" -f (Get-Date -Format HH:mm:ss), $name)
        $jobs += Start-Job -Name $file -ScriptBlock {
            param($k, $p, $f, $h, $r)
            scp -i $k -P $p -o ConnectTimeout=20 -o ServerAliveInterval=10 -o ServerAliveCountMax=3 -o BatchMode=yes $f "${h}:${r}/" 2>&1 | Out-Null
            $LASTEXITCODE
        } -ArgumentList $key, $Port, $file, $SshHost, $RemoteDir
    }
    Start-Sleep -Seconds 15
    Write-Host ("[{0}] running={1} queued={2}" -f (Get-Date -Format HH:mm:ss), @($jobs | Where-Object State -eq 'Running').Count, $queue.Count)
}

Write-Host ""
Write-Host "All parts uploaded. Re-run this script once more to verify sizes (it should say 'Nothing to do')."
Write-Host "Then on the server (SSH):"
Write-Host "  cat $RemoteDir/pine_v13afix_train_bundle.zip.part* > /workspace/pine_v13afix_train_bundle.zip"
Write-Host "  md5sum /workspace/pine_v13afix_train_bundle.zip"
