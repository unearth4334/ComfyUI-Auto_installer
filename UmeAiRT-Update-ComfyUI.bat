@echo off
setlocal

:: ============================================================================
:: Section 1: Checking and requesting administrator privileges
:: ============================================================================
net session >nul 2>&1
if %errorlevel% NEQ 0 (
    echo [INFO] Requesting administrator privileges for the updater...
    powershell.exe -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: ============================================================================
:: Section 2: Bootstrap downloader for all scripts
:: ============================================================================
title UmeAiRT ComfyUI Updater
echo [OK] Administrator privileges confirmed.
echo.

:: Create a "clean" path variable without the trailing backslash
set "InstallPath=%~dp0"
if "%InstallPath:~-1%"=="\" set "InstallPath=%InstallPath:~0,-1%"

set "ScriptsFolder=%InstallPath%\scripts"
set "BootstrapScript=%ScriptsFolder%\Bootstrap-Downloader.ps1"
set "BootstrapUrl=https://github.com/UmeAiRT/ComfyUI-Auto_installer/raw/main/scripts/Bootstrap-Downloader.ps1"

:: Create scripts folder if it doesn't exist
if not exist "%ScriptsFolder%" (
    echo [INFO] Creating the scripts folder: %ScriptsFolder%
    mkdir "%ScriptsFolder%"
)

:: Download the bootstrap script
echo [INFO] Downloading the bootstrap script to get the latest files...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%BootstrapUrl%' -OutFile '%BootstrapScript%'"

:: Run the bootstrap script to download all other files
echo [INFO] Running the bootstrap script to update all required files...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%BootstrapScript%" -InstallPath "%InstallPath%"
echo [OK] All scripts are now up-to-date.
echo.

:: ============================================================================
:: Section 3: Running the main update script
:: ============================================================================
echo [INFO] Launching the main update script...
echo.

:: Execute the update script that was just downloaded
powershell.exe -ExecutionPolicy Bypass -File "%ScriptsFolder%\Update-ComfyUI.ps1" -InstallPath "%InstallPath%"

echo.
echo [INFO] The update script is complete.
pause