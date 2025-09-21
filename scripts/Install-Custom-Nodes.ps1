#Requires -RunAsAdministrator

<#
.SYNOPSIS
    A dedicated installer for ComfyUI custom nodes only.
.DESCRIPTION
    This script installs custom nodes for an existing ComfyUI installation.
    It expects ComfyUI to already be installed with a virtual environment.
#>

#===========================================================================
# SECTION 1: SCRIPT CONFIGURATION & HELPER FUNCTIONS
#===========================================================================

param(
    [string]$InstallPath = (Split-Path -Path $PSScriptRoot -Parent)
)

$comfyPath = Join-Path $InstallPath "ComfyUI"
$scriptPath = Join-Path $InstallPath "scripts"
$venvPython = Join-Path $comfyPath "venv\Scripts\python.exe"
$logPath = Join-Path $InstallPath "logs"
$logFile = Join-Path $logPath "install_custom_nodes_log.txt"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$dependenciesFile = Join-Path (Split-Path -Path $MyInvocation.MyCommand.Definition -Parent) "dependencies.json"
if (-not (Test-Path $dependenciesFile)) { 
    Write-Host "FATAL: dependencies.json not found..." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1 
}
$dependencies = Get-Content -Raw -Path $dependenciesFile | ConvertFrom-Json
if (-not (Test-Path $logPath)) { New-Item -ItemType Directory -Force -Path $logPath | Out-Null }

function Write-Log {
    param([string]$Message, [int]$Level = 1, [string]$Color = "Default")
    $prefix = ""
    $defaultColor = "White"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    switch ($Level) {
        -2 { $prefix = "" }
        0 {
            $wrappedMessage = "| $Message |"
            $separator = "=" * ($wrappedMessage.Length)
            $consoleMessage = "`n$separator`n$wrappedMessage`n$separator"
            $logMessage = "[$timestamp] $Message"
            $defaultColor = "Yellow"
        }
        1 { $prefix = "  - " }
        2 { $prefix = "    -> " }
        3 { $prefix = "      [INFO] " }
    }
    if ($Color -eq "Default") { $Color = $defaultColor }
    if ($Level -ne 0) {
        $logMessage = "[$timestamp] $($prefix.Trim()) $Message"
        $consoleMessage = "$prefix$Message"
    }
    Write-Host $consoleMessage -ForegroundColor $Color
    Add-Content -Path $logFile -Value $logMessage
}

