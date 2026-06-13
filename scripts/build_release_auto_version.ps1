<#
.SYNOPSIS
  Bump pubspec version, then flutter build with Supabase dart-defines.

.DESCRIPTION
  Version format in pubspec: major.minor.micro+build (e.g. 6.0.1+2021).
  The app / About screen shows only major.minor.micro. +build increases every run for Play Store.

  Bump mode (pick one):
    (default)  Micro (patch) +1 - bugfixes / small tweaks (same as -Micro)
    -Micro     Explicit micro bump (optional; same as default)
    -Minor     Minor +1, micro reset - features
    -Major     Major +1, minor/micro reset - breaking / big releases

  Supabase defines are passed via a temp JSON file and --dart-define-from-file
  (avoids Windows/Gradle truncating long JWT --dart-define lines).

  Quick runs without pasting secrets each time:
    Set once per PowerShell session (or in your profile):
      $env:PINYA_PIC_SUPABASE_URL = 'https://YOUR_PROJECT.supabase.co'
      $env:PINYA_PIC_SUPABASE_ANON_KEY = 'YOUR_ANON_JWT'
    Then:
      .\scripts\build_release_auto_version.ps1 -Target apk -SplitPerAbi -Clean

.EXAMPLE
  # Micro bump (default), one APK per ABI (smaller files), clean
  .\scripts\build_release_auto_version.ps1 `
    -SupabaseUrl 'https://xxx.supabase.co' `
    -SupabaseAnonKey 'eyJ...' `
    -Target apk -SplitPerAbi -Clean

.EXAMPLE
  # Explicit micro + split APKs
  .\scripts\build_release_auto_version.ps1 `
    -SupabaseUrl 'https://xxx.supabase.co' `
    -SupabaseAnonKey 'eyJ...' `
    -Target apk -SplitPerAbi -Micro -Clean

.EXAMPLE
  .\scripts\build_release_auto_version.ps1 `
    -SupabaseUrl 'https://xxx.supabase.co' `
    -SupabaseAnonKey 'eyJ...' `
    -Target apk -SplitPerAbi -Minor -Clean

.EXAMPLE
  .\scripts\build_release_auto_version.ps1 `
    -SupabaseUrl 'https://xxx.supabase.co' `
    -SupabaseAnonKey 'eyJ...' `
    -Target apk -SplitPerAbi -Major -Clean
#>
param(
    [Parameter(Mandatory = $false, HelpMessage = "Or set env PINYA_PIC_SUPABASE_URL")]
    [string]$SupabaseUrl = "",

    [Parameter(Mandatory = $false, HelpMessage = "Or set env PINYA_PIC_SUPABASE_ANON_KEY")]
    [string]$SupabaseAnonKey = "",

    [ValidateSet("apk", "aab")]
    [string]$Target = "apk",

    [switch]$SplitPerAbi,
    [switch]$Micro,
    [switch]$Minor,
    [switch]$Major,
    [switch]$Clean
)

$ErrorActionPreference = "Stop"

$modes = 0
if ($Micro) { $modes++ }
if ($Minor) { $modes++ }
if ($Major) { $modes++ }
if ($modes -gt 1) {
    throw "Use only one bump mode: -Micro, -Minor, or -Major (default is micro / patch)."
}

