# Download critical Vast.ai artifacts to local (weights, metrics, configs, label snapshots).
# Usage: .\scripts\download_from_vast.ps1
# Requires: ssh/scp, Vast instance at 211.72.13.201:42557

$Host_ = "root@211.72.13.201"
$Port = 42557
$Root = "D:\old_PINE"
$Remote = "/workspace"

function Scp-Get {
    param(
        [string]$RemotePath,
        [string]$LocalPath,
        [switch]$Optional
    )
    $parent = Split-Path -Parent $LocalPath
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    $errPrev = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"
    & scp -P $Port "${Host_}:${RemotePath}" $LocalPath 2>$null
    $ok = $LASTEXITCODE -eq 0
    $ErrorActionPreference = $errPrev
    if ($ok) {
        Write-Host "  OK $LocalPath"
    } elseif (-not $Optional) {
        throw "scp failed: $RemotePath"
    } else {
        Write-Host "  skip (missing) $RemotePath"
    }
}

function Scp-GetDir {
    param([string]$RemotePath, [string]$LocalPath)
    if (-not (Test-Path $LocalPath)) {
        New-Item -ItemType Directory -Force -Path $LocalPath | Out-Null
    }
    $errPrev = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"
    & scp -P $Port -r "${Host_}:${RemotePath}" $LocalPath 2>$null
    $ok = $LASTEXITCODE -eq 0
    $ErrorActionPreference = $errPrev
    if (-not $ok) { throw "scp failed: $RemotePath" }
    Write-Host "  OK $LocalPath (dir)"
}

function Download-Run {
    param([string]$RunName)
    $remoteRun = "$Remote/runs/train/$RunName"
    $localRun = Join-Path $Root "runs\retrain\$RunName"
    New-Item -ItemType Directory -Force -Path (Join-Path $localRun "weights") | Out-Null

    Write-Host "`n=== $RunName ===" -ForegroundColor Cyan
    foreach ($f in @("results.csv", "args.yaml", "results.png", "confusion_matrix.png", "confusion_matrix_normalized.png", "labels.jpg")) {
        Scp-Get "$remoteRun/$f" (Join-Path $localRun $f) -Optional
    }
    foreach ($f in @("BoxF1_curve.png", "BoxPR_curve.png", "BoxP_curve.png", "BoxR_curve.png")) {
        Scp-Get "$remoteRun/$f" (Join-Path $localRun $f) -Optional
    }
    foreach ($w in @("best.pt", "last.pt")) {
        Scp-Get "$remoteRun/weights/$w" (Join-Path $localRun "weights\$w") -Optional
    }
}

Write-Host "Vast download -> $Root" -ForegroundColor Green

# --- Training runs ---
$runs = @(
    "mealybug_v15_fixed",
    "mealybug_v15_full",
    "mealybug_v16_selffix",
    "mealybug_v17_sam",
    "mealybug_v17_sam-2",
    "mealybug_v18_nosam"
)
foreach ($r in $runs) { Download-Run $r }

# --- v13 checkpoint (standalone on Vast) ---
Write-Host "`n=== v13afix_best.pt ===" -ForegroundColor Cyan
Scp-Get "$Remote/v13afix_best.pt" (Join-Path $Root "runs\retrain\mealybug_v13afix\weights\best.pt")

# --- Data YAMLs ---
Write-Host "`n=== configs ===" -ForegroundColor Cyan
$configDir = Join-Path $Root "vast_download\config"
New-Item -ItemType Directory -Force -Path $configDir | Out-Null
foreach ($y in @("data.yaml", "data_fixed.yaml", "data_v15.yaml")) {
    Scp-Get "$Remote/$y" (Join-Path $configDir $y)
}

# --- Workspace scripts (Vast copies) ---
Write-Host "`n=== scripts ===" -ForegroundColor Cyan
$scriptDir = Join-Path $Root "vast_download\scripts"
New-Item -ItemType Directory -Force -Path $scriptDir | Out-Null
foreach ($s in @("fix_annotations_with_dino.py", "audit_with_grounding_dino.py", "sam_tighten_boxes.py")) {
    Scp-Get "$Remote/$s" (Join-Path $scriptDir $s)
}

# --- Label snapshots (no images; ~250 MB) ---
Write-Host "`n=== label snapshots ===" -ForegroundColor Cyan
$labelRoot = Join-Path $Root "vast_download\labels_snapshots\mealybug_v13afix"
$ds = "$Remote/datasets/mealybug_v13afix"
Scp-GetDir "$ds/train/labels" (Join-Path $labelRoot "train\labels")
Scp-GetDir "$ds/test/labels" (Join-Path $labelRoot "test\labels")
Scp-GetDir "$ds/test/labels_pre_dino" (Join-Path $labelRoot "test\labels_pre_dino")
Scp-GetDir "$ds/test/labels_backup" (Join-Path $labelRoot "test\labels_backup")

Write-Host "`nDone. See vast_download\MANIFEST.md" -ForegroundColor Green
