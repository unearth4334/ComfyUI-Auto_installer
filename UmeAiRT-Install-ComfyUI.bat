@echo off

:: ============================================================================
:: Section 1: Checking and requesting administrator privileges
:: ============================================================================
net session >nul 2>&1
if %errorlevel% NEQ 0 (
    echo [INFO] Requesting administrator privileges...
    powershell.exe -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit
)

:: ============================================================================
:: Section 2: Updated scripts from Github
:: ============================================================================
title UmeAiRT ComfyUI Installer
echo [OK] Administrator privileges confirmed.
echo.

set "ScriptsFolder=%~dp0scripts"
if not exist "%ScriptsFolder%" (
    echo [INFO] Creating the folder for the scripts: %ScriptsFolder%
    mkdir "%ScriptsFolder%"
)
echo [INFO] Downloading the latest versions of the installation scripts...

echo   - Download ofInstall-ComfyUI.ps1...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://github.com/UmeAiRT/ComfyUI-Auto_installer/raw/refs/heads/main/scripts/Install-ComfyUI.ps1' -OutFile '%ScriptsFolder%\Install-ComfyUI.ps1'"
echo   - Download of Update-ComfyUI.ps1...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://github.com/UmeAiRT/ComfyUI-Auto_installer/raw/refs/heads/main/scripts/Update-ComfyUI.ps1' -OutFile '%ScriptsFolder%\Update-ComfyUI.ps1'"
echo   - Download of Download-FLUX-Models.ps1...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://github.com/UmeAiRT/ComfyUI-Auto_installer/raw/refs/heads/main/scripts/Download-FLUX-Models.ps1' -OutFile '%ScriptsFolder%\Download-FLUX-Models.ps1'"
echo   - Download of Download-WAN-Models.ps1...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://github.com/UmeAiRT/ComfyUI-Auto_installer/raw/refs/heads/main/scripts/Download-WAN-Models.ps1' -OutFile '%ScriptsFolder%\Download-WAN-Models.ps1'"
echo   - Download of Download-HIDREAM-Models.ps1...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://github.com/UmeAiRT/ComfyUI-Auto_installer/raw/refs/heads/main/scripts/Download-HIDREAM-Models.ps1' -OutFile '%ScriptsFolder%\Download-HIDREAM-Models.ps1'"
echo   - Download of Download-LTXV-Models.ps1...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://github.com/UmeAiRT/ComfyUI-Auto_installer/raw/refs/heads/main/scripts/Download-LTXV-Models.ps1' -OutFile '%ScriptsFolder%\Download-LTXV-Models.ps1'"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://github.com/UmeAiRT/ComfyUI-Auto_installer/raw/refs/heads/main/UmeAiRT-Start-ComfyUI.bat' -OutFile '%~dp0UmeAiRT-Start-ComfyUI.bat'"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://github.com/UmeAiRT/ComfyUI-Auto_installer/raw/refs/heads/main/UmeAiRT-Download_models.bat' -OutFile '%~dp0UmeAiRT-Download_models.bat'"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://github.com/UmeAiRT/ComfyUI-Auto_installer/raw/refs/heads/main/UmeAiRT-Update-ComfyUI.bat' -OutFile '%~dp0UmeAiRT-Update-ComfyUI.bat'"

echo [OK] Updated scripts.
echo.

:: ============================================================================
:: Section 3: Running the main script
:: ============================================================================
echo [INFO] Launching the main installation script...
echo.

REM NOUVEAU : On passe le chemin d'installation en argument avec -InstallPath
powershell.exe -ExecutionPolicy Bypass -File "%ScriptsFolder%\Install-ComfyUI.ps1" -InstallPath "%~dp0"

echo.
echo [INFO] The script execution is complete.
pause