param(
    [string]$InstallPath = $PSScriptRoot
)

<#
.SYNOPSIS
    A PowerShell script to interactively download HiDream models for ComfyUI.
.DESCRIPTION
    This version corrects a major syntax error in the helper functions.
#>

#===========================================================================
# SECTION 1: HELPER FUNCTIONS & SETUP
#===========================================================================
function Write-Log {
    param([string]$Message, [string]$Color = "White")
    $logFile = Join-Path $InstallPath "logs\download_log.txt"
    $formattedMessage = "[$([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss'))] [ModelDownloader-HiDream] $Message"
    Write-Host $Message -ForegroundColor $Color
    Add-Content -Path $logFile -Value $formattedMessage -ErrorAction SilentlyContinue
}

function Invoke-AndLog {
    param([string]$File, [string]$Arguments)
    $logFile = Join-Path $InstallPath "logs\download_log.txt"
    $commandToRun = "`"$File`" $Arguments"
    $cmdArguments = "/C `"$commandToRun >> `"`"$logFile`"`" 2>&1`""
    try {
        Start-Process -FilePath "cmd.exe" -ArgumentList $cmdArguments -Wait -WindowStyle Hidden
    }
    catch {
        Write-Log "FATAL ERROR trying to execute command: $commandToRun" -Color Red
    }
}

function Download-File {
    param([string]$Uri, [string]$OutFile)
    if (Test-Path $OutFile) {
        Write-Log "Skipping: $((Split-Path $OutFile -Leaf)) (already exists)." -Color Gray
        return
    }

    # Present as a modern browser to avoid being blocked.
    $modernUserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
    $fileName = Split-Path -Path $Uri -Leaf

    if (Get-Command 'aria2c' -ErrorAction SilentlyContinue) {
        Write-Log "Downloading: $fileName"
        $aria_args = "--disable-ipv6 -c -x 16 -s 16 -k 1M --user-agent=`"$modernUserAgent`" --dir=`"$((Split-Path $OutFile -Parent))`" --out=`"$((Split-Path $OutFile -Leaf))`" `"$Uri`""
        Invoke-AndLog "aria2c" $aria_args
    } else {
        Write-Log "Aria2 not found. Falling back to standard download: $fileName" -Color Yellow
        # Add the User-Agent to Invoke-WebRequest.
        Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UserAgent $modernUserAgent
    }
}

function Ask-Question {
    param([string]$Prompt, [string[]]$Choices, [string[]]$ValidAnswers)
    $choice = ''
    while ($choice -notin $ValidAnswers) {
        Write-Log "`n$Prompt" -Color Yellow
        foreach ($line in $Choices) {
            Write-Host "  $line" -ForegroundColor Green
        }
        $choice = (Read-Host "Enter your choice and press Enter").ToUpper()
        if ($choice -notin $ValidAnswers) {
            Write-Log "Invalid choice. Please try again." -Color Red
        }
    }
    return $choice
}

#===========================================================================
# SECTION 2: SCRIPT EXECUTION
#===========================================================================
$InstallPath = $InstallPath.Trim('"')
$modelsPath = Join-Path $InstallPath "models"
if (-not (Test-Path $modelsPath)) { Write-Log "Could not find ComfyUI models path at '$modelsPath'. Exiting." -Color Red; Read-Host "Press Enter to exit."; exit }

# --- GPU Detection ---
Write-Log "-------------------------------------------------------------------------------"
Write-Log "Checking for NVIDIA GPU to provide model recommendations..." -Color Yellow
# ... (GPU detection logic) ...
Write-Log "-------------------------------------------------------------------------------"

# --- Ask all questions ---
$fp8Choice = Ask-Question "Do you want to download HiDream fp8 models? (24GB Vram recommended)" @("A) Yes", "B) No") @("A", "B")
$ggufChoice = Ask-Question "Do you want to download HiDream GGUF models?" @("A) Q8_0 (16GB Vram)", "B) Q5_K_S (12GB Vram)", "C) Q4_K_S (less than 12GB Vram)", "D) All", "E) No") @("A", "B", "C", "D", "E")

# --- Download files based on answers ---
Write-Log "`nStarting HiDream model downloads..." -Color Cyan
$baseUrl = "https://huggingface.co/UmeAiRT/ComfyUI-Auto_installer/resolve/main/models"
$hidreamDiffDir = Join-Path $modelsPath "diffusion_models\HIDREAM"; $hidreamUnetDir = Join-Path $modelsPath "unet\HIDREAM"; $clipDir = Join-Path $modelsPath "clip"; $vaeDir  = Join-Path $modelsPath "vae"
New-Item -Path $hidreamDiffDir, $hidreamUnetDir, $clipDir, $vaeDir -ItemType Directory -Force | Out-Null

$doDownload = ($fp8Choice -eq 'A' -or $ggufChoice -ne 'E')

if ($doDownload) {
    Write-Log "`nDownloading HiDream common support files (VAE, CLIPs)..."
    Download-File -Uri "$baseUrl/vae/ae.safetensors?download=true" -OutFile (Join-Path $vaeDir "ae.safetensors")
    Download-File -Uri "$baseUrl/clip/clip_g_hidream.safetensors" -OutFile (Join-Path $clipDir "clip_g_hidream.safetensors")
    Download-File -Uri "$baseUrl/clip/clip_l_hidream.safetensors" -OutFile (Join-Path $clipDir "clip_l_hidream.safetensors")
    Download-File -Uri "$baseUrl/clip/t5xxl_fp8_e4m3fn_scaled.safetensors" -OutFile (Join-Path $clipDir "t5xxl_fp8_e4m3fn_scaled.safetensors")
    Download-File -Uri "$baseUrl/clip/llama_3.1_8b_instruct_fp8_scaled.safetensors" -OutFile (Join-Path $clipDir "llama_3.1_8b_instruct_fp8_scaled.safetensors")
}

if ($fp8Choice -eq 'A') {
    Write-Log "`nDownloading HiDream fp8 model..."
    Download-File -Uri "$baseUrl/diffusion_models/HiDream/hidream_i1_dev_fp8.safetensors" -OutFile (Join-Path $hidreamDiffDir "hidream_i1_dev_fp8.safetensors")
}

if ($ggufChoice -ne 'E') {
    Write-Log "`nDownloading HiDream GGUF models..."
    if ($ggufChoice -in 'A', 'D') {
        Download-File -Uri "$baseUrl/unet/HiDream/hidream-i1-dev-Q8_0.gguf" -OutFile (Join-Path $hidreamUnetDir "hidream-i1-dev-Q8_0.gguf")
    }
    if ($ggufChoice -in 'B', 'D') {
        Download-File -Uri "$baseUrl/unet/HiDream/hidream-i1-dev-Q5_K_S.gguf" -OutFile (Join-Path $hidreamUnetDir "hidream-i1-dev-Q5_K_S.gguf")
    }
    if ($ggufChoice -in 'C', 'D') {
        Download-File -Uri "$baseUrl/unet/HiDream/hidream-i1-dev-Q4_K_S.gguf" -OutFile (Join-Path $hidreamUnetDir "hidream-i1-dev-Q4_K_S.gguf")
    }
}

Write-Log "`nHiDream model downloads complete." -Color Green
Read-Host "Press Enter to return to the main installer."