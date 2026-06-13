# Slim PINYA-PIC disk use while keeping model-comparison + paper artifacts.
#
# Safe by default (-WhatIf). Phases:
#   Checkpoints  — keep best.pt (+ optional last.pt), results.csv, args.yaml, plots; drop epoch*.pt
#   Staging      — vast_upload/, roboflow_upload/, datasets.bak.*, root *.zip, build/
#   Datasets     — move superseded dataset trees to an archive folder (not delete)
#
# Examples:
#   .\scripts\slim_project_retention.ps1 -Phase Checkpoints -WhatIf
#   .\scripts\slim_project_retention.ps1 -Phase Checkpoints
#   .\scripts\slim_project_retention.ps1 -Phase Staging -WhatIf
#   .\scripts\slim_project_retention.ps1 -Phase Datasets -ArchiveRoot D:\PINE_ML_ARCHIVE -WhatIf

param(
    [ValidateSet('Checkpoints', 'Staging', 'Datasets', 'All')]
    [string]$Phase = 'Checkpoints',
    [switch]$WhatIf,
    [switch]$KeepLastPt,
    [string]$ArchiveRoot = ''
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent

# Versions referenced in thesis / compare scripts — keep best.pt + run metadata.
$KeepRuns = @(
    'mealybug_v2', 'mealybug_fix500', 'mealybug_v10', 'mealybug_v10a', 'mealybug_v11', 'mealybug_v12',
    'mealybug_va', 'mealybug_v13afix', 'mealybug_v15_full', 'mealybug_v15_fixed',
    'mealybug_v16_selffix', 'mealybug_v17_sam', 'mealybug_v17_sam-2', 'mealybug_v18_nosam', 'mealybug_v19_retry'
)

# Active training + panel eval (do not archive).
$KeepDatasets = @(
    'mealybug_v13afix'   # canonical train + corrected test (1,952 imgs)
)

# Legacy fair benchmark + field-only test (compare_all_retrains.py).
$KeepDatasets += @(
    'mealybug.v10-8th-yolo26n.yolo26'  # lives at repo root, not under datasets/
    'mealybug_va_field'
)

# Superseded after v13afix build — safe to move off-disk if v13afix exists.
$ArchiveDatasets = @(
    'mealybug_v10_plus_annotations',
    'mealybug_merged_all_annotations',
    'mealybug_merged_annotations'
)

function Format-GB([long]$bytes) {
    return '{0:N2} GB' -f ($bytes / 1GB)
}

function Remove-Safe([string]$Path) {
    if (-not (Test-Path $Path)) { return 0 }
    $size = (Get-ChildItem $Path -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    if ($WhatIf) {
        Write-Host "[WhatIf] Remove $Path ($(Format-GB $size))"
    }
    else {
        Write-Host "Remove $Path ($(Format-GB $size))"
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
    return $size
}

function Prune-Checkpoints {
    $freed = 0L
    $retrain = Join-Path $Root 'runs\retrain'
    if (-not (Test-Path $retrain)) { return }

    foreach ($runDir in Get-ChildItem $retrain -Directory) {
        $weights = Join-Path $runDir.FullName 'weights'
        if (-not (Test-Path $weights)) { continue }

        $keepNames = @('best.pt')
        if ($KeepLastPt) { $keepNames += 'last.pt' }

        foreach ($pt in Get-ChildItem $weights -Filter '*.pt' -File) {
            if ($keepNames -contains $pt.Name) { continue }
            $freed += $pt.Length
            if ($WhatIf) {
                Write-Host "[WhatIf] $($pt.FullName) ($(Format-GB $pt.Length))"
            }
            else {
                Write-Host "Delete $($pt.FullName)"
                Remove-Item -LiteralPath $pt.FullName -Force
            }
        }
    }
    Write-Host "Checkpoint phase: $(Format-GB $freed) reclaimable"
}

function Remove-Staging {
    $freed = 0L
    $paths = @(
        (Join-Path $Root 'vast_upload'),
        (Join-Path $Root 'roboflow_upload'),
        (Join-Path $Root 'build'),
        (Join-Path $Root 'annotation_new\all_mealybug_annotations.zip')
    )
    foreach ($p in $paths) { $freed += Remove-Safe $p }

    Get-ChildItem $Root -Filter 'datasets.bak.*' -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $freed += Remove-Safe $_.FullName
    }
    Get-ChildItem $Root -Filter '*.zip' -File -ErrorAction SilentlyContinue | ForEach-Object {
        $freed += Remove-Safe $_.FullName
    }
    Write-Host "Staging phase: $(Format-GB $freed) reclaimable"
}

function Archive-Datasets {
    if (-not $ArchiveRoot) {
        throw 'Pass -ArchiveRoot (e.g. D:\PINE_ML_ARCHIVE) for Dataset phase.'
    }
    if (-not (Test-Path $ArchiveRoot)) {
        if ($WhatIf) { Write-Host "[WhatIf] mkdir $ArchiveRoot" }
        else { New-Item -ItemType Directory -Path $ArchiveRoot -Force | Out-Null }
    }

    $v13 = Join-Path $Root 'datasets\mealybug_v13afix'
    if (-not (Test-Path $v13)) {
        throw "Refusing to archive superseded datasets: missing $v13"
    }

    $freed = 0L
    foreach ($name in $ArchiveDatasets) {
        $src = Join-Path $Root "datasets\$name"
        if (-not (Test-Path $src)) { continue }
        $size = (Get-ChildItem $src -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
        $dest = Join-Path $ArchiveRoot $name
        if ($WhatIf) {
            Write-Host "[WhatIf] Move $src -> $dest ($(Format-GB $size))"
        }
        else {
            Write-Host "Move $src -> $dest"
            Move-Item -LiteralPath $src -Destination $dest
        }
        $freed += $size
    }
    Write-Host "Dataset archive phase: $(Format-GB $freed) off project disk"
}

Write-Host "PINYA-PIC retention slim | Phase=$Phase | WhatIf=$WhatIf"
Write-Host "Keep runs: $($KeepRuns -join ', ')"
Write-Host "Keep datasets: $($KeepDatasets -join ', ')"
Write-Host ""

switch ($Phase) {
    'Checkpoints' { Prune-Checkpoints }
    'Staging'     { Remove-Staging }
    'Datasets'    { Archive-Datasets }
    'All'         {
        Prune-Checkpoints
        Remove-Staging
        Archive-Datasets
    }
}

Write-Host ''
Write-Host 'Paper/comparison artifacts preserved:'
Write-Host '  runs/retrain/*/weights/best.pt, results.csv, args.yaml'
Write-Host '  runs/calibration/*.json, *.csv'
Write-Host '  docs/thesis/assets/'
Write-Host '  datasets/mealybug_v13afix/test/labels_v16_corrected'
