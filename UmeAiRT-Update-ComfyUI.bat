@echo off

REM Checks if admin privileges are required for the PowerShell script and requests them if necessary.
net session >nul 2>&1
if %errorlevel% NEQ 0 (
    echo [INFO] Requesting administrator privileges for update...
    powershell.exe -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit
)

title ComfyUI Updater
echo [INFO] Launching the update script...
echo.

REM Runs the update script located in the "scripts" folder
powershell.exe -ExecutionPolicy Bypass -File "%~dp0scripts\Update-ComfyUI.ps1"

echo.
echo [INFO] The update script is complete.
pause