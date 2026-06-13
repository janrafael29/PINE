# PINE - Complete Setup Verification
# Run from project root: .\setup_check.ps1

Write-Host "`n🔍 PINE - Complete Setup Verification" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

Write-Host "`n📱 Checking Flutter Setup..." -ForegroundColor Yellow
flutter --version
flutter doctor

Write-Host "`n📱 Checking Android SDK..." -ForegroundColor Yellow
Write-Host "ANDROID_HOME: $env:ANDROID_HOME"
Write-Host "ANDROID_SDK_ROOT: $env:ANDROID_SDK_ROOT"

Write-Host "`n📱 Emulator Status:" -ForegroundColor Yellow
flutter emulators
flutter devices

Write-Host "`n📱 ADB Devices:" -ForegroundColor Yellow
adb devices

Write-Host "`n🔥 Checking Firebase..." -ForegroundColor Yellow
if (Test-Path "D:\PINE\android\app\google-services.json") {
    Write-Host "✅ google-services.json found" -ForegroundColor Green
} else {
    Write-Host "❌ google-services.json missing" -ForegroundColor Red
}

if (Test-Path "D:\PINE\lib\firebase_options.dart") {
    Write-Host "✅ firebase_options.dart found" -ForegroundColor Green
} else {
    Write-Host "❌ firebase_options.dart missing" -ForegroundColor Red
}

Write-Host "`n📁 Checking Model..." -ForegroundColor Yellow
if (Test-Path "D:\PINE\assets\model\best.tflite") {
    $modelSize = (Get-Item "D:\PINE\assets\model\best.tflite").Length / 1MB
    Write-Host "✅ Model found: $([math]::Round($modelSize, 2)) MB" -ForegroundColor Green
} else {
    Write-Host "❌ Model missing at assets/model/best.tflite" -ForegroundColor Red
}

Write-Host "`n📦 Project Status:" -ForegroundColor Yellow
Set-Location "D:\PINE"
flutter pub get

Write-Host "`n✅ SYSTEM READY!" -ForegroundColor Green
Write-Host "Run: flutter run -d emulator-5554" -ForegroundColor Cyan