$url = $SupabaseUrl.Trim()
$key = $SupabaseAnonKey.Trim()
if ([string]::IsNullOrWhiteSpace($url)) {
    $url = $env:PINYA_PIC_SUPABASE_URL
}
if ([string]::IsNullOrWhiteSpace($key)) {
    $key = $env:PINYA_PIC_SUPABASE_ANON_KEY
}
if ([string]::IsNullOrWhiteSpace($url) -or [string]::IsNullOrWhiteSpace($key)) {
    throw @"
Missing Supabase credentials. Either pass parameters:
  -SupabaseUrl 'https://YOUR_PROJECT.supabase.co'
  -SupabaseAnonKey 'YOUR_ANON_JWT'
Or set environment variables for this session:
  `$env:PINYA_PIC_SUPABASE_URL = '...'
  `$env:PINYA_PIC_SUPABASE_ANON_KEY = '...'
Then rerun without those parameters.
"@
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
$definesPath = $null
try {
    if ($Clean) {
        flutter clean
    }

    if ($Major) {
        & "$PSScriptRoot\bump_pubspec_version.ps1" -PubspecPath "pubspec.yaml" -Major
    }
    elseif ($Minor) {
        & "$PSScriptRoot\bump_pubspec_version.ps1" -PubspecPath "pubspec.yaml" -Minor
    }
    else {
        & "$PSScriptRoot\bump_pubspec_version.ps1" -PubspecPath "pubspec.yaml"
    }

    $verLine = (Select-String -Path "pubspec.yaml" -Pattern '^version:\s*.+' | Select-Object -First 1).Line
    $visibleVer = if ($verLine -match '^version:\s*(\d+\.\d+\.\d+)') { $Matches[1] } else { "?" }

    flutter pub get

    $definesPath = Join-Path $env:TEMP "pine_supabase_defines_$([guid]::NewGuid().ToString('N')).json"
    $payload = [ordered]@{
        SUPABASE_URL      = $url
        SUPABASE_ANON_KEY = $key
    }
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    $definesJson = $payload | ConvertTo-Json -Compress
    [System.IO.File]::WriteAllText($definesPath, $definesJson, $utf8NoBom)
    $fromFileArg = "--dart-define-from-file=$definesPath"

    $symDir = Join-Path $repoRoot "build\app\symbols"
    New-Item -ItemType Directory -Force -Path $symDir | Out-Null
    $obfuscateArgs = @(
        "--split-debug-info=$symDir",
        "--obfuscate"
    )

    if ($Target -eq "apk") {
        $flutterArgs = @("build", "apk", "--release") + $obfuscateArgs
        if ($SplitPerAbi) {
            $flutterArgs += "--split-per-abi"
        }
        $flutterArgs += $fromFileArg
        flutter @flutterArgs
        if ($LASTEXITCODE -ne 0) {
            throw "flutter build failed (exit $LASTEXITCODE). Fix errors above, then rerun."
        }
    }
    else {
        if ($SplitPerAbi) {
            Write-Warning "-SplitPerAbi applies to APK builds only; app bundles are split by Play when you upload the AAB."
        }
        flutter build appbundle --release @obfuscateArgs $fromFileArg
        if ($LASTEXITCODE -ne 0) {
            throw "flutter build appbundle failed (exit $LASTEXITCODE). Fix errors above, then rerun."
        }
    }

    Write-Host ""
    Write-Host "Build complete."
    Write-Host "pubspec: $verLine"
    Write-Host "Users see version: $visibleVer (in Settings / About)."
    if ($Target -eq "apk") {
        $outDir = Join-Path $repoRoot "build\app\outputs\flutter-apk"
        if ($SplitPerAbi) {
            Write-Host ""
            Write-Host "Split-per-ABI APKs (install the one matching the device CPU):" -ForegroundColor Cyan
            Write-Host ('  {0}   (32-bit ARM)' -f (Join-Path $outDir 'app-armeabi-v7a-release.apk'))
            Write-Host ('  {0}   (64-bit ARM - most phones)' -f (Join-Path $outDir 'app-arm64-v8a-release.apk'))
            Write-Host ('  {0}   (emulator / some tablets)' -f (Join-Path $outDir 'app-x86_64-release.apk'))
        }
        else {
            Write-Host ""
            Write-Host "Universal APK:" -ForegroundColor Cyan
            Write-Host ('  {0}' -f (Join-Path $outDir 'app-release.apk'))
        }
    }
    else {
        Write-Host ""
        Write-Host "App bundle:" -ForegroundColor Cyan
        Write-Host "  $(Join-Path $repoRoot 'build\app\outputs\bundle\release\app-release.aab')"
    }
    Write-Host ""
    Write-Host "Tip: commit pubspec.yaml. If you shipped a new semver, add bullets under that key in:"
    Write-Host "     lib/core/about_release_notes.dart"
}
finally {
    if ($null -ne $definesPath -and (Test-Path -LiteralPath $definesPath)) {
        Remove-Item -LiteralPath $definesPath -Force -ErrorAction SilentlyContinue
    }
    Pop-Location
}
