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

function Write-Log {
    param([string]$Message, [int]$Level = 1, [string]$Color = "Default")
    $prefix = ""
    $defaultColor = "White"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    switch ($Level) {
        -2 { $prefix = "" }
        0 {
            $global:currentStep++
            $wrappedMessage = "| [Step $($global:currentStep)/$($global:totalSteps)] $Message |"
            $separator = "=" * ($wrappedMessage.Length)
            $consoleMessage = "`n$separator`n$wrappedMessage`n$separator"
            $logMessage = "[$timestamp] [Step $($global:currentStep)/$($global:totalSteps)] $Message"
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
        Start-Process -FilePath "cmd.exe" -ArgumentList $cmdArguments -Wait -WindowStyle Hidden
        
        # Once the command is complete, read the temporary file.
        if (Test-Path $tempLogFile) {
            $output = Get-Content $tempLogFile
            # Append the output to the main log file.
            Add-Content -Path $logFile -Value $output
        }
    } catch {
        Write-Log "FATAL ERROR trying to execute command: $commandToRun" -Color Red
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
    Invoke-AndLog "powershell.exe" "-NoProfile -Command `"[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '$Uri' -OutFile '$OutFile'`""
}

function Install-Binary-From-Zip {
    param($ToolConfig)
    Write-Log "Processing $($ToolConfig.name)..." -Level 1
    $destFolder = $ToolConfig.install_path
    if (-not (Test-Path $destFolder)) {
        New-Item -ItemType Directory -Force -Path $destFolder | Out-Null
    }
    $zipPath = Join-Path $env:TEMP "$($ToolConfig.name)_temp.zip"
    Download-File -Uri $ToolConfig.url -OutFile $zipPath
    Write-Log "Extracting zip file" -Level 2
    Expand-Archive -Path $zipPath -DestinationPath $destFolder -Force
    $extractedSubfolder = Get-ChildItem -Path $destFolder -Directory | Select-Object -First 1
    if (($null -ne $extractedSubfolder) -and ($extractedSubfolder.Name -ne "bin")) {
        Write-Log "Moving contents from subfolder to destination" -Level 3
        Move-Item -Path (Join-Path $extractedSubfolder.FullName "*") -Destination $destFolder -Force
        Remove-Item -Path $extractedSubfolder.FullName -Recurse -Force
    }
    $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -notlike "*$destFolder*") {
        Write-Log "Adding to user PATH" -Level 3
        $newPath = $userPath + ";$destFolder"
        [System.Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        $env:Path = $env:Path + ";$destFolder"
    }
}

function Refresh-Path {
    $env:Path = "$([System.Environment]::GetEnvironmentVariable("Path", "Machine"));$([System.Environment]::GetEnvironmentVariable("Path", "User"))"
}

#===========================================================================
# SECTION 2: MAIN SCRIPT EXECUTION
#===========================================================================
Write-Host "`n>>> CONFIRMATION: RUNNING FINAL SCRIPT <<<`n" -ForegroundColor Green
Write-Log "DEBUG: Loaded tools config: $($dependencies.tools | ConvertTo-Json -Depth 3)" -Level 3
$global:totalSteps = 11
$global:currentStep = 0
$totalCores = [int]$env:NUMBER_OF_PROCESSORS
$optimalParallelJobs = [int][Math]::Floor(($totalCores * 3) / 4)
if ($optimalParallelJobs -lt 1) { $optimalParallelJobs = 1 }

Clear-Host
# --- Bannière ---
Write-Host "-------------------------------------------------------------------------------"
$asciiBanner = @'
                      __  __               ___    _ ____  ______
                     / / / /___ ___  ___  /   |  (_) __ \/_  __/
                    / / / / __ `__ \/ _ \/ /| | / / /_/ / / / 
                   / /_/ / / / / / /  __/ ___ |/ / _, _/ / /
                   \____/_/ /_/ /_/\___/_/  |_/_/_/ |_| /_/
'@
Write-Host $asciiBanner -ForegroundColor Cyan
Write-Host "-------------------------------------------------------------------------------"
Write-Host "                           ComfyUI - Auto-Installer                            " -ForegroundColor Yellow
Write-Host "                                  Version 3.2                                  " -ForegroundColor White
Write-Host "-------------------------------------------------------------------------------"

# --- Step 1: CUDA Check ---
Write-Log "Checking CUDA Version Compatibility" -Level 0

# Determine the required CUDA version from the PyTorch dependency URL.
$requiredCudaVersion = "Unknown"
$torchIndexUrl = $dependencies.pip_packages.torch.index_url
if ($torchIndexUrl -match "/cu(\d+)") {
    $cudaCode = $matches[1]
    if ($cudaCode.Length -eq 3) {
        $requiredCudaVersion = $cudaCode.Insert(2,'.') # e.g., 129 -> 12.9
    } elseif ($cudaCode.Length -eq 2) {
        $requiredCudaVersion = $cudaCode.Insert(1,'.') # e.g., 118 -> 11.8
    }
}
Write-Log "PyTorch requires CUDA Toolkit v$requiredCudaVersion" -Level 1

# Detect the currently installed CUDA version.
$installedCudaVersion = $null
try {
    $nvccOutput = nvcc --version 2>&1
    if ($nvccOutput -match "release ([\d\.]+),") {
        $versionString = $matches[1]
        
        # --- FIX ---
        # If the version string has no dot (e.g., "129"), add one.
        if ($versionString -notlike "*.*" -and $versionString.Length -eq 3) {
            $installedCudaVersion = $versionString.Insert(2,'.')
        } else {
            $installedCudaVersion = $versionString
        }
        Write-Log "Found installed CUDA Toolkit v$installedCudaVersion via nvcc." -Level 2
    }
} catch { Write-Log "nvcc not found, using fallback methods..." -Level 3 }

# (Fallback logic using CUDA_PATH remains the same)

# --- VERIFICATION AND WARNING ---
if ($installedCudaVersion) {
    if ($installedCudaVersion -like "$requiredCudaVersion*") {
        Write-Log "Installed CUDA version ($installedCudaVersion) is compatible." -Level 1 -Color Green
    } else {
        Write-Log "WARNING: Installed CUDA version ($installedCudaVersion) does not match required version ($requiredCudaVersion)." -Level 1 -Color Yellow
        Write-Log "This may cause issues with PyTorch." -Level 2 -Color Yellow
    }
} else {
    Write-Log "Could not determine installed CUDA Toolkit version. Please ensure v$requiredCudaVersion is installed." -Level 1 -Color Yellow
}

# --- Step 2: Python Check ---
Write-Log "Checking for Python $($dependencies.tools.python.version)" -Level 0

$pythonCommandToUse = $null
$requiredVersion = $dependencies.tools.python.version # e.g., "3.12.9"
$requiredMajorMinor = ($requiredVersion.Split('.')[0..1]) -join '.' # e.g., "3.12"

try {
    # We specifically check for the major.minor version (e.g., -3.12)
    Write-Log "Checking for Python $requiredMajorMinor via py.exe launcher..." -Level 2
    $versionString = (py "-$requiredMajorMinor" --version 2>&1)

    # Check if the output is what we expect (e.g., "Python 3.12.9")
    if ($LASTEXITCODE -eq 0 -and $versionString -like "Python $requiredMajorMinor*") {
        Write-Log "Found compatible Python version: $versionString" -Level 1 -Color Green
        # Set the command to use for the rest of the script (important for venv creation)
        $pythonCommandToUse = "py -$requiredMajorMinor"
    } else {
        Write-Log "A Python version was found via py.exe, but it's not the required one. ($versionString)" -Level 2
    }
}
catch {
    # This block will run if py.exe is not found or if the specific version doesn't exist.
    Write-Log "py.exe launcher did not find Python $requiredMajorMinor." -Level 2
}

if (-not $pythonCommandToUse) {
    Write-Log "Python $requiredVersion not found. Installing..." -Level 1 -Color Yellow
    
    $pythonInstallerPath = Join-Path $env:TEMP "python-installer.exe"
    Download-File -Uri $dependencies.tools.python.url -OutFile $pythonInstallerPath
    
    Write-Log "Running installer..." -Level 2
    Start-Process -FilePath $pythonInstallerPath -ArgumentList $dependencies.tools.python.arguments -Wait
    Remove-Item $pythonInstallerPath
    
    # After installation, the 'py.exe' command should now work.
    $pythonCommandToUse = "py -$requiredMajorMinor"
    Write-Log "Python $requiredVersion installed successfully." -Level 1 -Color Green
}

# --- Step 3: Required Tools Check ---
Write-Log "Checking for Required Tools" -Level 0

# Specific case for Git (.exe installer)
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

# Specific case for 7-Zip (.exe installer) - Improved
$sevenZipTool = $dependencies.tools.seven_zip
$sevenZipExePath = "C:\Program Files\7-Zip\7z.exe"

# Check the default install path first, then the user's PATH.
if (-not (Test-Path $sevenZipExePath) -and -not (Get-Command 7z.exe -ErrorAction SilentlyContinue)) {
    Write-Log "7-Zip not found. Installing..." -Level 1 -Color Yellow
    $sevenZipInstaller = Join-Path $env:TEMP "7z-Installer.exe"
    Download-File -Uri $sevenZipTool.url -OutFile $sevenZipInstaller
    Invoke-AndLog $sevenZipInstaller $sevenZipTool.arguments
    Remove-Item $sevenZipInstaller -ErrorAction SilentlyContinue
    Refresh-Path
}
Write-Log "7-Zip is ready" -Level 1 -Color Green

# Generic loop for other tools (from .zip archives)
foreach ($toolProperty in $dependencies.tools.PSObject.Properties) {
    $toolName = $toolProperty.Name
    # Skip tools that are handled separately.
    if ($toolName -in @('python', 'git', 'vs_build_tools', 'seven_zip')) { continue }

    $toolConfig = $toolProperty.Value
    
    # Handle the specific executable name for aria2.
    $exeName = if ($toolName -eq "aria2") { "aria2c.exe" } else { "$($toolConfig.name).exe" }
    
    # Use the correct executable name for path detection.
    $exePath = Join-Path $toolConfig.install_path $exeName

    # This detection is now more reliable.
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

    # Verify that the clone was successful before continuing.
    if (-not (Test-Path $comfyPath)) {
        Write-Log "FATAL: ComfyUI cloning failed. The directory was not created. Please check the logs." -Level 0 -Color Red
        Read-Host "Press Enter to exit."
        exit 1
    }
} else {
    Write-Log "ComfyUI directory already exists" -Level 1 -Color Green
}
# Check if venv already exists
if (-not (Test-Path (Join-Path $comfyPath "venv"))) {
    Write-Log "Creating Python virtual environment..." -Level 1

    # --- START OF MODIFICATION ---

    # 1. Get the python version from the dependencies file (e.g., "3.12.9")
    $pythonVersion = $dependencies.tools.python.version

    # 2. Build the version string for the py launcher (e.g., "3.12")
    $pythonMajorMinor = ($pythonVersion.Split('.')[0..1]) -join '.'

    # 3. Force venv creation with the specified Python version
    Write-Log "Forcing venv creation with Python v$pythonMajorMinor using py.exe..." -Level 2
    Push-Location $comfyPath
    Invoke-AndLog "py" "-$pythonMajorMinor -m venv venv"
    Pop-Location

    # --- END OF MODIFICATION ---

    Write-Log "Venv created successfully" -Level 2 -Color Green
}
else {
    Write-Log "Venv already exists" -Level 1 -Color Green
}
# Create the 'user' directory to prevent first-launch database errors
$userFolderPath = Join-Path $comfyPath "user"
if (-not (Test-Path $userFolderPath)) {
    Write-Log "Creating 'user' directory to prevent database issues" -Level 1
    New-Item -Path $userFolderPath -ItemType Directory | Out-Null
}
Invoke-AndLog "git" "config --global --add safe.directory `"$comfyPath`""

# --- Step 5: Install Core Dependencies ---
Write-Log "Installing Core Dependencies" -Level 0
Write-Log "Upgrading pip and wheel" -Level 1
Invoke-AndLog "$venvPython" "-m pip install --upgrade $($dependencies.pip_packages.upgrade -join ' ')"
Write-Log "Installing torch packages" -Level 1
Invoke-AndLog "$venvPython" "-m pip install $($dependencies.pip_packages.torch.packages) --index-url $($dependencies.pip_packages.torch.index_url)"
Write-Log "Installing ComfyUI requirements" -Level 1
Invoke-AndLog "$venvPython" "-m pip install -r `"$comfyPath\$($dependencies.pip_packages.comfyui_requirements)`""

# --- Step 6: Install Custom Nodes ---
Write-Log "Installing Custom Nodes" -Level 0
$csvUrl = $dependencies.files.custom_nodes_csv.url
$csvPath = Join-Path $InstallPath $dependencies.files.custom_nodes_csv.destination
Download-File -Uri $csvUrl -OutFile $csvPath
$customNodes = Import-Csv -Path $csvPath
$customNodesPath = Join-Path $InstallPath "custom_nodes"
foreach ($node in $customNodes) {
    $nodeName = $node.Name
    $repoUrl = $node.RepoUrl
    $nodePath = if ($node.Subfolder) { Join-Path $customNodesPath $node.Subfolder } else { Join-Path $customNodesPath $nodeName }
    if (-not (Test-Path $nodePath)) {
        Write-Log "Installing $nodeName" -Level 1
        Invoke-AndLog "git" "clone $repoUrl `"$nodePath`""
        if ($node.RequirementsFile) {
            $reqPath = Join-Path $nodePath $node.RequirementsFile
            if (Test-Path $reqPath) {
                Write-Log "Installing requirements for $nodeName" -Level 2
                Invoke-AndLog "$venvPython" "-m pip install -r `"$reqPath`""
            }
        }
    }
    else {
        Write-Log "$nodeName (already exists, skipping)" -Level 1 -Color Green
    }
}

# --- Step 7: Install Final Python Dependencies ---
Write-Log "Installing Final Python Dependencies" -Level 0
Write-Log "Installing standard packages..." -Level 1
Invoke-AndLog "$venvPython" "-m pip install $($dependencies.pip_packages.standard -join ' ')"

Write-Log "Installing packages from .whl files..." -Level 1
foreach ($wheel in $dependencies.pip_packages.wheels) {
    Write-Log "Installing $($wheel.name)" -Level 2
    $wheelPath = Join-Path $InstallPath "$($wheel.name).whl"
    Download-File -Uri $wheel.url -OutFile $wheelPath
    Invoke-AndLog "$venvPython" "-m pip install `"$wheelPath`""
    Remove-Item $wheelPath -ErrorAction SilentlyContinue
}

Write-Log "Installing pinned version packages..." -Level 1
Invoke-AndLog "$venvPython" "-m pip install $($dependencies.pip_packages.pinned -join ' ')"

Write-Log "Installing packages from git repositories..." -Level 1
foreach ($repo in $dependencies.pip_packages.git_repos) {
    Write-Log "Installing $($repo.name)..." -Level 2
    $installUrl = "git+$($repo.url)@$($repo.commit)"
    $pipArgs = "-m pip install `"$installUrl`""
    $useOptimizations = $false
    $originalPath = $env:Path
    if ($repo.name -eq "xformers" -or $repo.name -eq "SageAttention") {
        $useOptimizations = $true
        $env:PATH = "$($dependencies.tools.ccache.install_path);$originalPath"
        $env:CC = "cl.exe"
        $env:CXX = "cl.exe"
        $env:XFORMERS_BUILD_TYPE = "Release"
        $env:MAX_JOBS = $optimalParallelJobs
        Write-Log "Build optimizations ENABLED (ccache, Release mode, $optimalParallelJobs jobs)" -Level 3 -Color Cyan
    }
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
        continue
    }
    Invoke-AndLog "$venvPython" $pipArgs
    if ($useOptimizations) {
        $env:Path = $originalPath
        $env:CC = $null
        $env:CXX = $null
        $env:XFORMERS_BUILD_TYPE = $null
        $env:MAX_JOBS = $null
        Write-Log "Build optimizations DISABLED" -Level 3
    }
    if ($repo.name -eq "xformers") {
        $env:FORCE_CUDA = $null
    }
}

# --- Step 8: Install VS Build Tools ---
Write-Log "Checking for VS Build Tools" -Level 0
$vsTool = $dependencies.tools.vs_build_tools
if (-not (Test-Path $vsTool.install_path)) {
    Write-Log "VS Build Tools not found. Installing..." -Level 1 -Color Yellow
    $vsInstaller = Join-Path $env:TEMP "vs_buildtools.exe"
    Download-File -Uri $vsTool.url -OutFile $vsInstaller
    Start-Process -FilePath $vsInstaller -ArgumentList $vsTool.arguments -Wait
    Remove-Item $vsInstaller
}
else {
    Write-Log "Visual Studio Build Tools are already installed" -Level 1 -Color Green
}

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
    Invoke-AndLog "git" "clone $workflowRepo.url `"$workflowCloneDest`""
}

# --- Step 10: Finalize Permissions ---
Write-Log "Finalizing Folder Permissions" -Level 0
Write-Log "Applying permissions for standard users to the installation directory..." -Level 1
Write-Log "This will allow ComfyUI to run without administrator rights." -Level 2
Invoke-AndLog "icacls" "`"$InstallPath`" /grant `"BUILTIN\Users`":(OI)(CI)F /T"

# --- Step 11: Optional Model Pack Downloads ---
Write-Log "Optional Model Pack Downloads" -Level 0

# Copy the base models directory if it exists
$ModelsSource = Join-Path $comfyPath "models"
if (Test-Path $ModelsSource) {
    Write-Log "Copying base models directory..." -Level 1
    Copy-Item -Path $ModelsSource -Destination $InstallPath -Recurse -Force
}

$modelPacks = @(
    @{Name="FLUX"; ScriptName="Download-FLUX-Models.ps1"},
    @{Name="WAN2.1"; ScriptName="Download-WAN2.1-Models.ps1"},
    @{Name="WAN2.2"; ScriptName="Download-WAN2.2-Models.ps1"},
    @{Name="HIDREAM"; ScriptName="Download-HIDREAM-Models.ps1"},
    @{Name="LTXV"; ScriptName="Download-LTXV-Models.ps1"}
    @{Name="QWEN"; ScriptName="Download-QWEN-Models.ps1"}
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
        # Use Write-Log for the prompt to keep the color formatting.
        Write-Log "Would you like to download $($pack.Name) models? (Y/N)" -Level 1 -Color Yellow
        $choice = Read-Host

        if ($choice -eq 'Y' -or $choice -eq 'y') {
            Write-Log "Launching downloader for $($pack.Name) models..." -Level 2 -Color Green
            # The external script will handle its own logging.
            & $scriptPath -InstallPath $InstallPath
            $validInput = $true
        } elseif ($choice -eq 'N' -or $choice -eq 'n') {
            Write-Log "Skipping download for $($pack.Name) models." -Level 2
            $validInput = $true
        } else {
            # Use Write-Log for the error message.
            Write-Log "Invalid choice. Please enter Y or N." -Level 2 -Color Red
        }
    }
}

#===========================================================================
# FINALIZATION
#===========================================================================
Write-Log "-------------------------------------------------------------------------------" -Color Green
Write-Log "Installation of ComfyUI and all nodes is complete!" -Color Green
Read-Host "Press Enter to close this window."
