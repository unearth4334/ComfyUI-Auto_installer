@echo off

:: ============================================================================
:: Section 1: Check for and request administrator privileges
:: ============================================================================
REM Checks if the script has admin rights.
net session >nul 2>&1

REM If the previous command failed (errorlevel not 0), then we don't have rights.
if %errorlevel% NEQ 0 (
    echo [INFO] Requesting administrator privileges for the updater...
    
    REM Use PowerShell to re-launch this same batch script as an administrator.
    powershell.exe -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    
    REM Exit the current (non-admin) script.
    exit
)


:: ============================================================================
:: Section 2: Download the latest update script
:: ============================================================================
title ComfyUI Updater
echo [OK] Administrator privileges confirmed.
echo.

set "ScriptsFolder=%~dp0scripts"

REM Create the scripts folder if it doesn't exist.
if not exist "%ScriptsFolder%" mkdir "%ScriptsFolder%"

echo [INFO] Downloading the latest version of the update script...

echo   - Download of Install-ComfyUI.ps1...
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

REM Use PowerShell to reliably download the file.


echo [OK] Update script is up-to-date.
echo.

:: ============================================================================
:: Section 3: Execute the script
:: ============================================================================
echo [INFO] Launching the update script...
echo.

REM Execute the update script that was just downloaded.
powershell.exe -ExecutionPolicy Bypass -File "%ScriptsFolder%\Update-ComfyUI.ps1"

echo.
echo [INFO] The update script is complete.
pause