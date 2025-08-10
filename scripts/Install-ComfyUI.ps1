#Requires -RunAsAdministrator

# --- Script Parameters ---
param(
    [string]$InstallPath = $PSScriptRoot
)

#===========================================================================
# SECTION 1: SCRIPT CONFIGURATION & HELPER FUNCTIONS
#===========================================================================

# --- Clean up paths and set security protocol ---
$InstallPath = $InstallPath.Trim('"')
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- Define core paths ---
$comfyPath = Join-Path $InstallPath "ComfyUI"
$logPath = Join-Path $InstallPath "logs"
$logFile = Join-Path $logPath "install_log.txt"
$venvPython = Join-Path $comfyPath "venv\Scripts\python.exe"

# --- Load Dependencies from JSON ---
$dependenciesFile = Join-Path $InstallPath "csv\dependencies.json"
if (-not (Test-Path $dependenciesFile)) {
    Write-Host "FATAL: dependencies.json not found at '$dependenciesFile'. Cannot proceed." -ForegroundColor Red
    Read-Host "Press Enter to exit."
    exit 1
}
$dependencies = Get-Content -Raw -Path $dependenciesFile | ConvertFrom-Json

# --- Create Log Directory ---
if (-not (Test-Path $logPath)) {
    New-Item -ItemType Directory -Force -Path $logPath | Out-Null
}

# --- Helper functions ---
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

