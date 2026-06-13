# Push PINE to GitHub before building release APK
# Run in PowerShell from D:\PINE. If "index.lock" error appears, close other terminals/IDE and run again.

Set-Location $PSScriptRoot

# Remove stale lock from previous crashed/long-running git command
if (Test-Path ".git\index.lock") {
    try {
        Remove-Item ".git\index.lock" -Force
        Write-Host "Removed .git\index.lock"
    } catch {
        Write-Host "Could not remove index.lock - close other Git/IDE windows and run this script again."
        exit 1
    }
}

Write-Host "Staging all files (.gitignore excludes build/, venv/, .gradle/, google-services.json, *.apk)..."
git add .
Write-Host "`nStaged:"
git status --short

Write-Host "`n--- Next steps ---"
Write-Host "1. Commit:"
Write-Host '   git commit -m "Modernized UI: 5-tab nav, Home/Diagnose/My Fields/More, theme and Gradle fix"'
Write-Host "`n2. Add remote (only first time):"
Write-Host "   git remote add origin https://github.com/janrafael29/PINE.git"
Write-Host "`n3. Push:"
Write-Host "   git push -u origin main"
Write-Host "`n4. Then build release APK:"
Write-Host "   flutter build apk --release"
