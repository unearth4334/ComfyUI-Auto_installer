param(
    [string]$InstallPath = $PSScriptRoot
)

<#
.SYNOPSIS
    A PowerShell script to interactively download QWEN models for ComfyUI.
.DESCRIPTION
    This version corrects a major syntax error in the helper functions.
#>

#===========================================================================
# SECTION 1: HELPER FUNCTIONS & SETUP
#===========================================================================
function Write-Log { 
    param([string]$Message, [string]$Color = "White") 
    $logFile = Join-Path $InstallPath "logs\install_log.txt"
    $formattedMessage = "[$([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss'))] [ModelDownloader-QWEN] $Message"
    Write-Host $Message -ForegroundColor $Color
    Add-Content -Path $logFile -Value $formattedMessage -ErrorAction SilentlyContinue
}

function Invoke-AndLog { 
    param([string]$File, [string]$Arguments) 
    $logFile = Join-Path $InstallPath "logs\install_log.txt"
    $commandToRun = "`"$File`" $Arguments"
    $cmdArguments = "/C `"$commandToRun >> `"`"$logFile`"`" 2>&1`""
    try { 
        Start-Process -FilePath "cmd.exe" -ArgumentList $cmdArguments -Wait -WindowStyle Hidden 
    } catch { 
        Write-Log "FATAL ERROR trying to execute command: $commandToRun" -Color Red 
    } 
}

function Download-File {
    param([string]$Uri, [string]$OutFile)
    if (Test-Path $OutFile) {
        Write-Log "Skipping: $((Split-Path $OutFile -Leaf)) (already exists)." -Color Gray
        return
    }

    # Se présenter comme un navigateur moderne pour éviter les blocages
    $modernUserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
    $fileName = Split-Path -Path $Uri -Leaf

    if (Get-Command 'aria2c' -ErrorAction SilentlyContinue) {
        Write-Log "Downloading: $fileName"
        $aria_args = "--disable-ipv6 -c -x 16 -s 16 -k 1M --user-agent=`"$modernUserAgent`" --dir=`"$((Split-Path $OutFile -Parent))`" --out=`"$((Split-Path $OutFile -Leaf))`" `"$Uri`""
        Invoke-AndLog "aria2c" $aria_args
    } else {
        Write-Log "Aria2 not found. Falling back to standard download: $fileName" -Color Yellow
        # On ajoute le User-Agent à Invoke-WebRequest
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
# ... (logique de détection GPU) ...
Write-Log "-------------------------------------------------------------------------------"

# --- Ask all questions ---
$baseChoice = Ask-Question "Do you want to download QWEN base models? " @("A) bf16", "B) fp8", "C) All", "D) No") @("A", "B", "C", "D")
$ggufChoice = Ask-Question "Do you want to download QWEN GGUF models?" @("A) Q8_0", "B) Q5_K_S", "C) Q4_K_S", "D) All", "E) No") @("A", "B", "C", "D", "E")

# --- Download files based on answers ---
Write-Log "`nStarting QWEN model downloads..." -Color Cyan
$baseUrl = "https://huggingface.co/UmeAiRT/ComfyUI-Auto_installer/resolve/main/models"
$QWENDiffDir = Join-Path $modelsPath "diffusion_models\QWEN"; $QWENUnetDir = Join-Path $modelsPath "unet\QWEN"; $clipDir = Join-Path $modelsPath "clip"; $vaeDir  = Join-Path $modelsPath "vae"
New-Item -Path $QWENDiffDir, $QWENUnetDir, $clipDir, $vaeDir -ItemType Directory -Force | Out-Null

$doDownload = ($fp8Choice -eq 'A' -or $ggufChoice -ne 'E')

if ($doDownload) {
    Write-Log "`nDownloading QWEN common support files (VAE, CLIPs)..."
    Download-File -Uri "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors" -OutFile (Join-Path $vaeDir "qwen_image_vae.safetensors")
}

if ($baseChoice -ne 'D') {
    Write-Log "`nDownloading QWEN base model..."
    if ($ggufChoice -in 'A', 'C') { Download-File -Uri "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_bf16.safetensors" -OutFile (Join-Path $QWENUnetDir "qwen_image_bf16.safetensors"); Download-File -Uri "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b.safetensors" -OutFile (Join-Path $clipDir "qwen_2.5_vl_7b.safetensors")}
    if ($ggufChoice -in 'B', 'C') { Download-File -Uri "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_fp8_e4m3fn.safetensors" -OutFile (Join-Path $QWENUnetDir "qwen_image_fp8_e4m3fn.safetensors"); Download-File -Uri "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors" -OutFile (Join-Path $clipDir "qwen_2.5_vl_7b_fp8_scaled.safetensors")}
}

if ($ggufChoice -ne 'E') {
    Write-Log "`nDownloading QWEN GGUF models..."
    if ($ggufChoice -in 'A', 'D') { Download-File -Uri "$baseUrl/unet/QWEN/Qwen_Image_Distill-Q8_0.gguf" -OutFile (Join-Path $QWENUnetDir "Qwen_Image_Distill-Q8_0.gguf"); Download-File -Uri "$baseUrl/clip/Qwen2.5-VL-7B-Instruct-UD-Q4_K_S.gguf" -OutFile (Join-Path $clipDir "Qwen2.5-VL-7B-Instruct-UD-Q4_K_S.gguf")}
    if ($ggufChoice -in 'B', 'D') { Download-File -Uri "$baseUrl/unet/QWEN/Qwen_Image_Distill-Q5_K_S.gguf" -OutFile (Join-Path $QWENUnetDir "Qwen_Image_Distill-Q5_K_S.gguf"); Download-File -Uri "$baseUrl/clip/Qwen2.5-VL-7B-Instruct-UD-Q4_K_S.gguf" -OutFile (Join-Path $clipDir "Qwen2.5-VL-7B-Instruct-UD-Q4_K_S.gguf")}
    if ($ggufChoice -in 'C', 'D') { Download-File -Uri "$baseUrl/unet/QWEN/Qwen_Image_Distill-Q4_K_S.gguf" -OutFile (Join-Path $QWENUnetDir "Qwen_Image_Distill-Q4_K_S.gguf"); Download-File -Uri "$baseUrl/clip/Qwen2.5-VL-7B-Instruct-UD-Q4_K_S.gguf" -OutFile (Join-Path $clipDir "Qwen2.5-VL-7B-Instruct-UD-Q4_K_S.gguf")}
}

Write-Log "`nQWEN model downloads complete." -Color Green
Read-Host "Press Enter to return to the main installer."