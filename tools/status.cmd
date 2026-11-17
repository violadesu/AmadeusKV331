@echo off
rem Double-click helper: report whether claude.exe is currently armored.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\scripts\check-armor.ps1" %*
echo.
pause
