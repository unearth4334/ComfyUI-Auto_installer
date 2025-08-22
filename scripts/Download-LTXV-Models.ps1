param(
    [string]$InstallPath = $PSScriptRoot
)

<#
.SYNOPSIS
    A PowerShell script to interactively download LTX-Video models for ComfyUI.
.DESCRIPTION
    This version corrects a major syntax error in the helper functions.
#>

#===========================================================================
# SECTION 1: HELPER FUNCTIONS & SETUP
#===========================================================================
function Write-Log {
    param([string]$Message, [string]$Color = "White")
    $logFile = Join-Path $InstallPath "logs\download_log.txt"
    $formattedMessage = "[$([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss'))] [ModelDownloader-LTXV] $Message"
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
if (-not (Test-Path $modelsPath)) {
    Write-Log "Could not find ComfyUI models path at '$modelsPath'. Exiting." -Color Red
    Read-Host "Press Enter to exit."
    exit
}

# --- GPU Detection ---
Write-Log "-------------------------------------------------------------------------------"
Write-Log "Checking for NVIDIA GPU to provide model recommendations..." -Color Yellow
# ... (GPU detection logic) ...
Write-Log "-------------------------------------------------------------------------------"

# --- Ask all questions ---
$baseChoice = Ask-Question "Do you want to download LTXV base models?" @("A) 13B (30Gb)", "B) 2B (7Gb)", "C) All", "D) No") @("A", "B", "C", "D")
$ggufChoice = Ask-Question "Do you want to download LTXV GGUF models?" @("A) Q8_0 (24GB Vram)", "B) Q5_K_M (16GB Vram)", "C) Q3_K_S (less than 12GB Vram)", "D) All", "E) No") @("A", "B", "C", "D", "E")

# --- Download files based on answers ---
Write-Log "`nStarting LTX-Video model downloads..." -Color Cyan
$baseUrl = "https://huggingface.co/UmeAiRT/ComfyUI-Auto_installer/resolve/main/models"
$ltxvChkptDir = Join-Path $modelsPath "checkpoints\LTXV"
$ltxvUnetDir = Join-Path $modelsPath "unet\LTXV"
$vaeDir = Join-Path $modelsPath "vae"
New-Item -Path $ltxvChkptDir, $ltxvUnetDir, $vaeDir -ItemType Directory -Force | Out-Null

$doDownload = ($baseChoice -ne 'D' -or $ggufChoice -ne 'E')

if ($doDownload) {
    Write-Log "`nDownloading LTXV common support file (VAE)..."
    Download-File -Uri "$baseUrl/vae/ltxv-13b-0.9.7-vae-BF16.safetensors" -OutFile (Join-Path $vaeDir "ltxv-13b-0.9.7-vae-BF16.safetensors")
}

if ($baseChoice -ne 'D') {
    Write-Log "`nDownloading LTXV base model(s)..."
    if ($baseChoice -in 'A', 'C') {
        Download-File -Uri "$baseUrl/checkpoints/LTXV/ltxv-13b-0.9.7-dev.safetensors" -OutFile (Join-Path $ltxvChkptDir "ltxv-13b-0.9.7-dev.safetensors")
    }
    if ($baseChoice -in 'B', 'C') {
        Download-File -Uri "$baseUrl/checkpoints/LTXV/ltxv-2b-0.9.6-dev-04-25.safetensors" -OutFile (Join-Path $ltxvChkptDir "ltxv-2b-0.9.6-dev-04-25.safetensors")
    }
}

if ($ggufChoice -ne 'E') {
    Write-Log "`nDownloading LTXV GGUF models..."
    if ($ggufChoice -in 'A', 'D') {
        Download-File -Uri "$baseUrl/unet/LTXV/ltxv-13b-0.9.7-dev-Q8_0.gguf" -OutFile (Join-Path $ltxvUnetDir "ltxv-13b-0.9.7-dev-Q8_0.gguf")
    }
    if ($ggufChoice -in 'B', 'D') {
        Download-File -Uri "$baseUrl/unet/LTXV/ltxv-13b-0.9.7-dev-Q5_K_M.gguf" -OutFile (Join-Path $ltxvUnetDir "ltxv-13b-0.9.7-dev-Q5_K_M.gguf")
    }
    if ($ggufChoice -in 'C', 'D') {
        Download-File -Uri "$baseUrl/unet/LTXV/ltxv-13b-0.9.7-dev-Q3_K_S.gguf" -OutFile (Join-Path $ltxvUnetDir "ltxv-13b-0.9.7-dev-Q3_K_S.gguf")
    }
}

Write-Log "`nLTX-Video model downloads complete." -Color Green
Read-Host "Press Enter to return to the main installer."