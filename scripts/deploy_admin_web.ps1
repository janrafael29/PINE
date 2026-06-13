<#
.SYNOPSIS
  Deploy PineSight Admin to a public URL (Netlify or Supabase Storage backup).

.DESCRIPTION
  Recommended (live UI):
    Netlify production deploy - run: .\scripts\deploy_admin_web.ps1 -Target netlify -Prod
    Requires one-time: npx netlify-cli login

  Supabase Storage (-Target supabase):
    Uploads static files only. Supabase cannot render HTML in a browser (shows source code).

.PARAMETER Target
  netlify | supabase

.PARAMETER Prod
  For Netlify: deploy to production URL (recommended).

.EXAMPLE
  npx netlify-cli login
  .\scripts\deploy_admin_web.ps1 -Target netlify -Prod

.EXAMPLE
  $env:SUPABASE_SERVICE_ROLE_KEY = 'eyJ...'  # backup upload only
  .\scripts\deploy_admin_web.ps1 -Target supabase
#>
param(
  [ValidateSet('supabase', 'netlify')]
  [string]$Target = 'netlify',
  [switch]$Prod
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$adminDir = Join-Path $repoRoot 'admin'
$configPath = Join-Path $adminDir 'config.js'

if (-not (Test-Path $configPath)) {
  throw 'Missing admin/config.js - copy from admin/config.example.js and fill Supabase URL + anon key.'
}

if ($Target -eq 'supabase') {
  Write-Host ''
  Write-Host 'Note: Supabase URLs cannot render HTML in a browser (platform serves HTML as plain text).' -ForegroundColor Yellow
  Write-Host 'Use -Target netlify -Prod for the live admin UI.' -ForegroundColor Yellow
  Write-Host ''
  $url = 'https://sjdcnkendlgqbxxjdqml.supabase.co'
  if (-not $env:SUPABASE_URL) { $env:SUPABASE_URL = $url }
  if (-not $env:SUPABASE_SERVICE_ROLE_KEY) {
    Write-Host ''
    Write-Host 'Supabase Storage deploy needs your service_role key (one time):' -ForegroundColor Yellow
    Write-Host '  Supabase Dashboard -> Settings -> API -> service_role -> Reveal'
    Write-Host ''
    Write-Host 'Then run:' -ForegroundColor Cyan
    Write-Host '  $env:SUPABASE_SERVICE_ROLE_KEY = ''YOUR_SERVICE_ROLE_KEY'''
    Write-Host '  .\scripts\deploy_admin_web.ps1'
    Write-Host ''
    exit 1
  }

  node (Join-Path $repoRoot 'scripts\deploy_admin_web.mjs')
  exit $LASTEXITCODE
}

# Netlify
$netlifyArgs = @('deploy', '--dir', '.', '--message', 'PineSight Admin')
if ($Prod -or -not $PSBoundParameters.ContainsKey('Prod')) { $netlifyArgs += '--prod' }

Push-Location $adminDir
try {
  npx --yes netlify-cli @netlifyArgs
} finally {
  Pop-Location
}
