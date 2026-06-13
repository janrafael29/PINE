# Run Android emulator with verbose output to see why it exits with code 1.
# Usage: .\scripts\run_emulator_verbose.ps1
# Or for a specific AVD: $env:ANDROID_HOME\emulator\emulator.exe -avd pixel_4_api_36 -verbose 2>&1

$avd = "pixel_4_api_36"
$emu = "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe"
if (-not (Test-Path $emu)) { $emu = "$env:ANDROID_HOME\emulator\emulator.exe" }
if (-not (Test-Path $emu)) {
    Write-Host "Emulator not found. Set ANDROID_HOME or ensure Android SDK is installed."
    exit 1
}
Write-Host "Launching AVD: $avd (verbose)..."
& $emu -avd $avd -verbose 2>&1
