#Requires -RunAsAdministrator

<#
.SYNOPSIS
    A dedicated update script for the ComfyUI installation.
.DESCRIPTION
    This script performs a 'git pull' on the main ComfyUI repository,
    all custom nodes, and the workflow repository. It then updates all
    Python dependencies from any found 'requirements.txt' files and
    ensures pinned packages are at the correct version.
#>

#===========================================================================
# SECTION 1: SCRIPT CONFIGURATION & HELPER FUNCTIONS
#===========================================================================

# --- Paths and Configuration ---
$InstallPath = (Split-Path -Path $PSScriptRoot -Parent)
$comfyPath = Join-Path $InstallPath "ComfyUI"
$customNodesPath = Join-Path $InstallPath "custom_nodes"
$workflowPath = Join-Path $InstallPath "user\default\workflows\UmeAiRT-Workflow"
$venvPython = Join-Path $comfyPath "venv\Scripts\python.exe"
$logPath = Join-Path $InstallPath "logs"
$logFile = Join-Path $logPath "update_log.txt"

# --- Load Dependencies from JSON ---
$dependenciesFile = Join-Path $InstallPath "scripts\dependencies.json"
if (-not (Test-Path $dependenciesFile)) {
    Write-Host "FATAL: dependencies.json not found at '$dependenciesFile'. Cannot proceed." -ForegroundColor Red
    Read-Host "Press Enter to exit."
    exit 1
}
$dependencies = Get-Content -Raw -Path $dependenciesFile | ConvertFrom-Json

if (-not (Test-Path $logPath)) { New-Item -ItemType Directory -Force -Path $logPath | Out-Null }

# --- Helper Functions ---
function Write-Log {
    param([string]$Message, [string]$Color = "White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $formattedMessage = "[$timestamp] $Message"
    Write-Host $Message -ForegroundColor $Color
    Add-Content -Path $logFile -Value $formattedMessage
}

function Invoke-AndLog {
    param(
        [string]$File,
        [string]$Arguments
    )
    $tempLogFile = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString() + ".tmp")
    try {
        $commandToRun = "`"$File`" $Arguments"
        $cmdArguments = "/C `"$commandToRun > `"`"$tempLogFile`"`" 2>&1`""
        Start-Process -FilePath "cmd.exe" -ArgumentList $cmdArguments -Wait -WindowStyle Hidden
        if (Test-Path $tempLogFile) {
            $output = Get-Content $tempLogFile
            Add-Content -Path $logFile -Value $output
        }
    } catch {
        Write-Log "FATAL ERROR trying to execute command: $commandToRun" -Color Red
    } finally {
        if (Test-Path $tempLogFile) {
            Remove-Item $tempLogFile
        }
    }
}

function Invoke-Git-Pull {
    param([string]$DirectoryPath)
    if (Test-Path (Join-Path $DirectoryPath ".git")) {
        Write-Log "    - Updating $($DirectoryPath)..."
        Invoke-AndLog "git" "-C `"$DirectoryPath`" pull"
    } else {
        Write-Log "    - Skipping: Not a git repository." -Color Gray
    }
}

