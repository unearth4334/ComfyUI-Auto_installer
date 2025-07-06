@echo off

:: ============================================================================
:: Section 1: Vérification et demande des privilèges d'administrateur
:: ============================================================================
net session >nul 2>&1
if %errorlevel% NEQ 0 (
    echo [INFO] Demande des privilèges d'administrateur...
    powershell.exe -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit
)

:: ============================================================================
:: Section 2: Mise à jour des scripts depuis Hugging Face
:: ============================================================================
title UmeAiRT ComfyUI Installer
echo [OK] Privileges d'administrateur confirmes.
echo.

set "ScriptsFolder=%~dp0scripts"
if not exist "%ScriptsFolder%" (
    echo [INFO] Creation du dossier pour les scripts : %ScriptsFolder%
    mkdir "%ScriptsFolder%"
)
echo [INFO] Telechargement des dernieres versions des scripts d'installation...

echo   - Telechargement de Install-ComfyUI.ps1...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://github.com/UmeAiRT/ComfyUI-Auto_installer/blob/main/scripts/Install-ComfyUI.ps1' -OutFile '%ScriptsFolder%\Install-ComfyUI.ps1'"
echo   - Telechargement de Update-ComfyUI.ps1...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://github.com/UmeAiRT/ComfyUI-Auto_installer/blob/main/scripts/Update-ComfyUI.ps1' -OutFile '%ScriptsFolder%\Update-ComfyUI.ps1'"
echo   - Telechargement de Download-FLUX-Models.ps1...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://github.com/UmeAiRT/ComfyUI-Auto_installer/blob/main/scripts/Download-FLUX-Models.ps1' -OutFile '%ScriptsFolder%\Download-FLUX-Models.ps1'"
echo   - Telechargement de Download-WAN-Models.ps1...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://github.com/UmeAiRT/ComfyUI-Auto_installer/blob/main/scripts/Download-WAN-Models.ps1' -OutFile '%ScriptsFolder%\Download-WAN-Models.ps1'"
echo   - Telechargement de Download-HIDREAM-Models.ps1...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://github.com/UmeAiRT/ComfyUI-Auto_installer/blob/main/scripts/Download-HIDREAM-Models.ps1' -OutFile '%ScriptsFolder%\Download-HIDREAM-Models.ps1'"
echo   - Telechargement de Download-LTXV-Models.ps1...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://github.com/UmeAiRT/ComfyUI-Auto_installer/blob/main/scripts/Download-LTXV-Models.ps1' -OutFile '%ScriptsFolder%\Download-LTXV-Models.ps1'"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://github.com/UmeAiRT/ComfyUI-Auto_installer/blob/main/UmeAiRT-Start-ComfyUI.bat' -OutFile '%~dp0UmeAiRT-Start-ComfyUI.bat'"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://github.com/UmeAiRT/ComfyUI-Auto_installer/blob/main/UmeAiRT-Download_models.bat' -OutFile '%~dp0UmeAiRT-Download_models.bat'"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://github.com/UmeAiRT/ComfyUI-Auto_installer/blob/main/UmeAiRT-Update-ComfyUI.bat' -OutFile '%~dp0UmeAiRT-Update-ComfyUI.bat'"

echo [OK] Scripts mis a jour.
echo.

:: ============================================================================
:: Section 3: Exécution du script principal
:: ============================================================================
echo [INFO] Lancement du script d'installation principal...
echo.

REM NOUVEAU : On passe le chemin d'installation en argument avec -InstallPath
powershell.exe -ExecutionPolicy Bypass -File "%ScriptsFolder%\Install-ComfyUI.ps1" -InstallPath "%~dp0"

echo.
echo [INFO] L'execution du script est terminee.
pause