function Invoke-AndLog {
    param(
        [string]$File,
        [string]$Arguments
    )
    
    # Path to a unique temporary log file.
    $tempLogFile = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString() + ".tmp")

    try {
        # Execute the command and redirect ALL of its output to the temporary file.
        $commandToRun = "`"$File`" $Arguments"
        $cmdArguments = "/C `"$commandToRun > `"`"$tempLogFile`"`" 2>&1`""
        $process = Start-Process -FilePath "cmd.exe" -ArgumentList $cmdArguments -Wait -WindowStyle Hidden -PassThru
        
        # Once the command is complete, read the temporary file.
        if (Test-Path $tempLogFile) {
            $output = Get-Content $tempLogFile
            # Append the output to the main log file.
            Add-Content -Path $logFile -Value $output
        }
        
        return $process.ExitCode
    } catch {
        Write-Log "FATAL ERROR trying to execute command: $commandToRun" -Color Red
        return 1
    } finally {
        # Ensure the temporary file is always deleted.
        if (Test-Path $tempLogFile) {
            Remove-Item $tempLogFile
        }
    }
}

function Download-File {
    param([string]$Uri, [string]$OutFile)
    Write-Log "Downloading `"$($Uri.Split('/')[-1])`"" -Level 2 -Color DarkGray
    $exitCode = Invoke-AndLog "powershell.exe" "-NoProfile -Command `"[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '$Uri' -OutFile '$OutFile'`""
    return $exitCode -eq 0
}

#===========================================================================
# SECTION 2: VALIDATION
#===========================================================================

Write-Log "ComfyUI Custom Nodes Installer" -Level 0

# Check if ComfyUI is installed
if (-not (Test-Path $comfyPath)) {
    Write-Log "ComfyUI installation not found at: $comfyPath" -Level 1 -Color Red
    Write-Log "Please install ComfyUI first using the main installer." -Level 1 -Color Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Check if virtual environment exists
if (-not (Test-Path $venvPython)) {
    Write-Log "Python virtual environment not found at: $venvPython" -Level 1 -Color Red
    Write-Log "Please ensure ComfyUI is properly installed with its virtual environment." -Level 1 -Color Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Test the virtual environment
try {
    $pythonVersion = & $venvPython --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Python execution failed"
    }
    Write-Log "Python virtual environment is functional: $pythonVersion" -Level 1 -Color Green
} catch {
    Write-Log "Python virtual environment is not functional" -Level 1 -Color Red
    Write-Log "Please reinstall ComfyUI to fix the virtual environment." -Level 1 -Color Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Log "ComfyUI installation found and virtual environment is functional" -Level 1 -Color Green

#===========================================================================
# SECTION 3: INSTALL CUSTOM NODES
#===========================================================================

Write-Log "Installing Custom Nodes" -Level 0

# Download the latest custom nodes CSV if needed
$csvUrl = $dependencies.files.custom_nodes_csv.url
$csvPath = Join-Path $InstallPath $dependencies.files.custom_nodes_csv.destination

if (-not (Test-Path $csvPath)) {
    Write-Log "Custom nodes CSV not found locally, downloading..." -Level 1 -Color Yellow
    if (-not (Download-File -Uri $csvUrl -OutFile $csvPath)) {
        Write-Log "Failed to download custom nodes CSV file" -Level 1 -Color Red
        Read-Host "Press Enter to exit"
        exit 1
    }
}

if (Test-Path $csvPath) {
    $customNodes = Import-Csv -Path $csvPath
    $customNodesPath = Join-Path $comfyPath "custom_nodes"
    
    if (-not (Test-Path $customNodesPath)) {
        New-Item -ItemType Directory -Force -Path $customNodesPath | Out-Null
    }
    
    $totalNodes = $customNodes.Count
    $currentNode = 0
    
    Write-Log "Found $totalNodes custom nodes to process" -Level 1
    
    foreach ($node in $customNodes) {
        $currentNode++
        $nodeName = $node.Name
        $repoUrl = $node.RepoUrl
        
        if ([string]::IsNullOrWhiteSpace($nodeName) -or [string]::IsNullOrWhiteSpace($repoUrl)) {
            Write-Log "Skipping invalid entry: Name='$nodeName', RepoUrl='$repoUrl'" -Level 2 -Color Yellow
            continue
        }
        
        Write-Log "[$currentNode/$totalNodes] Processing custom node: $nodeName" -Level 1
        
        $nodePath = if ($node.Subfolder) { 
            Join-Path $customNodesPath $node.Subfolder 
        } else { 
            Join-Path $customNodesPath $nodeName 
        }
        
        if (-not (Test-Path $nodePath)) {
            Write-Log "Cloning repository: $repoUrl" -Level 2
            $exitCode = Invoke-AndLog "git" "clone `"$repoUrl`" `"$nodePath`""
            
            if ($exitCode -eq 0) {
                Write-Log "Successfully cloned $nodeName" -Level 2 -Color Green
                
                # Install requirements if specified
                if ($node.RequirementsFile) {
                    $reqPath = Join-Path $nodePath $node.RequirementsFile
                    if (Test-Path $reqPath) {
                        Write-Log "Installing requirements: $($node.RequirementsFile)" -Level 2
                        $exitCode = Invoke-AndLog $venvPython "-m pip install -r `"$reqPath`""
                        
                        if ($exitCode -eq 0) {
                            Write-Log "Successfully installed requirements for $nodeName" -Level 2 -Color Green
                        } else {
                            Write-Log "Failed to install requirements for $nodeName" -Level 2 -Color Yellow
                        }
                    }
                }
            } else {
                Write-Log "Failed to clone $nodeName" -Level 2 -Color Red
            }
        } else {
            Write-Log "Custom node $nodeName already exists, skipping" -Level 2 -Color DarkGray
        }
    }
} else {
    Write-Log "Custom nodes CSV file not found: $csvPath" -Level 1 -Color Yellow
    Write-Log "Please ensure the custom_nodes.csv file exists or can be downloaded." -Level 1 -Color Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

#===========================================================================
# SECTION 4: COMPLETION
#===========================================================================

Write-Log "Custom Nodes Installation Complete!" -Level 0 -Color Green
Write-Log "All custom nodes have been installed to: $customNodesPath" -Level 1 -Color Green
Write-Log "You can now start ComfyUI to use the newly installed custom nodes." -Level 1 -Color Green

Write-Host ""
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host "                 Installation Summary" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host "• Custom nodes installed to: $customNodesPath" -ForegroundColor White
Write-Host "• Log file saved to: $logFile" -ForegroundColor White
Write-Host "• You can now start ComfyUI to use the new nodes" -ForegroundColor White
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host ""

Read-Host "Press Enter to close this window"