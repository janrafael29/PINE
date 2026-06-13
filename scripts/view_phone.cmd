@echo off

setlocal

rem Double-click or: view_phone.cmd -Serial YOUR_ID

rem Extra args are passed to view_phone.ps1 (e.g. -List, -MaxSize 1280).

cd /d "%~dp0.."

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0view_phone.ps1" %*

if errorlevel 1 (

  echo.

  pause

)

