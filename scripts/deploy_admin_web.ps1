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
$wantProd = $Prod -or -not $PSBoundParameters.ContainsKey('Prod')

function Invoke-NetlifyCli {
  param(
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$CliArgs,
    [switch]$Quiet
  )
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    if ($Quiet) {
      & npx --yes netlify-cli @CliArgs 2>&1 | Out-Null
    } else {
      & npx --yes netlify-cli @CliArgs 2>&1 | ForEach-Object { Write-Host $_ }
    }
    return [int]$LASTEXITCODE
  } finally {
    $ErrorActionPreference = $prev
  }
}

function Invoke-NetlifyProdViaDraftRestore {
  param([string]$Message)
  Write-Host ''
  Write-Host 'Production deploy blocked (often Netlify credit limit). Using draft + publish workaround...' -ForegroundColor Yellow
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $raw = & npx --yes netlify-cli deploy --dir . --message $Message --json 2>&1 | Out-String
  } finally {
    $ErrorActionPreference = $prev
  }
  if ($LASTEXITCODE -ne 0) {
    throw "Netlify draft deploy failed.`n$raw"
  }
  if ($raw -notmatch '(?s)\{.*\}') {
    throw "Netlify draft deploy returned no JSON.`n$raw"
  }
  $deploy = $Matches[0] | ConvertFrom-Json
  if (-not $deploy.deploy_id -or -not $deploy.site_id) {
    throw "Unexpected Netlify JSON: $($Matches[0])"
  }
  $apiData = '{\"site_id\":\"' + $deploy.site_id + '\",\"deploy_id\":\"' + $deploy.deploy_id + '\"}'
  $code = Invoke-NetlifyCli api restoreSiteDeploy --data $apiData
  if ($code -ne 0) { throw 'Netlify restoreSiteDeploy failed.' }
  Write-Host ''
  Write-Host "Production URL: https://$($deploy.site_name).netlify.app" -ForegroundColor Green
  Write-Host "Deploy: $($deploy.logs)" -ForegroundColor DarkGray
}

Push-Location $adminDir
try {
  if ($wantProd) {
    $code = Invoke-NetlifyCli -Quiet deploy --dir . --message 'PineSight Admin' --prod
    if ($code -ne 0) {
      Invoke-NetlifyProdViaDraftRestore -Message 'PineSight Admin'
    }
  } else {
    $code = Invoke-NetlifyCli deploy --dir . --message 'PineSight Admin'
    if ($code -ne 0) { exit $code }
  }
} finally {
  Pop-Location
}
