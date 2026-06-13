<#
.SYNOPSIS
  Run the PINE app in debug mode on a connected emulator or USB device.

.DESCRIPTION
  From the project root (or run from anywhere — script cds to repo root).
  Supabase: pass -SupabaseUrl / -SupabaseAnonKey or set:
    $env:PINYA_PIC_SUPABASE_URL
    $env:PINYA_PIC_SUPABASE_ANON_KEY
  The key can be the legacy anon JWT (eyJ... three dot-separated parts) or the new publishable key (sb_publishable_... from Project Settings -> API).
  Use -NoSupabase to run without dart-defines (configuration screen until you set credentials in-app or rebuild).
  By default there is NO GET /rest/v1/ network preflight (it caused false 401s with valid publishable keys and legacy JWTs where PostgREST differs from the Flutter client). Optional: -TestSupabaseOnline runs that check; add -StrictSupabaseProbe to abort on HTTP 401/403.

.EXAMPLE
  .\scripts\run_debug.ps1
.EXAMPLE
  .\scripts\run_debug.ps1 -Device 10944373AB107405
.EXAMPLE
  .\scripts\run_debug.ps1 -SupabaseUrl 'https://xxx.supabase.co' -SupabaseAnonKey 'eyJ...'
.EXAMPLE
  .\scripts\run_debug.ps1 -NoSupabase
.EXAMPLE
  .\scripts\run_debug.ps1 -SupabaseUrl '...' -SupabaseAnonKey '...' -TestSupabaseOnline
#>
param(
    [Parameter(Mandatory = $false)]
    [string]$SupabaseUrl = "",

    [Parameter(Mandatory = $false)]
    [string]$SupabaseAnonKey = "",

    [Parameter(Mandatory = $false, HelpMessage = "Device id from `flutter devices` (e.g. phone serial)")]
    [Alias("d")]
    [string]$Device = "",

    [switch]$NoSupabase,

    [Parameter(HelpMessage = "Call GET {url}/rest/v1/ with the key before flutter run (opt-in; can false-fail for valid keys).")]
    [switch]$TestSupabaseOnline,

    [Parameter(HelpMessage = "With -TestSupabaseOnline: abort the script if the REST probe returns 401/403 for all header modes. Without -TestSupabaseProbe: warn only.")]
    [switch]$StrictSupabaseProbe,

    [Parameter(HelpMessage = "Obsolete: no-op. REST preflight is off by default; remove this flag.")]
    [switch]$SkipSupabaseOnlineCheck
)

function Get-SupabaseProjectRefFromHost {
    param([string]$DnsHost)
    if ($DnsHost -match '^([a-z0-9]+)\.supabase\.co$') { return $Matches[1] }
    return $null
}

function Test-IsSupabasePublishableKey {
    param([string]$Key)
    return $Key.Trim().StartsWith('sb_publishable_', [StringComparison]::OrdinalIgnoreCase)
}

function Read-SupabaseJwtPayloadRef {
    param([string]$Jwt)
    $dotCount = ([regex]::Matches($Jwt, '\.')).Count
    if ($dotCount -ne 2) {
        throw "Anon key must be a JWT (three segments: header.payload.signature). Found $dotCount dot(s). Re-copy from Supabase Dashboard -> Project Settings -> API -> anon public."
    }
    $parts = $Jwt.Split('.', [StringSplitOptions]::None)
    if ($parts.Length -ne 3) {
        throw "Anon key split into $($parts.Length) segment(s); expected 3."
    }
    $seg = $parts[1]
    $b64 = $seg.Replace('-', '+').Replace('_', '/')
    $pad = (4 - ($b64.Length % 4)) % 4
    if ($pad -gt 0) { $b64 += ('=' * $pad) }
    try {
        $bytes = [Convert]::FromBase64String($b64)
    }
    catch {
        throw "Could not decode JWT payload (middle segment). The anon key may be truncated or contain invalid characters."
    }
    $json = [Text.Encoding]::UTF8.GetString($bytes)
    try {
        $obj = $json | ConvertFrom-Json
    }
    catch {
        throw "JWT payload is not valid JSON. Re-copy the anon key from the Supabase dashboard."
    }
    if (-not $obj.PSObject.Properties['ref']) {
        throw "JWT payload has no 'ref' field. Paste the Supabase anon public key (not another provider's JWT)."
    }
    if ($obj.PSObject.Properties['role'] -and $obj.role -ne 'anon') {
        Write-Warning "This JWT role is '$($obj.role)'. For client apps use the anon public key (role should be 'anon')."
    }
    return [string]$obj.ref
}

