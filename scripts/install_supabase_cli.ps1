<#
.SYNOPSIS
  Download official Supabase CLI for Windows (npm global install is not supported).

.DESCRIPTION
  Puts supabase.exe under repo tools/supabase-cli/. Add that folder to PATH or run:
    .\tools\supabase-cli\supabase.exe login

.EXAMPLE
  .\scripts\install_supabase_cli.ps1
#>
$ErrorActionPreference = 'Stop'
# scripts/ -> repo root
$repoRoot = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path (Join-Path $repoRoot 'supabase'))) {
  throw "Run from PINE repo: expected $repoRoot\supabase"
}
$destDir = Join-Path $repoRoot 'tools\supabase-cli'
New-Item -ItemType Directory -Force -Path $destDir | Out-Null

Write-Host 'Fetching latest Supabase CLI release...'
$rel = Invoke-RestMethod -Uri 'https://api.github.com/repos/supabase/cli/releases/latest' -Headers @{ 'User-Agent' = 'PINE-install-supabase-cli' }
$asset = $rel.assets | Where-Object { $_.name -eq 'supabase_windows_amd64.tar.gz' } | Select-Object -First 1
if (-not $asset) {
  throw 'Could not find supabase_windows_amd64.tar.gz in latest release.'
}
$gz = Join-Path $env:TEMP ("supabase_cli_{0}.tar.gz" -f $rel.tag_name)
Write-Host "Downloading $($asset.browser_download_url) ..."
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $gz -UseBasicParsing

Write-Host "Extracting to $destDir ..."
Push-Location $destDir
try {
  tar -xzf $gz
} finally {
  Pop-Location
}
Remove-Item $gz -Force -ErrorAction SilentlyContinue

$exe = Join-Path $destDir 'supabase.exe'
if (-not (Test-Path $exe)) {
  throw "Expected $exe after extract. Check release layout."
}
Write-Host ""
Write-Host "OK: $exe"
Write-Host ""
Write-Host "Next (from repo root):"
Write-Host "  .\tools\supabase-cli\supabase.exe login"
Write-Host "  .\tools\supabase-cli\supabase.exe link --project-ref YOUR_PROJECT_REF"
Write-Host "  .\tools\supabase-cli\supabase.exe functions deploy pine-admin-create-user"
Write-Host "  .\tools\supabase-cli\supabase.exe functions deploy pine-admin-delete-user"
Write-Host "  .\tools\supabase-cli\supabase.exe functions deploy pine-admin-update-user-profile"
Write-Host ""
Write-Host 'Optional: prepend to PATH for this session:'
Write-Host ('  $env:Path = ''{0};'' + $env:Path' -f $destDir)
