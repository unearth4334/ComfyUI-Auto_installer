@echo off
echo Activating ComfyUI virtual environment...

REM Activates the virtual environment.
REM Using "%~dp0" ensures the path is correct regardless of where the script is run from.
call "%~dp0ComfyUI\venv\Scripts\activate.bat"

echo Starting ComfyUI with custom arguments...

REM Moves to the ComfyUI folder.
REM The /d option is added to the cd command to ensure it also changes the drive if necessary (e.g., from C: to D:).
cd /d "%~dp0ComfyUI"

REM Prepares the base path, ensuring it is correctly formatted.
set "RAW_BASE_DIR=%~dp0"
REM Removes the trailing backslash if it exists to prevent path errors.
if "%RAW_BASE_DIR:~-1%"=="\" set "RAW_BASE_DIR=%RAW_BASE_DIR:~0,-1%"

REM Adds quotes around the paths directly into the variables.
REM This is the main fix to handle spaces in folder names.
set "BASE_DIR="%RAW_BASE_DIR%""
set "TMP_DIR="%RAW_BASE_DIR%\ComfyUI\temp""

echo Launching Python script...
REM Runs the Python script. The %BASE_DIR% and %TMP_DIR% variables already contain the quotes,
REM ensuring that paths with spaces are treated as a single argument.
python main.py --use-sage-attention --disable-smart-memory --base-directory %BASE_DIR% --auto-launch --temp-directory %TMP_DIR%

pause
