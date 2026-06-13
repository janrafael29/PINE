# Roboflow Zip API upload for PINYA-PIC dataset
# Usage:
#   $env:ROBOFLOW_API_KEY = "your_key"
#   .\scripts\roboflow_upload_zip.ps1 -Phase Prepare
#   .\scripts\roboflow_upload_zip.ps1 -Phase Upload
#   .\scripts\roboflow_upload_zip.ps1 -Phase All

param(
    [ValidateSet("Prepare", "Upload", "All")]
    [string]$Phase = "All",
    [string]$DatasetRoot = "d:\old_PINE\mealybug.v10-8th-yolo26n.yolo26",
    [string]$UploadRoot = "d:\old_PINE\roboflow_upload",
    [string]$Workspace = "pine3",
    [string]$Project = "mealybug-detection",
    [string]$ApiKey = "",
    [switch]$SkipValid,
    [switch]$SkipTest,
    [string[]]$OnlyZips = @()
)

if ($ApiKey) { $env:ROBOFLOW_API_KEY = $ApiKey }

$ErrorActionPreference = "Stop"

function Ensure-Dir($path) {
    if (-not (Test-Path $path)) { New-Item -ItemType Directory -Force -Path $path | Out-Null }
}

function Copy-SplitImagesLabels {
    param(
        [string]$SrcImages,
        [string]$SrcLabels,
        [string]$DstImages,
        [string]$DstLabels,
        [int]$Skip = 0,
        [int]$Take = -1
    )
    Ensure-Dir $DstImages
    Ensure-Dir $DstLabels
    $files = Get-ChildItem $SrcImages -File | Sort-Object Name
    if ($Take -lt 0) { $Take = $files.Count - $Skip }
    $end = [Math]::Min($Skip + $Take - 1, $files.Count - 1)
    if ($end -lt $Skip) { return 0 }
    $slice = $files[$Skip..$end]
    $i = 0
    foreach ($img in $slice) {
        Copy-Item $img.FullName $DstImages -Force
        $lbl = Join-Path $SrcLabels ($img.BaseName + ".txt")
        if (Test-Path $lbl) { Copy-Item $lbl $DstLabels -Force }
        $i++
        if ($i % 2000 -eq 0) { Write-Host "  copied $i / $($slice.Count) ..." }
    }
    return $slice.Count
}

function New-DatasetZip {
    param([string]$StagingDir, [string]$ZipPath)
    if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
    $images = (Get-ChildItem (Join-Path $StagingDir "images") -File -ErrorAction SilentlyContinue).Count
    $labels = (Get-ChildItem (Join-Path $StagingDir "labels") -File -ErrorAction SilentlyContinue).Count
    if ($images -gt 10000) { throw "Too many files in $StagingDir ($images images); max 10000 per zip" }
    Write-Host "Zipping $StagingDir -> $ZipPath ($images images, $labels labels)"
    Compress-Archive -Path (Join-Path $StagingDir "*") -DestinationPath $ZipPath -CompressionLevel Optimal
    $sizeGb = (Get-Item $ZipPath).Length / 1GB
    Write-Host "  size: $([math]::Round($sizeGb, 2)) GB"
    if ($sizeGb -gt 2) { throw "Zip exceeds 2 GB: $ZipPath" }
}

function Invoke-RoboflowZipUpload {
    param(
        [string]$ZipPath,
        [string]$Split,
        [string]$BatchName
    )
    if (-not $env:ROBOFLOW_API_KEY) { throw "Set ROBOFLOW_API_KEY before Upload phase" }
    $body = @{ split = $Split; batchName = $BatchName } | ConvertTo-Json -Compress
    $key = [uri]::EscapeDataString($env:ROBOFLOW_API_KEY)
    $postUri = "https://api.roboflow.com/$Workspace/$Project/upload/zip?api_key=$key"
    Write-Host "POST $Split batch=$BatchName ..."
    $resp = Invoke-RestMethod -Method Post -Uri $postUri -ContentType "application/json" -Body $body
    $taskId = $resp.taskId
    $signedUrl = $resp.signedUrl
    if (-not $taskId -or -not $signedUrl) { throw "Unexpected POST response: $($resp | ConvertTo-Json -Depth 5)" }
    Write-Host "  taskId=$taskId - uploading zip ..."
    & curl.exe -sS -X PUT $signedUrl -H "Content-Type: application/zip" --upload-file $ZipPath
    if ($LASTEXITCODE -ne 0) { throw "curl PUT failed with exit $LASTEXITCODE" }
    Write-Host "  polling ..."
    $pollUri = "https://api.roboflow.com/$Workspace/upload/zip/$taskId?api_key=$key"
    do {
        Start-Sleep -Seconds 30
        $raw = (& curl.exe -sS --max-time 180 $pollUri 2>$null) -join ""
        if (-not $raw) { Write-Host "  poll empty, retrying..."; continue }
        $st = if ($raw -match '"status"\s*:\s*"([^"]+)"') { $Matches[1] } else { "unknown" }
        $cur = if ($raw -match '"current"\s*:\s*(\d+)') { $Matches[1] } else { "?" }
        $tot = if ($raw -match '"total"\s*:\s*(\d+)') { $Matches[1] } else { "?" }
        Write-Host "  status=$st progress=$cur/$tot"
        if ($st -eq "failed") { throw "Roboflow zip task failed: $taskId" }
    } while ($st -ne "completed")
    $uploaded = if ($raw -match '"uploaded"\s*:\s*(\d+)') { $Matches[1] } else { "?" }
    $failed = if ($raw -match '"failed"\s*:\s*(\d+)') { $Matches[1] } else { "0" }
    Write-Host "  done: uploaded=$uploaded failed=$failed"
    if ([int]$failed -gt 0) { Write-Warning "Some files failed - check Roboflow dashboard" }
    return $status
}