function Download-File {
    param([string]$Uri, [string]$OutFile)
    if (Test-Path $OutFile) {
        Write-Log "Skipping: $((Split-Path $OutFile -Leaf)) (already exists)." -Color Gray
        return
    }
    $modernUserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
    $fileName = Split-Path -Path $Uri -Leaf
    if (Get-Command 'aria2c' -ErrorAction SilentlyContinue) {
        Write-Log "  - Downloading with Aria2: $fileName"
        $aria_args = "--disable-ipv6 -c -x 16 -s 16 -k 1M --user-agent=`"$modernUserAgent`" --dir=`"$((Split-Path $OutFile -Parent))`" --out=`"$((Split-Path $OutFile -Leaf))`" `"$Uri`""
        Invoke-AndLog "aria2c" $aria_args
    } else {
        Write-Log "Aria2 not found. Falling back to standard download: $fileName" -Color Yellow
        Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UserAgent $modernUserAgent
    }
}

function Install-Binary-From-Zip {
    param($ToolConfig)
    Write-Log "--- Starting $($ToolConfig.name) binary installation ---" -Color Magenta
    $destFolder = $ToolConfig.install_path
    if (-not (Test-Path $destFolder)) { New-Item -ItemType Directory -Force -Path $destFolder | Out-Null }
    
    $zipPath  = Join-Path $env:TEMP "$($ToolConfig.name)_temp.zip"
    Download-File -Uri $ToolConfig.url -OutFile $zipPath
    Write-Log "Extracting zip file to $destFolder..."
    Expand-Archive -Path $zipPath -DestinationPath $destFolder -Force
    
    # Handle cases where zip extracts to a subfolder
    $extractedSubfolder = Get-ChildItem -Path $destFolder -Directory | Where-Object { $_.Name -like "*$($ToolConfig.version)*" } | Select-Object -First 1
    if ($null -ne $extractedSubfolder) {
        Write-Log "  - Moving contents from $($extractedSubfolder.FullName) to $destFolder"
        Move-Item -Path (Join-Path $extractedSubfolder.FullName "*") -Destination $destFolder -Force
        Remove-Item -Path $extractedSubfolder.FullName -Recurse -Force
    }

    $envScope = "User"
    $oldPath = [System.Environment]::GetEnvironmentVariable("Path", $envScope)
    if ($oldPath -notlike "*$destFolder*") {
        Write-Log "Adding '$destFolder' to user PATH..."
        $newPath = $oldPath + ";$destFolder"
        [System.Environment]::SetEnvironmentVariable("Path", $newPath, $envScope)
        $env:Path = $newPath # Update for current session
        Write-Log "PATH updated. $($ToolConfig.name) will be available immediately."
    }
    Write-Log "--- $($ToolConfig.name) binary installation complete ---" -Color Magenta
}

function Refresh-Path {
    Write-Log "  - Refreshing PATH environment variable for the current session..." -Color DarkGray
    $env:Path = "$([System.Environment]::GetEnvironmentVariable("Path", "Machine"));$([System.Environment]::GetEnvironmentVariable("Path", "User"))"
}

#===========================================================================
# SECTION 2: MAIN SCRIPT EXECUTION
#===========================================================================

Clear-Host
# --- Banner ---
Write-Log "-------------------------------------------------------------------------------"
$asciiBanner = @'
                      __  __               ___    _ ____  ______
                     / / / /___ ___  ___  /   |  (_) __ \/_  __/
                    / / / / __ `__ \/ _ \/ /| | / / /_/ / / / 
                   / /_/ / / / / / /  __/ ___ |/ / _, _/ / /
                   \____/_/ /_/ /_/\___/_/  |_/_/_/ |_| /_/
'@
Write-Host $asciiBanner -ForegroundColor Cyan
Write-Log "-------------------------------------------------------------------------------"
Write-Log "                           ComfyUI - Auto-Installer                            " -Color Yellow
Write-Log "                                 Version 3.2                                   " -Color White
Write-Log "-------------------------------------------------------------------------------"

# --- Step 0: CUDA Check (Same as before) ---
Write-Log "`nStep 0: Checking for CUDA 12.9 Toolkit..." -Color Yellow
# ... (This section doesn't depend on the JSON file, so it can remain as is)
$cudaFound = $false
$nvccExe = Get-Command nvcc -ErrorAction SilentlyContinue

if ($nvccExe) {
    $versionOutput = (nvcc --version 2>&1)
    if ($versionOutput -join "`n" -like "*release 12.9*") {
        Write-Log "  - Found CUDA Toolkit 12.9." -Color Green
        $cudaFound = $true
    } else {
        Write-Log "  - An incorrect version of CUDA Toolkit was found." -Color Yellow
        Write-Log ($versionOutput | Select-Object -First 4)
    }
} else {
    Write-Log "  - CUDA Toolkit (nvcc) not found in PATH." -Color Yellow
}

if (-not $cudaFound) {
    Write-Log "--------------------------------- WARNING ---------------------------------" -Color Red
    Write-Log "NVIDIA CUDA Toolkit v12.9 is not detected on your system." -Color Red
    Write-Log "It is required for building some modules and for full performance." -Color Yellow
    Write-Log "Please download and install it manually from this official link:" -Color Yellow
    Write-Log "https://developer.nvidia.com/cuda-12-9-1-download-archive" -Color Cyan
    Read-Host "`nAfter installation, please RESTART this script. Press Enter to continue without CUDA for now, or close this window to abort."
    Write-Log "---------------------------------------------------------------------------"
}


# --- Step 1: Install Python ---
Write-Log "`nStep 1: Checking for Python $($dependencies.tools.python.version)..." -Color Yellow

# NOUVEAU: On va stocker la commande exacte (ex: "py -3.12" ou "python") pour plus tard.
$pythonCommandToUse = $null 
$requiredPythonVersion = $dependencies.tools.python.version

# NOUVEAU: Méthode 1 (la plus fiable) - On essaie d'utiliser le lanceur py.exe
try {
    $versionString = (py "-$requiredPythonVersion" --version 2>&1)
    if ($versionString -like "Python $requiredPythonVersion*") {
        Write-Log "  - Found Python $requiredPythonVersion via 'py.exe' launcher: $versionString" -Color Green
        $pythonCommandToUse = "py -$requiredPythonVersion"
    }
}
catch {
    Write-Log "  - 'py -$requiredPythonVersion' failed. Checking default 'python' command..." -Color DarkGray
}

# NOUVEAU: Méthode 2 (repli) - Si la méthode 1 a échoué, on vérifie la commande 'python' par défaut
if (-not $pythonCommandToUse) {
    $pythonExe = Get-Command python -ErrorAction SilentlyContinue
    if ($pythonExe) {
        $versionString = (python --version 2>&1)
        Write-Log "  - Found default Python: $versionString"
        if ($versionString -like "Python $requiredPythonVersion*") {
            Write-Log "  - Default Python is the correct version." -Color Green
            $pythonCommandToUse = "python"
        }
    }
}

# NOUVEAU: Installation si aucune des méthodes n'a trouvé la bonne version
if (-not $pythonCommandToUse) {
    Write-Log "  - Python $requiredPythonVersion not found. Downloading and installing..." -Color Yellow
    $pythonInstallerPath = Join-Path $env:TEMP "python-installer.exe"
    Download-File -Uri $dependencies.tools.python.url -OutFile $pythonInstallerPath
    Write-Log "  - Running Python installer silently..."
    Start-Process -FilePath $pythonInstallerPath -ArgumentList $dependencies.tools.python.arguments -Wait
    Remove-Item $pythonInstallerPath
    Write-Log "  - Python installation complete." -Color Green
    Refresh-Path
    
    # Après installation, on utilise la commande la plus fiable
    $pythonCommandToUse = "py -$requiredPythonVersion"
    Write-Log "  - Python will now be invoked using '$pythonCommandToUse'." -Color Cyan
}

# --- Step 2: Install Required Tools ---
Write-Log "`nStep 2: Checking for required tools..." -Color Yellow
$gitTool = $dependencies.tools.git
$sevenZipTool = $dependencies.tools.seven_zip
$aria2Tool = $dependencies.tools.aria2
$ninjaTool = $dependencies.tools.ninja

if (-not (Get-Command 'aria2c' -ErrorAction SilentlyContinue)) { Install-Binary-From-Zip -ToolConfig @{name="Aria2"; version=$aria2Tool.version; url=$aria2Tool.url; install_path=$aria2Tool.install_path} } else { Write-Log "  - Aria2 is already installed." -Color Green }
if (-not (Get-Command 'ninja' -ErrorAction SilentlyContinue)) { Install-Binary-From-Zip -ToolConfig @{name="Ninja"; version=$ninjaTool.version; url=$ninjaTool.url; install_path=$ninjaTool.install_path} } else { Write-Log "  - Ninja is already installed." -Color Green }
if (-not (Test-Path $sevenZipTool.path)) {
    $sevenZipInstaller = Join-Path $env:TEMP "7z-installer.exe"; Download-File -Uri $sevenZipTool.url -OutFile $sevenZipInstaller; Start-Process -FilePath $sevenZipInstaller -ArgumentList $sevenZipTool.arguments -Wait; Remove-Item $sevenZipInstaller; Refresh-Path
} else { Write-Log "  - 7-Zip is already installed." -Color Green }
if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
    $gitInstaller = Join-Path $env:TEMP "Git-Installer.exe"; Download-File -Uri $gitTool.url -OutFile $gitInstaller; Start-Process -FilePath $gitInstaller -ArgumentList $gitTool.arguments -Wait; Remove-Item $gitInstaller; Refresh-Path
}
Invoke-AndLog "git" "config --system core.longpaths true"
Write-Log "  - Git is ready." -Color Green

# --- Step 3: Clone ComfyUI and create Venv ---
Write-Log "`nStep 3: Cloning ComfyUI and creating Virtual Environment..." -Color Yellow
if (-not (Test-Path $comfyPath)) {
    Write-Log "  - Cloning ComfyUI repository..."
    Invoke-AndLog "git" "clone $($dependencies.repositories.comfy_ui) `"$comfyPath`""
} else {
    Write-Log "  - ComfyUI directory already exists. Skipping clone." -Color Green
}

if (-not (Test-Path (Join-Path $comfyPath "venv"))) {
    Write-Log "  - Creating Python virtual environment (venv) using '$pythonCommandToUse'..."
    Push-Location $comfyPath
    
    # NOUVEAU: On utilise la commande validée à l'étape 1 pour créer le venv
    # On sépare l'exécutable de ses arguments (ex: "py" et "-3.12")
    $commandParts = $pythonCommandToUse.Split(' ', 2)
    $executable = $commandParts[0]
    $baseArguments = if ($commandParts.Length -gt 1) { $commandParts[1] } else { "" }
    
    Invoke-AndLog $executable "$baseArguments -m venv venv"

    Pop-Location
    Write-Log "  - Venv created successfully." -Color Green
} else {
    Write-Log "  - Venv already exists. Skipping creation." -Color Green
}
Invoke-AndLog "git" "config --global --add safe.directory `"$comfyPath`""

# --- Step 4: Install Python Dependencies ---
Write-Log "`nStep 4: Installing all Python dependencies into the venv..." -Color Yellow

# Upgrade pip and wheel
$pipUpgradePackages = $dependencies.pip_packages.upgrade -join " "
Write-Log "  - Upgrading pip and wheel..."
Invoke-AndLog "$venvPython" "-m pip install --upgrade $pipUpgradePackages"

# Install torch
Write-Log "  - Installing torch, torchvision, torchaudio for CUDA 12.9..."
Invoke-AndLog "$venvPython" "-m pip install --pre $($dependencies.pip_packages.torch.packages) --index-url $($dependencies.pip_packages.torch.index_url)"

# Install ComfyUI requirements.txt
Write-Log "  - Installing ComfyUI requirements..."
Invoke-AndLog "$venvPython" "-m pip install -r `"$comfyPath\$($dependencies.pip_packages.comfyui_requirements)`""

# Install standard packages from list
$standardPackages = $dependencies.pip_packages.standard -join " "
Write-Log "  - Installing standard packages: $standardPackages"
Invoke-AndLog "$venvPython" "-m pip install $standardPackages"

# Install packages from wheels
Write-Log "  - Installing packages from .whl files..."
foreach ($wheel in $dependencies.pip_packages.wheels) {
    Write-Log "    - Installing $($wheel.name)..."
    $wheelPath = Join-Path $InstallPath "$($wheel.name).whl"
    Download-File -Uri $wheel.url -OutFile $wheelPath
    Invoke-AndLog "$venvPython" "-m pip install `"$wheelPath`""
    Remove-Item $wheelPath -ErrorAction SilentlyContinue
}

# Install packages from git repositories
Write-Log "  - Installing packages from git repositories..."
foreach ($repo in $dependencies.pip_packages.git_repos) {
    Write-Log "    - Installing $($repo.name)... (This may take several minutes)"
    $installUrl = "git+$($repo.url)@$($repo.commit)"
    $pipArgs = "-m pip install `"$installUrl`""
    
    # Handle special cases
    if ($repo.name -eq "xformers") {
        $env:FORCE_CUDA = "1"
        $pipArgs = "-m pip install --no-build-isolation --verbose `"$installUrl`""
    }
    if ($repo.name -eq "apex") {
        $pipArgs = "-m pip install $($repo.install_options) `"$installUrl`""
    }
     if ($repo.name -eq "SageAttention") {
        $clonePath = Join-Path $InstallPath "SageAttention_temp"
        Invoke-AndLog "git" "clone $($repo.url) `"$clonePath`""
        Invoke-AndLog "$venvPython" "-m pip install --no-build-isolation --verbose `"$clonePath`""
        Remove-Item $clonePath -Recurse -Force -ErrorAction SilentlyContinue
        continue # Skip the generic pip install below
    }

    Invoke-AndLog "$venvPython" $pipArgs
    
    # Cleanup environment variables
    if ($repo.name -eq "xformers") {
        $env:FORCE_CUDA = $null
    }
}

# --- Step 5: Install Custom Nodes ---
Write-Log "`nStep 5: Installing custom nodes from CSV list..." -Color Yellow
$csvUrl = $dependencies.files.custom_nodes_csv.url
$csvPath = Join-Path $InstallPath $dependencies.files.custom_nodes_csv.destination
Download-File -Uri $csvUrl -OutFile $csvPath

if (-not (Test-Path $csvPath)) {
    Write-Log "  - ERROR: Could not download custom nodes list. Skipping." -Color Red
} else {
    $customNodes = Import-Csv -Path $csvPath
    $customNodesPath = Join-Path $comfyPath "custom_nodes" # Corrected path

    foreach ($node in $customNodes) {
        $nodeName = $node.Name
        $repoUrl = $node.RepoUrl
        $nodePath = Join-Path $customNodesPath $nodeName
        
        if ($node.Subfolder) {
            $nodePath = Join-Path $customNodesPath $node.Subfolder
        }

        if (-not (Test-Path $nodePath)) {
            Write-Log "  - Installing $nodeName..."
            Invoke-AndLog "git" "clone $repoUrl `"$nodePath`""
            if ($node.RequirementsFile) {
                $reqPath = Join-Path $nodePath $node.RequirementsFile
                if (Test-Path $reqPath) { Invoke-AndLog "$venvPython" "-m pip install -r `"$reqPath`"" }
            }
        } else {
            Write-Log "  - $nodeName (already exists, skipping)" -Color Green
        }
    }
}

# --- Step 6: Install VS Build Tools ---
Write-Log "`nStep 6: Installing Visual Studio Build Tools..." -Color Yellow
$vsTool = $dependencies.tools.vs_build_tools
$vsInstallerPath = Join-Path $env:TEMP "vs_buildtools.exe"
Download-File -Uri $vsTool.url -OutFile $vsInstallerPath
if (Test-Path $vsInstallerPath) {
    Write-Log "    - Running Visual Studio Build Tools installer... (This may take several minutes)"
    Invoke-AndLog $vsInstallerPath $vsTool.arguments
    Remove-Item $vsInstallerPath -ErrorAction SilentlyContinue
} else {
    Write-Log "  - FAILED to download Visual Studio Build Tools installer." -Color Red
}

# --- Step 7: Download Workflows & Settings ---
Write-Log "`nStep 7: Downloading Workflows & Settings..." -Color Yellow
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

# --- Step 8: Optional Model Pack Downloads ---
Write-Log "`nStep 8: Optional Model Pack Downloads..." -Color Yellow
$ModelsSource = Join-Path $comfyPath "models"
Copy-Item -Path $ModelsSource -Destination $InstallPath -Recurse
# This section remains largely the same as it calls other scripts
$modelPacks = @(
    @{Name="FLUX"; ScriptName="Download-FLUX-Models.ps1"},
    @{Name="WAN"; ScriptName="Download-WAN-Models.ps1"},
    @{Name="HIDREAM"; ScriptName="Download-HIDREAM-Models.ps1"},
    @{Name="LTXV"; ScriptName="Download-LTXV-Models.ps1"}
)
$scriptsSubFolder = Join-Path $InstallPath "scripts"
foreach ($pack in $modelPacks) {
    $scriptPath = Join-Path $scriptsSubFolder $pack.ScriptName
    if (-not (Test-Path $scriptPath)) { Write-Log "Model downloader script not found: '$($pack.ScriptName)'. Skipping." -Color Red; continue }
    $validInput = $false
    while (-not $validInput) {
        Write-Host "`n[33mWould you like to download $($pack.Name) models? (Y/N)[0m"
        $choice = Read-Host
        if ($choice -eq 'Y' -or $choice -eq 'y') {
            Write-Log "  - Launching downloader for $($pack.Name) models..." -Color Green
            & $scriptPath -InstallPath $InstallPath
            $validInput = $true
        } elseif ($choice -eq 'N' -or $choice -eq 'n') {
            Write-Log "  - Skipping download for $($pack.Name) models." -Color Gray
            $validInput = $true
        } else { Write-Host "  [31mInvalid choice. Please enter Y or N.[0m" }
    }
}

#===========================================================================
# FINALIZATION
#===========================================================================
Write-Log "-------------------------------------------------------------------------------" -Color Green
Write-Log "Installation of ComfyUI and all nodes is complete!" -Color Green
Read-Host "Press Enter to close this window."
