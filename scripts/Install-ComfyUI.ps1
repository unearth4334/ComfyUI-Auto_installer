#Requires -RunAsAdministrator

<#
.SYNOPSIS
    An automated installer for ComfyUI and its dependencies.
.DESCRIPTION
    This script streamlines the setup of ComfyUI, including Python, Git,
    all required Python packages, custom nodes, and optional models.
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
$logFile = Join-Path $logPath "install_log.txt"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$dependenciesFile = Join-Path (Split-Path -Path $MyInvocation.MyCommand.Definition -Parent) "dependencies.json"
if (-not (Test-Path $dependenciesFile)) { Write-Host "FATAL: dependencies.json not found..." -ForegroundColor Red; Read-Host; exit 1 }
$dependencies = Get-Content -Raw -Path $dependenciesFile | ConvertFrom-Json
if (-not (Test-Path $logPath)) { New-Item -ItemType Directory -Force -Path $logPath | Out-Null }

function Write-Log { param([string]$Message, [int]$Level = 1, [string]$Color = "Default"); $prefix = ""; $defaultColor = "White"; $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"; switch ($Level) {-2 { $prefix = "" } 0 { $global:currentStep++; $wrappedMessage = "| [Step $($global:currentStep)/$($global:totalSteps)] $Message |"; $separator = "=" * ($wrappedMessage.Length); $consoleMessage = "`n$separator`n$wrappedMessage`n$separator"; $logMessage = "[$timestamp] [Step $($global:currentStep)/$($global:totalSteps)] $Message"; $defaultColor = "Yellow" } 1 { $prefix = "  - " } 2 { $prefix = "    -> " } 3 { $prefix = "      [INFO] " } }; if ($Color -eq "Default") { $Color = $defaultColor }; if ($Level -ne 0) { $logMessage = "[$timestamp] $($prefix.Trim()) $Message"; $consoleMessage = "$prefix$Message" }; Write-Host $consoleMessage -ForegroundColor $Color; Add-Content -Path $logFile -Value $logMessage }
function Invoke-AndLog {
    param(
        [string]$File,
        [string]$Arguments,
        [switch]$Silent = $true # Par défaut, la fonction est silencieuse
    )
    $tempLogFile = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString() + ".tmp")
    $output = ""
    try {
        $commandToRun = "`"$File`" $Arguments"
        $cmdArguments = "/C `"$commandToRun > `"`"$tempLogFile`"`" 2>&1`""
        Start-Process -FilePath "cmd.exe" -ArgumentList $cmdArguments -Wait -WindowStyle Hidden
        if (Test-Path $tempLogFile) {
            $output = Get-Content $tempLogFile -Raw
            if (-not $Silent) { # On ne log que si demandé
                Add-Content -Path $logFile -Value $output
            }
        }
    } catch {
        Write-Log "FATAL ERROR trying to execute command: $commandToRun" -Level 1 -Color Red
    } finally {
        if (Test-Path $tempLogFile) {
            Remove-Item $tempLogFile
        }
    }
    return $output
}
function Download-File { param([string]$Uri, [string]$OutFile); Write-Log "Downloading `"$($Uri.Split('/')[-1])`"" -Level 2 -Color DarkGray; Invoke-AndLog "powershell.exe" "-NoProfile -Command `"[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '$Uri' -OutFile '$OutFile'`"" }
function Install-Binary-From-Zip { param($ToolConfig); Write-Log "Processing $($ToolConfig.name)..." -Level 1; $destFolder = $ToolConfig.install_path; if (-not (Test-Path $destFolder)) { New-Item -ItemType Directory -Force -Path $destFolder | Out-Null }; $zipPath = Join-Path $env:TEMP "$($ToolConfig.name)_temp.zip"; Download-File -Uri $ToolConfig.url -OutFile $zipPath; Write-Log "Extracting zip file" -Level 2; Expand-Archive -Path $zipPath -DestinationPath $destFolder -Force; $extractedSubfolder = Get-ChildItem -Path $destFolder -Directory | Select-Object -First 1; if (($null -ne $extractedSubfolder) -and ($extractedSubfolder.Name -ne "bin")) { Write-Log "Moving contents from subfolder to destination" -Level 3; Move-Item -Path (Join-Path $extractedSubfolder.FullName "*") -Destination $destFolder -Force; Remove-Item -Path $extractedSubfolder.FullName -Recurse -Force }; $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User"); if ($userPath -notlike "*$destFolder*") { Write-Log "Adding to user PATH" -Level 3; $newPath = $userPath + ";$destFolder"; [System.Environment]::SetEnvironmentVariable("Path", $newPath, "User"); $env:Path = $env:Path + ";$destFolder"} }
function Refresh-Path { $env:Path = "$([System.Environment]::GetEnvironmentVariable("Path", "Machine"));$([System.Environment]::GetEnvironmentVariable("Path", "User"))" }

#===========================================================================
# SECTION 2: MAIN SCRIPT EXECUTION
#===========================================================================
Write-Host "`n>>> CONFIRMATION: EXÉCUTION DU SCRIPT FINAL CORRIGÉ <<<`n" -ForegroundColor Green
Write-Log "DEBUG: Loaded tools config: $($dependencies.tools | ConvertTo-Json -Depth 3)" -Level 3
$global:totalSteps = 11
$global:currentStep = 0
$totalCores = [int]$env:NUMBER_OF_PROCESSORS
$optimalParallelJobs = [int][Math]::Floor(($totalCores * 3) / 4)
if ($optimalParallelJobs -lt 1) { $optimalParallelJobs = 1 }

Clear-Host
$banner = @"
-------------------------------------------------------------------------------
                      __  __           ___   _ ____  ______
                     / / / /___ ___  /   |  (_) __ \/_  __/
                    / / / / __ `__ \/ _ \/ /| | / / /_/ / / /
                   / /_/ / / / / / /  __/ ___ |/ / _, _/ / /
                   \____/_/ /_/ /_/\___/_/  |_/_/_/ |_| /_/
-------------------------------------------------------------------------------
                          ComfyUI - Auto-Installer
                                Version 3.2
-------------------------------------------------------------------------------
"@
Write-Log $banner -Level -2

# --- Step 1: CUDA Check ---
Write-Log "Checking CUDA Version Compatibility" -Level 0

# On détermine la version de CUDA requise par PyTorch depuis dependencies.json
$requiredCudaVersion = "Unknown"
$torchIndexUrl = $dependencies.pip_packages.torch.index_url
if ($torchIndexUrl -match "/cu(\d+)") {
    $cudaCode = $matches[1]
    if ($cudaCode.Length -eq 3) {
        $requiredCudaVersion = $cudaCode.Insert(2,'.')
    } elseif ($cudaCode.Length -eq 2) {
        $requiredCudaVersion = $cudaCode.Insert(1,'.')
    }
}
Write-Log "PyTorch requires CUDA Toolkit v$requiredCudaVersion" -Level 1

# On détecte la version réellement installée
$installedCudaVersion = $null
try {
    $nvccOutput = nvcc --version 2>&1
    if ($nvccOutput -match "release ([\d\.]+),") {
        $installedCudaVersion = $matches[1]
        Write-Log "Found installed CUDA Toolkit v$installedCudaVersion via nvcc." -Level 2
    }
} catch { Write-Log "nvcc not found, checking other methods..." -Level 3 }

if (-not $installedCudaVersion) {
    try {
        $cudaPath = (Get-ChildItem Env:CUDA_PATH).Value
        if ($cudaPath -match "\\v([\d\.]+)$") {
            $installedCudaVersion = $matches[1]
            Write-Log "Found installed CUDA Toolkit v$installedCudaVersion via CUDA_PATH." -Level 2
        }
    } catch { Write-Log "CUDA_PATH not found..." -Level 3 }
}

# --- VÉRIFICATION ET AVERTISSEMENT ---
if ($installedCudaVersion) {
    if ($installedCudaVersion -like "$requiredCudaVersion*") {
        Write-Log "Installed CUDA version ($installedCudaVersion) is compatible." -Level 1 -Color Green
    } else {
        Write-Log "WARNING: Installed CUDA version ($installedCudaVersion) does not match required version ($requiredCudaVersion)." -Level 1 -Color Yellow
        Write-Log "This may cause issues with PyTorch. It is recommended to install CUDA Toolkit $requiredCudaVersion." -Level 2 -Color Yellow
    }
} else {
    Write-Log "Could not determine installed CUDA Toolkit version. Please ensure v$requiredCudaVersion is installed." -Level 1 -Color Yellow
}

# --- Step 2: Python Check ---
Write-Log "Checking for Python $($dependencies.tools.python.version)" -Level 0
$pythonCommandToUse = $null; $requiredPythonVersion = $dependencies.tools.python.version
try { $versionString = (py "-$requiredPythonVersion" --version 2>&1); if ($versionString -like "Python $requiredPythonVersion*") { Write-Log "Found Python via 'py.exe' launcher" -Level 1 -Color Green; $pythonCommandToUse = "py -$requiredPythonVersion" } } catch { Write-Log "py.exe launcher check failed" -Level 3 }
if (-not $pythonCommandToUse) { $pythonExe = Get-Command python -ErrorAction SilentlyContinue; if ($pythonExe) { $versionString = (python --version 2>&1); Write-Log "Found default Python: $versionString" -Level 1; if ($versionString -like "Python $requiredPythonVersion*") { Write-Log "Default Python is the correct version" -Level 2 -Color Green; $pythonCommandToUse = "python" } } }
if (-not $pythonCommandToUse) { Write-Log "Python $requiredPythonVersion not found. Installing..." -Level 1 -Color Yellow; $pythonInstallerPath = Join-Path $env:TEMP "python-installer.exe"; Download-File -Uri $dependencies.tools.python.url -OutFile $pythonInstallerPath; Write-Log "Running installer..." -Level 2; Start-Process -FilePath $pythonInstallerPath -ArgumentList $dependencies.tools.python.arguments -Wait; Remove-Item $pythonInstallerPath; Refresh-Path; $pythonCommandToUse = "py -$requiredPythonVersion" }

# --- Step 3: Required Tools Check ---
Write-Log "Checking for Required Tools" -Level 0

# Cas spécifique pour Git (.exe installer)
$gitTool = $dependencies.tools.git
if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
    Write-Log "Git not found. Installing..." -Level 1 -Color Yellow
    $gitInstaller = Join-Path $env:TEMP "Git-Installer.exe"
    Download-File -Uri $gitTool.url -OutFile $gitInstaller
    Invoke-AndLog $gitInstaller $gitTool.arguments
    Remove-Item $gitInstaller -ErrorAction SilentlyContinue
    Refresh-Path
}
Invoke-AndLog "git" "config --system core.longpaths true"
Write-Log "Git is ready" -Level 1 -Color Green

# Cas spécifique pour 7-Zip (.exe installer) - Amélioré
$sevenZipTool = $dependencies.tools.seven_zip
$sevenZipExePath = "C:\Program Files\7-Zip\7z.exe"

# On vérifie d'abord le chemin d'installation par défaut ET ensuite le PATH
if (-not (Test-Path $sevenZipExePath) -and -not (Get-Command 7z.exe -ErrorAction SilentlyContinue)) {
    Write-Log "7-Zip not found. Installing..." -Level 1 -Color Yellow
    $sevenZipInstaller = Join-Path $env:TEMP "7z-Installer.exe"
    Download-File -Uri $sevenZipTool.url -OutFile $sevenZipInstaller
    Invoke-AndLog $sevenZipInstaller $sevenZipTool.arguments
    Remove-Item $sevenZipInstaller -ErrorAction SilentlyContinue
    Refresh-Path
}
Write-Log "7-Zip is ready" -Level 1 -Color Green

# Boucle générique pour les autres outils (archives .zip)
foreach ($toolProperty in $dependencies.tools.PSObject.Properties) {
    $toolName = $toolProperty.Name
    # On saute les outils déjà gérés
    if ($toolName -in @('python', 'git', 'vs_build_tools', 'seven_zip')) { continue }

    $toolConfig = $toolProperty.Value
    
    # --- CORRECTION APPLIQUÉE ICI ---
    # On gère le nom d'exécutable spécifique à aria2
    $exeName = if ($toolName -eq "aria2") { "aria2c.exe" } else { "$($toolConfig.name).exe" }
    
    # On utilise le nom correct dans le chemin de détection
    $exePath = Join-Path $toolConfig.install_path $exeName

    # La détection est maintenant fiable
    if (-not (Test-Path $exePath) -and -not (Get-Command $exeName -ErrorAction SilentlyContinue)) {
        Install-Binary-From-Zip -ToolConfig $toolConfig
    } else {
        Write-Log "$($toolConfig.name) is already installed" -Level 1 -Color Green
    }
}
# --- Step 4: Clone ComfyUI and create Venv ---
Write-Log "Cloning ComfyUI & Creating Virtual Environment" -Level 0
if (-not (Test-Path $comfyPath)) {
    Write-Log "Cloning ComfyUI repository from $($dependencies.repositories.comfyui.url)..." -Level 1
    $cloneArgs = "clone $($dependencies.repositories.comfyui.url) `"$comfyPath`""
    Invoke-AndLog "git" $cloneArgs

    # On vérifie si le clonage a réussi avant de continuer
    if (-not (Test-Path $comfyPath)) {
        Write-Log "FATAL: ComfyUI cloning failed. The directory was not created. Please check the logs." -Level 0 -Color Red
        Read-Host "Press Enter to exit."
        exit 1
    }
} else {
    Write-Log "ComfyUI directory already exists" -Level 1 -Color Green
}
# Create the 'user' directory to prevent first-launch database errors
$userFolderPath = Join-Path $comfyPath "user"
if (-not (Test-Path $userFolderPath)) {
    Write-Log "Creating 'user' directory to prevent database issues" -Level 1
    New-Item -Path $userFolderPath -ItemType Directory | Out-Null
}
if (-not (Test-Path (Join-Path $comfyPath "venv"))) { Write-Log "Creating Python virtual environment..." -Level 1; Push-Location $comfyPath; $commandParts = $pythonCommandToUse.Split(' ', 2); $executable = $commandParts[0]; $baseArguments = if ($commandParts.Length -gt 1) { $commandParts[1] } else { "" }; Invoke-AndLog $executable "$baseArguments -m venv venv"; Pop-Location; Write-Log "Venv created successfully" -Level 2 -Color Green } else { Write-Log "Venv already exists" -Level 1 -Color Green }
Invoke-AndLog "git" "config --global --add safe.directory `"$comfyPath`""

# --- Step 5: Install Core Dependencies ---
Write-Log "Installing Core Dependencies" -Level 0
Write-Log "Upgrading pip and wheel" -Level 1; Invoke-AndLog "$venvPython" "-m pip install --upgrade $($dependencies.pip_packages.upgrade -join ' ')"
Write-Log "Installing torch packages" -Level 1; Invoke-AndLog "$venvPython" "-m pip install --pre $($dependencies.pip_packages.torch.packages) --index-url $($dependencies.pip_packages.torch.index_url)"
Write-Log "Installing ComfyUI requirements" -Level 1; Invoke-AndLog "$venvPython" "-m pip install -r `"$comfyPath\$($dependencies.pip_packages.comfyui_requirements)`""

# --- Step 6: Install Custom Nodes ---
Write-Log "Installing Custom Nodes" -Level 0
$csvUrl = $dependencies.files.custom_nodes_csv.url; $csvPath = Join-Path $InstallPath $dependencies.files.custom_nodes_csv.destination; Download-File -Uri $csvUrl -OutFile $csvPath
$customNodes = Import-Csv -Path $csvPath; $customNodesPath = Join-Path $InstallPath "custom_nodes"
foreach ($node in $customNodes) { $nodeName = $node.Name; $repoUrl = $node.RepoUrl; $nodePath = if ($node.Subfolder) { Join-Path $customNodesPath $node.Subfolder } else { Join-Path $customNodesPath $nodeName }; if (-not (Test-Path $nodePath)) { Write-Log "Installing $nodeName" -Level 1; Invoke-AndLog "git" "clone $repoUrl `"$nodePath`""; if ($node.RequirementsFile) { $reqPath = Join-Path $nodePath $node.RequirementsFile; if (Test-Path $reqPath) { Write-Log "Installing requirements for $nodeName" -Level 2; Invoke-AndLog "$venvPython" "-m pip install -r `"$reqPath`"" } } } else { Write-Log "$nodeName (already exists, skipping)" -Level 1 -Color Green } }

# --- Step 7: Install Final Python Dependencies ---
Write-Log "Installing Final Python Dependencies" -Level 0
Write-Log "Installing standard packages..." -Level 1; Invoke-AndLog "$venvPython" "-m pip install $($dependencies.pip_packages.standard -join ' ')"
Write-Log "Installing packages from .whl files..." -Level 1
foreach ($wheel in $dependencies.pip_packages.wheels) { Write-Log "Installing $($wheel.name)" -Level 2; $wheelPath = Join-Path $InstallPath "$($wheel.name).whl"; Download-File -Uri $wheel.url -OutFile $wheelPath; Invoke-AndLog "$venvPython" "-m pip install `"$wheelPath`""; Remove-Item $wheelPath -ErrorAction SilentlyContinue }
Write-Log "Installing packages from git repositories..." -Level 1
foreach ($repo in $dependencies.pip_packages.git_repos) { Write-Log "Installing $($repo.name)..." -Level 2; $installUrl = "git+$($repo.url)@$($repo.commit)"; $pipArgs = "-m pip install `"$installUrl`""; $useOptimizations = $false; $originalPath = $env:Path; if ($repo.name -eq "xformers" -or $repo.name -eq "SageAttention") { $useOptimizations = $true; $env:PATH = "$($dependencies.tools.ccache.install_path);$originalPath"; $env:CC = "cl.exe"; $env:CXX = "cl.exe"; $env:XFORMERS_BUILD_TYPE = "Release"; $env:MAX_JOBS = $optimalParallelJobs; Write-Log "Build optimizations ENABLED (ccache, Release mode, $optimalParallelJobs jobs)" -Level 3 -Color Cyan }; if ($repo.name -eq "xformers") { $env:FORCE_CUDA = "1"; $pipArgs = "-m pip install --no-build-isolation --verbose `"$installUrl`"" }; if ($repo.name -eq "apex") { $pipArgs = "-m pip install $($repo.install_options) `"$installUrl`"" }; if ($repo.name -eq "SageAttention") { $clonePath = Join-Path $InstallPath "SageAttention_temp"; Invoke-AndLog "git" "clone $($repo.url) `"$clonePath`""; Invoke-AndLog "$venvPython" "-m pip install --no-build-isolation --verbose `"$clonePath`""; Remove-Item $clonePath -Recurse -Force -ErrorAction SilentlyContinue; continue }; Invoke-AndLog "$venvPython" $pipArgs; if ($useOptimizations) { $env:Path = $originalPath; $env:CC = $null; $env:CXX = $null; $env:XFORMERS_BUILD_TYPE = $null; $env:MAX_JOBS = $null; Write-Log "Build optimizations DISABLED" -Level 3 }; if ($repo.name -eq "xformers") { $env:FORCE_CUDA = $null } }

# --- Step 8: Install VS Build Tools ---
Write-Log "Checking for VS Build Tools" -Level 0
$vsTool = $dependencies.tools.vs_build_tools
if (-not (Test-Path $vsTool.install_path)) { Write-Log "VS Build Tools not found. Installing..." -Level 1 -Color Yellow; $vsInstaller = Join-Path $env:TEMP "vs_buildtools.exe"; Download-File -Uri $vsTool.url -OutFile $vsInstaller; Start-Process -FilePath $vsInstaller -ArgumentList $vsTool.arguments -Wait; Remove-Item $vsInstaller } else { Write-Log "Visual Studio Build Tools are already installed" -Level 1 -Color Green }

# --- Step 9: Download Workflows & Settings ---
Write-Log "Downloading Workflows & Settings..." -Level 0
$settingsFile = $dependencies.files.comfy_settings
$settingsDest = Join-Path $InstallPath $settingsFile.destination
$settingsDir = Split-Path $settingsDest -Parent
if (-not (Test-Path $settingsDir)) { New-Item -Path $settingsDir -ItemType Directory -Force | Out-Null }
Download-File -Uri $settingsFile.url -OutFile $settingsDest

$workflowRepo = $dependencies.repositories.workflows
$workflowCloneDest = Join-Path $InstallPath "user\default\workflows\UmeAiRT-Workflow"
if (-not (Test-Path $workflowCloneDest)) { 
    Invoke-AndLog "git" "clone $workflowRepo `"$workflowCloneDest`"" 
}

# --- Step 10: Optional Model Pack Downloads ---
Write-Log "Optional Model Pack Downloads" -Level 0

# Copy the base models directory if it exists
$ModelsSource = Join-Path $comfyPath "models"
if (Test-Path $ModelsSource) {
    Write-Log "Copying base models directory..." -Level 1
    Copy-Item -Path $ModelsSource -Destination $InstallPath -Recurse -Force
}

$modelPacks = @(
    @{Name="FLUX"; ScriptName="Download-FLUX-Models.ps1"},
    @{Name="WAN"; ScriptName="Download-WAN-Models.ps1"},
    @{Name="HIDREAM"; ScriptName="Download-HIDREAM-Models.ps1"},
    @{Name="LTXV"; ScriptName="Download-LTXV-Models.ps1"}
)
$scriptsSubFolder = Join-Path $InstallPath "scripts"

foreach ($pack in $modelPacks) {
    $scriptPath = Join-Path $scriptsSubFolder $pack.ScriptName
    if (-not (Test-Path $scriptPath)) {
        Write-Log "Model downloader script not found: '$($pack.ScriptName)'. Skipping." -Level 1 -Color Red
        continue 
    }

    $validInput = $false
    while (-not $validInput) {
        # On utilise Write-Log pour la question, en gardant la couleur
        Write-Log "Would you like to download $($pack.Name) models? (Y/N)" -Level 1 -Color Yellow
        $choice = Read-Host

        if ($choice -eq 'Y' -or $choice -eq 'y') {
            Write-Log "Launching downloader for $($pack.Name) models..." -Level 2 -Color Green
            # L'exécution du script externe affichera ses propres logs
            & $scriptPath -InstallPath $InstallPath
            $validInput = $true
        } elseif ($choice -eq 'N' -or $choice -eq 'n') {
            Write-Log "Skipping download for $($pack.Name) models." -Level 2
            $validInput = $true
        } else {
            # On utilise Write-Log pour le message d'erreur
            Write-Log "Invalid choice. Please enter Y or N." -Level 2 -Color Red
        }
    }
}
# --- Step 11: Finalize Permissions ---
Write-Log "Finalizing Folder Permissions" -Level 0
Write-Log "Applying permissions for standard users to the installation directory..." -Level 1
Write-Log "This will allow ComfyUI to run without administrator rights." -Level 2
Invoke-AndLog "icacls" "`"$InstallPath`" /grant `"BUILTIN\Users`":(OI)(CI)F /T"
#===========================================================================
# FINALIZATION
#===========================================================================
Remove-Item -Path $scriptPath -Recurse -Force
Write-Log "-------------------------------------------------------------------------------" -Color Green
Write-Log "Installation of ComfyUI and all nodes is complete!" -Color Green
Read-Host "Press Enter to close this window."