function Invoke-Pip-Install {
    param([string]$RequirementsPath)
    if (Test-Path $RequirementsPath) {
        Write-Log "  - Found requirements: $RequirementsPath. Updating..." -Color Cyan
        Invoke-AndLog "$venvPython" "-m pip install -r `"$RequirementsPath`""
    }
}
function Download-File {
    param([string]$Uri, [string]$OutFile)
    Write-Log "Downloading `"$($Uri.Split('/')[-1])`"" -Color DarkGray
    Invoke-AndLog "powershell.exe" "-NoProfile -Command `"[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '$Uri' -OutFile '$OutFile'`""
}
#===========================================================================
# SECTION 2: UPDATE PROCESS
#===========================================================================
Clear-Host
Write-Log "==============================================================================="
Write-Log "             Starting UmeAiRT ComfyUI Update Process" -Color Yellow
Write-Log "==============================================================================="

# --- 1. Update Git Repositories ---
Write-Log "`n[1/3] Updating all Git repositories..." -Color Green
Write-Log "  - Updating ComfyUI Core..."
Invoke-Git-Pull -DirectoryPath $comfyPath
Write-Log "  - Updating UmeAiRT Workflows..."
Invoke-Git-Pull -DirectoryPath $workflowPath

# --- 2. Update and Install Custom Nodes ---
Write-Log "`n[2/3] Updating and Installing Custom Nodes..." -Color Green
$csvUrl = $dependencies.files.custom_nodes_csv.url
$csvPath = Join-Path $InstallPath "scripts\custom_nodes.csv"

# Download the latest list of custom nodes
try {
    Download-File -Uri $csvUrl -OutFile $csvPath
} catch {
    Write-Log "  - ERROR: Could not download the custom nodes list. Skipping node updates." -Color Red
    return
}

# Update existing nodes
Write-Log "  - Updating existing custom nodes..."
Get-ChildItem -Path $customNodesPath -Directory | ForEach-Object {
    Invoke-Git-Pull -DirectoryPath $_.FullName
}

# Check for and install new nodes
Write-Log "  - Checking for new nodes to install..."
$customNodesList = Import-Csv -Path $csvPath
foreach ($node in $customNodesList) {
    $nodeName = $node.Name
    $nodePath = if ($node.Subfolder) { Join-Path $customNodesPath $node.Subfolder } else { Join-Path $customNodesPath $nodeName }

    if (-not (Test-Path $nodePath)) {
        Write-Log "    - New node found: $nodeName. Installing..." -Color Yellow
        Invoke-AndLog "git" "clone $($node.RepoUrl) `"$nodePath`""
    }
}

# --- 3. Update Python Dependencies ---
Write-Log "`n[3/3] Updating all Python dependencies..." -Color Green
Write-Log "  - Checking main ComfyUI requirements..."
Invoke-Pip-Install -RequirementsPath (Join-Path $comfyPath "requirements.txt")

Write-Log "  - Checking custom node requirements..."
Get-ChildItem -Path $customNodesPath -Directory -Recurse | ForEach-Object {
    $reqFile = Join-Path $_.FullName "requirements.txt"
    # Also check for common variations of the requirements file name
    $reqFileWithCupy = Join-Path $_.FullName "requirements-with-cupy.txt"
    if (Test-Path $reqFile) {
        Invoke-Pip-Install -RequirementsPath $reqFile
    }
    if (Test-Path $reqFileWithCupy) {
        Invoke-Pip-Install -RequirementsPath $reqFileWithCupy
    }
}

# Reinstall pinned packages to ensure correct versions
Write-Log "  - Ensuring pinned packages are at the correct version..."
$pinnedPackages = $dependencies.pip_packages.pinned -join " "
if ($pinnedPackages) {
    Invoke-AndLog "$venvPython" "-m pip install --force-reinstall $pinnedPackages"
}

# Reinstall wheel packages to ensure correct versions from JSON
Write-Log "  - Ensuring wheel packages are at the correct version..."
foreach ($wheel in $dependencies.pip_packages.wheels) {
    $wheelName = $wheel.name
    $wheelUrl = $wheel.url
    $localWheelPath = Join-Path $env:TEMP $wheelName

    Write-Log "    - Processing wheel: $wheelName" -Color Cyan

    try {
        # Download the wheel file
        Download-File -Uri $wheelUrl -OutFile $localWheelPath

        # Force reinstall the downloaded wheel
        if (Test-Path $localWheelPath) {
            Invoke-AndLog "$venvPython" "-m pip install --force-reinstall `"$localWheelPath`""
        } else {
            Write-Log "      - ERROR: Failed to download $wheelName" -Color Red
        }
    } catch {
        # On récupère le message d'erreur sur une ligne séparée pour éviter les erreurs de syntaxe
        $errorMessage = $_.Exception.Message
        Write-Log "      - FATAL ERROR during processing of $wheelName: $errorMessage" -Color Red
    } finally {
        # Clean up the downloaded wheel file
        if (Test-Path $localWheelPath) {
            Remove-Item $localWheelPath -Force
        }
    }
}

Write-Log "==============================================================================="
Write-Log "Update process complete!" -Color Yellow
Write-Log "==============================================================================="
Read-Host "Press Enter to exit."
