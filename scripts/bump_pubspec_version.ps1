param(
    [string]$PubspecPath = "pubspec.yaml",
    [switch]$Minor,
    [switch]$Major
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $PubspecPath)) {
    throw "pubspec.yaml not found at: $PubspecPath"
}

$content = Get-Content -Path $PubspecPath -Raw
# major.minor.micro+build — visible version is the three-part semver; +build is Android versionCode (must only increase).
$match = [regex]::Match($content, '(?m)^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$')
if (-not $match.Success) {
    throw "Could not parse pubspec version. Use: version: major.minor.micro+build  (e.g. 6.0.0+2020). The app shows only major.minor.micro; +build is for the store."
}

$majorNum = [int]$match.Groups[1].Value
$minorNum = [int]$match.Groups[2].Value
$patchNum = [int]$match.Groups[3].Value
$buildNum = [int]$match.Groups[4].Value + 1

if ($Major) {
    $majorNum += 1
    $minorNum = 0
    $patchNum = 0
}
elseif ($Minor) {
    $minorNum += 1
    $patchNum = 0
}
else {
    $patchNum += 1
}

$newVersion = "$majorNum.$minorNum.$patchNum+$buildNum"
$updated = [regex]::Replace($content, '(?m)^version:\s*\d+\.\d+\.\d+\+\d+\s*$', "version: $newVersion", 1)
Set-Content -Path $PubspecPath -Value $updated -NoNewline

Write-Host "Updated pubspec to $newVersion"
Write-Host "  App / About will show: $majorNum.$minorNum.$patchNum (major.minor.micro)"
Write-Host "  Android versionCode: $buildNum"
