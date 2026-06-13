# PINYA-PIC — Fast panel video assembly (after you record clips)
# Prerequisite: install ffmpeg — winget install Gyan.FFmpeg
# Usage:
#   1. Record: panel_video_slides.html (browser) + phone screen clips
#   2. Put clips in: d:\old_PINE\docs\thesis\panel_clips\
#   3. Run: .\scripts\record_panel_video_guide.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path (Join-Path $root "docs"))) { $root = "d:\old_PINE" }

$clipsDir = Join-Path $root "docs\thesis\panel_clips"
$outDir = Join-Path $root "docs\thesis"
$outFile = Join-Path $outDir "PINYA-PIC_panel_update_May2026.mp4"

if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Host "ffmpeg not found. Install: winget install Gyan.FFmpeg"
    Write-Host "Or record everything in one take with OBS (slides + phone)."
    exit 1
}

New-Item -ItemType Directory -Force -Path $clipsDir | Out-Null

$expected = @(
    "01_slides.mp4",
    "02_app_dense.mp4",
    "03_app_sparse.mp4",
    "04_app_clean.mp4",
    "05_app_field.mp4"
)

$missing = $expected | Where-Object { -not (Test-Path (Join-Path $clipsDir $_)) }
if ($missing.Count -gt 0) {
    Write-Host "Missing clips in $clipsDir :"
    $missing | ForEach-Object { Write-Host "  - $_" }
    Write-Host ""
    Write-Host "Fastest path: ONE OBS recording — browser slides then phone demo."
    Write-Host "Script: docs\thesis\PANEL_UPDATE_VIDEO_SCRIPT.md"
    exit 0
}

$listFile = Join-Path $env:TEMP "pine_panel_concat.txt"
Remove-Item $listFile -ErrorAction SilentlyContinue
foreach ($name in $expected) {
    $path = (Join-Path $clipsDir $name) -replace '\\', '/'
    Add-Content $listFile "file '$path'"
}

ffmpeg -y -f concat -safe 0 -i $listFile -c copy $outFile
Write-Host "Done: $outFile"