function Assert-SupabaseUrlAndKeyMatch {
    param([string]$UrlString, [string]$Key)
    $u = [Uri]$UrlString
    $refUrl = Get-SupabaseProjectRefFromHost -DnsHost $u.Host
    if (Test-IsSupabasePublishableKey -Key $Key) {
        if ($null -eq $refUrl) {
            Write-Host "Publishable key: URL host is not {{ref}}.supabase.co ($($u.Host)); cannot auto-check project. Ensure the key is for this project." -ForegroundColor DarkGray
        }
        else {
            Write-Host "Using new-style publishable key (sb_publishable_...). It must be from the same project as the URL (ref: $refUrl)." -ForegroundColor DarkGray
        }
        return
    }
    $refJwt = Read-SupabaseJwtPayloadRef -Jwt $Key
    if ($null -eq $refUrl) {
        Write-Host "Skipping JWT ref vs URL check (host is not {ref}.supabase.co: $($u.Host))." -ForegroundColor DarkGray
        return
    }
    if ($refJwt -cne $refUrl) {
        throw "JWT payload ref '$refJwt' does not match URL project '$refUrl'. Use the anon key from the same Supabase project as SUPABASE_URL."
    }
    Write-Host "Supabase JWT ref matches URL project ($refJwt)." -ForegroundColor DarkGray
}

function Test-SupabaseAnonKeyOnline {
    param(
        [string]$BaseUrl,
        [string]$Key,
        [bool]$ThrowOnFailure = $false
    )
    $root = $BaseUrl.TrimEnd('/')
    $uri = "$root/rest/v1/"
    # Publishable keys (sb_publishable_...) are NOT JWTs. Sending them as "Bearer" can make PostgREST try JWT validation and return 401.
    # Try apikey-only first for publishable; JWT anon keys use Bearer + apikey first (Supabase client style).
    $isPub = Test-IsSupabasePublishableKey -Key $Key
    if ($isPub) {
        $headerSets = @(
            @{ apikey = $Key; Accept = 'application/json' },
            @{ apikey = $Key; Authorization = "Bearer $Key"; Accept = 'application/json' }
        )
    }
    else {
        $headerSets = @(
            @{ apikey = $Key; Authorization = "Bearer $Key"; Accept = 'application/json' },
            @{ apikey = $Key; Accept = 'application/json' }
        )
    }
    $attempt = 0
    foreach ($headers in $headerSets) {
        $attempt++
        try {
            $null = Invoke-WebRequest -Uri $uri -Headers $headers -Method Get -UseBasicParsing -TimeoutSec 25
            if ($attempt -gt 1) {
                Write-Host "REST probe: succeeded on attempt $attempt (header mode order matters for publishable vs JWT keys)." -ForegroundColor DarkGray
            }
            return
        }
        catch {
            $resp = $_.Exception.Response
            $code = if ($null -ne $resp) { [int]$resp.StatusCode } else { 0 }
            if ($code -eq 401 -or $code -eq 403) { continue }
            Write-Warning "Could not verify anon key online ($($_.Exception.Message)). Continuing."
            return
        }
    }
    $msgPub = "Supabase GET $uri returned 401/403 (tried apikey-only, then Bearer). Re-check the key in Dashboard -> Project Settings -> API. Starting Flutter anyway; if the app cannot reach Supabase, fix the key or project."
    $msgJwt = "Supabase GET $uri returned 401/403. Re-copy the legacy anon JWT or use a publishable key. Starting Flutter anyway; if auth fails, fix the key."
    if ($ThrowOnFailure) {
        throw "Supabase REST probe failed (HTTP 401/403) on $uri. Fix the key or omit -StrictSupabaseProbe (warnings only)."
    }
    if ($isPub) { Write-Warning $msgPub }
    else { Write-Warning $msgJwt }
}

$ErrorActionPreference = "Stop"

$env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
    [System.Environment]::GetEnvironmentVariable('Path', 'User')

# Prefer Android SDK platform-tools for adb (flutter devices works either way)
$sdkRoot = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "$env:LOCALAPPDATA\Android\Sdk" }
$adbDir = Join-Path $sdkRoot "platform-tools"
if ((Test-Path (Join-Path $adbDir "adb.exe")) -and ($env:Path -notlike "*${adbDir}*")) {
    $env:Path = "$adbDir;$env:Path"
}

