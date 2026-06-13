# PINE Team Setup Check
# Run from project root: .\team_setup.ps1

Write-Host "🔍 PINE Team Setup Check" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan

Write-Host "`n📱 Checking Flutter..." -ForegroundColor Yellow
flutter --version

Write-Host "`n🔧 Checking Java version..." -ForegroundColor Yellow
java -version

Write-Host "`n📦 Checking Android SDK..." -ForegroundColor Yellow
Write-Host "ANDROID_HOME: $env:ANDROID_HOME"

Write-Host "`n✅ Installing dependencies..." -ForegroundColor Yellow
Set-Location $PSScriptRoot
flutter pub get

Write-Host "`n📱 Available devices:" -ForegroundColor Yellow
flutter devices

Write-Host "`n🚀 Ready to run!" -ForegroundColor Green
Write-Host "Use: flutter run -d emulator-5554" -ForegroundColor Green
