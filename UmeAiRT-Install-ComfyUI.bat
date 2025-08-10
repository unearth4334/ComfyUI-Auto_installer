@echo off
setlocal

:: ============================================================================
:: Section 1: Checking and requesting administrator privileges
:: ============================================================================
net session >nul 2>&1
if %errorlevel% NEQ 0 (
    echo [INFO] Requesting administrator privileges...
    powershell.exe -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: ============================================================================
:: Section 2: Bootstrap downloader for all scripts
:: ============================================================================
title UmeAiRT ComfyUI Installer
echo [OK] Administrator privileges confirmed.
echo.

set "ScriptsFolder=%~dp0scripts"
set "BootstrapScript=%ScriptsFolder%\Bootstrap-Downloader.ps1"
set "BootstrapUrl=https://github.com/UmeAiRT/ComfyUI-Auto_installer/raw/refs/heads/main/scripts/Bootstrap-Downloader.ps1"

:: Create scripts folder if it doesn't exist
if not exist "%ScriptsFolder%" (
    echo [INFO] Creating the scripts folder: %ScriptsFolder%
    mkdir "%ScriptsFolder%"
)

:: Download the bootstrap script
echo [INFO] Downloading the bootstrap script...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%BootstrapUrl%' -OutFile '%BootstrapScript%'"

:: Run the bootstrap script to download all other files
echo [INFO] Running the bootstrap script to download all required files...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%BootstrapScript%" -InstallPath "%~dp0"
echo [OK] Bootstrap download complete.
echo.

:: ============================================================================
:: Section 3: Running the main installation script
:: ============================================================================
echo [INFO] Launching the main installation script...
echo.

powershell.exe -ExecutionPolicy Bypass -File "%ScriptsFolder%\Install-ComfyUI.ps1" -InstallPath "%~dp0"

echo.
echo [INFO] The script execution is complete.
pause