# Gradle's gradlew often requires JAVA_HOME before the daemon starts (org.gradle.java.home in gradle.properties is separate).
if (-not $env:JAVA_HOME) {
    $jbr = Join-Path $env:ProgramFiles "Android\Android Studio\jbr"
    if (Test-Path (Join-Path $jbr "bin\java.exe")) {
        $env:JAVA_HOME = $jbr
    }
}

# Flutter: use FLUTTER_ROOT if the SDK bin folder is not already on PATH (avoids broken "SDK`b" messages in errors).
$flutterRoot = $env:FLUTTER_ROOT
if ($flutterRoot) {
    $flutterBin = Join-Path $flutterRoot "bin"
    $hasFlutterExe = (Test-Path (Join-Path $flutterBin "flutter.bat")) -or (Test-Path (Join-Path $flutterBin "flutter.cmd")) -or (Test-Path (Join-Path $flutterBin "flutter.exe"))
    if ($hasFlutterExe -and ($env:Path -notlike "*${flutterBin}*")) {
        $env:Path = "$flutterBin;$env:Path"
    }
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw "flutter not in PATH. Set FLUTTER_ROOT to your Flutter SDK root, or add the SDK's bin folder to User PATH, then open a new terminal (see RUN.md)."
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot

try {
    $definesPath = $null
    $url = $SupabaseUrl.Trim()
    $key = $SupabaseAnonKey.Trim()
    if ([string]::IsNullOrWhiteSpace($url)) { $url = $env:PINYA_PIC_SUPABASE_URL }
    if ([string]::IsNullOrWhiteSpace($key)) { $key = $env:PINYA_PIC_SUPABASE_ANON_KEY }

    $useSupabase = -not $NoSupabase
    if ($useSupabase -and ([string]::IsNullOrWhiteSpace($url) -or [string]::IsNullOrWhiteSpace($key))) {
        throw @"
Missing Supabase credentials for dart-define. Either:
  - Pass -SupabaseUrl and -SupabaseAnonKey
  - Or set `$env:PINYA_PIC_SUPABASE_URL` and `$env:PINYA_PIC_SUPABASE_ANON_KEY`
  - Or use -NoSupabase to run without cloud config (see RUN.md).
"@
    }

    if ($useSupabase) {
        if ($SkipSupabaseOnlineCheck) {
            Write-Warning "Ignoring -SkipSupabaseOnlineCheck (obsolete: the GET /rest/v1/ preflight is off by default). Remove this switch from your command."
        }
        Assert-SupabaseUrlAndKeyMatch -UrlString $url -Key $key
        if ($TestSupabaseOnline) {
            Test-SupabaseAnonKeyOnline -BaseUrl $url -Key $key -ThrowOnFailure:([bool]$StrictSupabaseProbe)
        }
    }

    $flutterArgs = [System.Collections.ArrayList]::new()
    [void]$flutterArgs.Add("run")
    [void]$flutterArgs.Add("--debug")

    $dev = $Device.Trim()
    if ($dev) {
        [void]$flutterArgs.Add("-d")
        [void]$flutterArgs.Add($dev)
    }

    # JWT anon keys must not be passed as raw --dart-define=...=eyJ... on Windows:
    # Gradle/shell parsing can truncate or corrupt the value → Supabase "Invalid API key".
    if ($useSupabase) {
        $definesPath = Join-Path $env:TEMP "pine_supabase_defines_$([guid]::NewGuid().ToString('N')).json"
        $payload = [ordered]@{
            SUPABASE_URL      = $url
            SUPABASE_ANON_KEY = $key
        }
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        $jsonText = ($payload | ConvertTo-Json -Compress)
        [System.IO.File]::WriteAllText($definesPath, $jsonText, $utf8NoBom)
        [void]$flutterArgs.Add("--dart-define-from-file=$definesPath")
        try {
            $hostOnly = ([Uri]$url).Host
            Write-Host "Supabase: $hostOnly | anon key length: $($key.Length) chars (via dart-define-from-file)" -ForegroundColor DarkGray
        }
        catch {
            Write-Host "Supabase: (dart-define-from-file temp JSON at $definesPath)" -ForegroundColor DarkGray
        }
    }

    Write-Host "Repo: $repoRoot" -ForegroundColor Cyan
    Write-Host "flutter $($flutterArgs -join ' ')" -ForegroundColor Gray
    flutter @($flutterArgs.ToArray())
}
finally {
    if ($null -ne $definesPath -and (Test-Path -LiteralPath $definesPath)) {
        Remove-Item -LiteralPath $definesPath -Force -ErrorAction SilentlyContinue
    }
    Pop-Location
}
