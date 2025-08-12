@echo off
setlocal

:MENU
cls
echo =================================================
echo.
echo           UmeAiRT Model Downloader Menu
echo.
echo =================================================
echo.
echo  Choose model to download:
echo.
echo    1. FLUX Models
echo    2. WAN2.1 Models
echo    3. WAN2.2 Models
echo    4. HIDREAM Models
echo    5. LTXV Models
echo    6. QWEN Models
echo.
echo    Q. Quit
echo.

set /p "CHOICE=Your choice:"

if /i "%CHOICE%"=="1" goto :DOWNLOAD_FLUX
if /i "%CHOICE%"=="2" goto :DOWNLOAD_WAN2.1
if /i "%CHOICE%"=="3" goto :DOWNLOAD_WAN2.2
if /i "%CHOICE%"=="4" goto :DOWNLOAD_HIDREAM
if /i "%CHOICE%"=="5" goto :DOWNLOAD_LTXV
if /i "%CHOICE%"=="6" goto :DOWNLOAD_QWEN
if /i "%CHOICE%"=="Q" goto :EOF

echo Choix invalide. Veuillez reessayer.
pause
goto :MENU


:DOWNLOAD_FLUX
echo Launch of the download of FLUX models...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0scripts\Download-FLUX-Models.ps1" -InstallPath "%~dp0"
goto :END

:DOWNLOAD_WAN2.1
echo Launch of WAN template download...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0scripts\Download-WAN2.1-Models.ps1" -InstallPath "%~dp0"
goto :END

:DOWNLOAD_WAN2.2
echo Launch of WAN template download...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0scripts\Download-WAN2.2-Models.ps1" -InstallPath "%~dp0"
goto :END

:DOWNLOAD_HIDREAM
echo Launch of HIDREAM model downloads...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0scripts\Download-HIDREAM-Models.ps1" -InstallPath "%~dp0"
goto :END

:DOWNLOAD_LTXV
echo LTXV model download launch...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0scripts\Download-LTXV-Models.ps1" -InstallPath "%~dp0"
goto :END

:DOWNLOAD_QWEN
echo Launch of WAN template download...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0scripts\Download-QWEN-Models.ps1" -InstallPath "%~dp0"
goto :END

:END
echo.
echo The download script is complete.
pause
goto :MENU