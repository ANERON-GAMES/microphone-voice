@echo off
setlocal EnableExtensions
if "%~1"=="" (
  set /p LEVEL=Sound level 10-300 percent [100]: 
) else (
  set "LEVEL=%~1"
)
if "%LEVEL%"=="" set "LEVEL=100"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Set-Microphone.ps1"
echo.
pause
