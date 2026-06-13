<#

.SYNOPSIS

  Mirror/control a USB-debugging-enabled Android device on the PC (scrcpy + adb).



.DESCRIPTION

  The -Serial value is the same id as the first column from:

    flutter devices

    adb devices -l

  Install scrcpy:  winget install Genymobile.scrcpy

  Phone: Developer options → USB debugging ON.



.EXAMPLE

  .\scripts\scrcpy_phone.ps1

.EXAMPLE

  .\scripts\scrcpy_phone.ps1 -Serial 10944373AB107405

.EXAMPLE

  .\scripts\scrcpy_phone.ps1 -MaxSize 1280

#>

param(

    [string]$Serial = "",

    [int]$MaxSize = 0,

    [switch]$NoStayAwake,

    [switch]$List

)



$ErrorActionPreference = "Stop"



# Stale PATH in older shells / Cursor: reload Machine + User, then common SDK paths.

$env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +

    [System.Environment]::GetEnvironmentVariable('Path', 'User')



$sdkRoot = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "$env:LOCALAPPDATA\Android\Sdk" }

$adbDir = Join-Path $sdkRoot "platform-tools"

if ((Test-Path (Join-Path $adbDir "adb.exe")) -and ($env:Path -notlike "*${adbDir}*")) {

    $env:Path = "$adbDir;$env:Path"

}



function Add-ScrcpyToPath {

    if (Get-Command scrcpy -ErrorAction SilentlyContinue) {

        return $true

    }

    $found = Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter "scrcpy.exe" -Recurse -ErrorAction SilentlyContinue |

        Select-Object -First 1 -ExpandProperty FullName

    if ($found) {

        $dir = Split-Path -Parent $found

        if ($env:Path -notlike "*${dir}*") {

            $env:Path = "$dir;$env:Path"

        }

        return $null -ne (Get-Command scrcpy -ErrorAction SilentlyContinue)

    }

    return $false

}



if (-not (Add-ScrcpyToPath)) {

    throw @"

scrcpy not found. Install:

  winget install Genymobile.scrcpy

Then open a new terminal, or run from: https://github.com/Genymobile/scrcpy/releases

"@

}



if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {

    throw @"

adb not found. Install Android SDK platform-tools (Android Studio / SDK Manager), or add platform-tools to PATH.

Expected: $adbDir\adb.exe

"@

}



if ($List) {

    Write-Host "adb:" -ForegroundColor Cyan

    adb devices -l

    Write-Host ""

    Write-Host "Use the first column as -Serial when several devices are connected (same id as ``flutter devices``)." -ForegroundColor Gray

    exit 0

}



$deviceLines = @(adb devices | Select-String "^\S+\s+device\s*$")

if (-not $deviceLines) {

    throw "No device in `adb devices` with state `device`. Unlock the phone, allow USB debugging, try another USB cable/port."

}



if ($deviceLines.Count -gt 1 -and -not $Serial.Trim()) {

    $msg = @"

Multiple Android devices/emulators are connected. Choose one serial from below and run again with -Serial <id>



  adb devices -l

  flutter devices



"@

    throw ($msg + (adb devices -l | Out-String))

}



$scrcpyArgs = [System.Collections.ArrayList]::new()

[void]$scrcpyArgs.Add("--window-title=Phone (scrcpy - USB)")

$sid = $Serial.Trim()

if ($sid) {

    [void]$scrcpyArgs.Add("--serial=$sid")

}

if (-not $NoStayAwake) {

    [void]$scrcpyArgs.Add("--stay-awake")

}

if ($MaxSize -gt 0) {

    [void]$scrcpyArgs.Add("--max-size=$MaxSize")

}



Write-Host "Starting scrcpy..." -ForegroundColor Cyan

& scrcpy @($scrcpyArgs.ToArray())

