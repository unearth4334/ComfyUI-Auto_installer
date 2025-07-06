@echo off
echo Activating ComfyUI virtual environment...

REM Active l'environnement virtuel.
call "%~dp0ComfyUI\venv\Scripts\activate.bat"

echo Starting ComfyUI with custom arguments...

REM Se place dans le dossier ComfyUI.
cd "%~dp0ComfyUI"

REM === CORRECTION ===
REM On prépare le chemin de base en s'assurant qu'il n'y a pas de backslash à la fin
REM pour éviter les problèmes d'interprétation des guillemets.
set "BASE_DIR=%~dp0"
if "%BASE_DIR:~-1%"=="\" set "BASE_DIR=%BASE_DIR:~0,-1%"

REM On exécute le script en utilisant la variable de chemin nettoyée.
python main.py --use-sage-attention --disable-smart-memory --base-directory "%BASE_DIR%" --auto-launch

pause