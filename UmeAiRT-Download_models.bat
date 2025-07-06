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
echo  Choisissez un pack de modeles a telecharger :
echo.
echo    1. FLUX Models
echo    2. WAN Models
echo    3. HIDREAM Models
echo    4. LTXV Models
echo.
echo    Q. Quitter
echo.

set /p "CHOICE=Votre choix : "

if /i "%CHOICE%"=="1" goto :DOWNLOAD_FLUX
if /i "%CHOICE%"=="2" goto :DOWNLOAD_WAN
if /i "%CHOICE%"=="3" goto :DOWNLOAD_HIDREAM
if /i "%CHOICE%"=="4" goto :DOWNLOAD_LTXV
if /i "%CHOICE%"=="Q" goto :EOF

echo Choix invalide. Veuillez reessayer.
pause
goto :MENU


:DOWNLOAD_FLUX
echo Lancement du telechargement des modeles FLUX...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0scripts\Download-FLUX-Models.ps1" -InstallPath "%~dp0"
goto :END

:DOWNLOAD_WAN
echo Lancement du telechargement des modeles WAN...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0scripts\Download-WAN-Models.ps1" -InstallPath "%~dp0"
goto :END

:DOWNLOAD_HIDREAM
echo Lancement du telechargement des modeles HIDREAM...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0scripts\Download-HIDREAM-Models.ps1" -InstallPath "%~dp0"
goto :END

:DOWNLOAD_LTXV
echo Lancement du telechargement des modeles LTXV...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0scripts\Download-LTXV-Models.ps1" -InstallPath "%~dp0"
goto :END


:END
echo.
echo Le script de telechargement est termine.
pause
goto :MENU