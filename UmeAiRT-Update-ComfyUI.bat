@echo off

:: Vérifie si les privilèges admin sont nécessaires pour le script PowerShell et les demande si besoin.
net session >nul 2>&1
if %errorlevel% NEQ 0 (
    echo [INFO] Demande des privilèges d'administrateur pour la mise a jour...
    powershell.exe -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit
)

title ComfyUI Updater
echo [INFO] Lancement du script de mise a jour...
echo.

REM Exécute le script de mise à jour qui se trouve dans le dossier "scripts"
powershell.exe -ExecutionPolicy Bypass -File "%~dp0scripts\Update-ComfyUI.ps1"

echo.
echo [INFO] Le script de mise a jour est termine.
pause