@echo off
REM Wrapper batch file to install ComfyUI custom nodes only
REM This script calls the main custom nodes installer PowerShell script

cd /d "%~dp0"
powershell.exe -ExecutionPolicy Bypass -File "scripts\Install-Custom-Nodes.ps1"
pause