function Prepare-Zips {
    Write-Host "=== Prepare: staging + zips ==="
    $splits = @(
        @{ Name = "valid"; Src = "valid" },
        @{ Name = "test";  Src = "test" }
    )
    foreach ($s in $splits) {
        $stage = Join-Path $UploadRoot $s.Name
        $imgDst = Join-Path $stage "images"
        $lblDst = Join-Path $stage "labels"
        if ((Get-ChildItem $imgDst -File -ErrorAction SilentlyContinue).Count -eq 0) {
            Write-Host "Staging $($s.Name) ..."
            $n = Copy-SplitImagesLabels `
                -SrcImages (Join-Path $DatasetRoot "$($s.Src)\images") `
                -SrcLabels (Join-Path $DatasetRoot "$($s.Src)\labels") `
                -DstImages $imgDst -DstLabels $lblDst
            Write-Host "  $($s.Name): $n files"
        } else {
            Write-Host "Staging $($s.Name) already exists - skipping copy"
        }
        New-DatasetZip -StagingDir $stage -ZipPath (Join-Path $UploadRoot "$($s.Name).zip")
    }

    $trainImg = Join-Path $DatasetRoot "train\images"
    $trainLbl = Join-Path $DatasetRoot "train\labels"
    $trainCount = (Get-ChildItem $trainImg -File).Count
    $half = [int][math]::Ceiling($trainCount / 2)
    foreach ($part in @("train_part1", "train_part2")) {
        $stage = Join-Path $UploadRoot $part
        $imgDst = Join-Path $stage "images"
        if ((Get-ChildItem $imgDst -File -ErrorAction SilentlyContinue).Count -eq 0) {
            $skip = if ($part -eq "train_part1") { 0 } else { $half }
            $take = if ($part -eq "train_part1") { $half } else { $trainCount - $half }
            Write-Host "Staging $part (skip=$skip take=$take) ..."
            $n = Copy-SplitImagesLabels -SrcImages $trainImg -SrcLabels $trainLbl `
                -DstImages $imgDst -DstLabels (Join-Path $stage "labels") -Skip $skip -Take $take
            Write-Host "  $part : $n files"
        } else {
            Write-Host "Staging $part already exists - skipping copy"
        }
        New-DatasetZip -StagingDir $stage -ZipPath (Join-Path $UploadRoot "$part.zip")
    }
    Write-Host "=== Prepare done ==="
}

function Upload-AllZips {
    Write-Host "=== Upload to $Workspace/$Project ==="
    $jobs = @(
        @{ Zip = "valid.zip";       Split = "valid"; Batch = "upload-valid" },
        @{ Zip = "test.zip";        Split = "test";  Batch = "upload-test" },
        @{ Zip = "train_part1.zip"; Split = "train"; Batch = "train-part1" },
        @{ Zip = "train_part2.zip"; Split = "train"; Batch = "train-part2" }
    )
    if ($SkipValid) { $jobs = $jobs | Where-Object { $_.Zip -ne "valid.zip" } }
    if ($SkipTest) { $jobs = $jobs | Where-Object { $_.Zip -ne "test.zip" } }
    if ($OnlyZips.Count -gt 0) { $jobs = $jobs | Where-Object { $OnlyZips -contains $_.Zip } }
    foreach ($j in $jobs) {
        $zipPath = Join-Path $UploadRoot $j.Zip
        if (-not (Test-Path $zipPath)) { throw "Missing $zipPath - run Prepare first" }
        Invoke-RoboflowZipUpload -ZipPath $zipPath -Split $j.Split -BatchName $j.Batch
    }
    Write-Host "=== Upload done ==="
}

Ensure-Dir $UploadRoot
if ($Phase -eq "Prepare" -or $Phase -eq "All") { Prepare-Zips }
if ($Phase -eq "Upload" -or $Phase -eq "All") { Upload-AllZips }
