# Build 500-image CVAT fix set (worst val/test + optional field folder)
param(
    [int]$Count = 500,
    [string]$FieldDir = "",
    [int]$FieldMax = 0,
    [double]$Conf = 0.15,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot\..

$py = ".\.venv\Scripts\python.exe"
if (-not (Test-Path $py)) { $py = "python" }

$argsList = @("scripts\build_fix_set.py", "--n", $Count, "--conf", $Conf)
if ($FieldDir -ne "") {
    $argsList += @("--field-dir", $FieldDir)
    if ($FieldMax -gt 0) { $argsList += @("--field-max", $FieldMax) }
}
if ($DryRun) { $argsList += "--dry-run" }

& $py @argsList
