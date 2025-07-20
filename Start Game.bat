@echo off
echo Starting PowerShell Leafmap Game...
echo.

cd /d "%~dp0"

powershell.exe -ExecutionPolicy Bypass -File "Launch-Game.ps1"

echo.
echo Game server stopped.
pause
