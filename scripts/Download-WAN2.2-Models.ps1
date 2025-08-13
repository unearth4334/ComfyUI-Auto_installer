param(
    # Accepts the installation path from the main script.
    # Defaults to its own directory if run standalone.
    [string]$InstallPath = $PSScriptRoot
)

<#
.SYNOPSIS
    A PowerShell script to interactively download WAN 2.2 models for ComfyUI.
#>

#===========================================================================
# SECTION 1: HELPER FUNCTIONS & SETUP
#===========================================================================
$InstallPath = $InstallPath.Trim('"')
function Write-Log {
    param([string]$Message, [string]$Color = "White")
    $logFile = Join-Path $InstallPath "logs\install_log.txt"
    $formattedMessage = "[$([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss'))] [ModelDownloader-WAN] $Message"
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
if (Get-Command 'nvidia-smi' -ErrorAction SilentlyContinue) {
    try {
        $gpuInfoCsv = nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
        if ($gpuInfoCsv) {
            $gpuInfoParts = $gpuInfoCsv.Split(','); $gpuName = $gpuInfoParts[0].Trim(); $gpuMemoryMiB = ($gpuInfoParts[1] -replace ' MiB').Trim(); $gpuMemoryGiB = [math]::Round([int]$gpuMemoryMiB / 1024)
            Write-Log "GPU: $gpuName" -Color Green; Write-Log "VRAM: $gpuMemoryGiB GB" -Color Green
            if ($gpuMemoryGiB -ge 40) { Write-Log "Recommendation: fp16" -Color Cyan } elseif ($gpuMemoryGiB -ge 23) { Write-Log "Recommendation: fp8 or GGUF Q8" -Color Cyan } elseif ($gpuMemoryGiB -ge 16) { Write-Log "Recommendation: Q5_K_M" -Color Cyan } else { Write-Log "Recommendation: Q3_K_S" -Color Cyan }
        }
    } catch { Write-Log "Could not retrieve GPU information. Error: $($_.Exception.Message)" -Color Red }
} else { Write-Log "No NVIDIA GPU detected (nvidia-smi not found). Please choose based on your hardware." -Color Gray }
Write-Log "-------------------------------------------------------------------------------"

# --- Ask all questions ---
$T2VChoice = Ask-Question "Do you want to download WAN text-to-video models?" @("A) fp16", "B) fp8", "C) Q8_0", "D) Q5_K_M", "E) Q3_K_S", "F) All", "G) No") @("A", "B", "C", "D", "E", "F", "G")
$I2VChoice = Ask-Question "Do you want to download WAN image-to-video models?" @("A) fp16", "B) fp8", "C) Q8_0", "D) Q5_K_M", "E) Q3_K_S", "F) All", "G) No") @("A", "B", "C", "D", "E", "F", "G")

# --- Download files based on answers ---
Write-Log "`nStarting WAN model downloads..." -Color Cyan
$baseUrl = "https://huggingface.co/UmeAiRT/ComfyUI-Auto_installer/resolve/main/models"
$wanDiffDir = Join-Path $modelsPath "diffusion_models\WAN2.2"; $wanUnetDir = Join-Path $modelsPath "unet\WAN2.2"; $clipDir = Join-Path $modelsPath "clip"; $vaeDir  = Join-Path $modelsPath "vae" ; $visionDir  = Join-Path $modelsPath "clip_vision"
New-Item -Path $wanDiffDir, $wanUnetDir, $clipDir, $vaeDir -ItemType Directory -Force | Out-Null
$doDownload = ($T2VChoice -ne 'G' -or $I2VChoice -ne 'G')

if($doDownload) {
    Download-File -Uri "$baseUrl/vae/wan_2.1_vae.safetensors" -OutFile (Join-Path $vaeDir "wan_2.1_vae.safetensors")
    Download-File -Uri "$baseUrl/clip/umt5-xxl-encoder-fp8-e4m3fn-scaled.safetensors" -OutFile (Join-Path $clipDir "umt5-xxl-encoder-fp8-e4m3fn-scaled.safetensors")
}

# text-to-video Models
if ($T2VChoice -ne 'G') {
    Write-Log "`nDownloading text-to-video Models..."
    if ($T2VChoice -in 'A', 'F') {
        Download-File -Uri "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_high_noise_14B_fp16.safetensors" -OutFile (Join-Path $wanDiffDir "wan2.2_t2v_high_noise_14B_fp16_scaled.safetensors")
        Download-File -Uri "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp16.safetensors" -OutFile (Join-Path $wanDiffDir "wan2.2_t2v_low_noise_14B_fp16_scaled.safetensors")
    }
    if ($T2VChoice -in 'B', 'F') {
        Download-File -Uri "$baseUrl/diffusion_models/WAN/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors" -OutFile (Join-Path $wanDiffDir "wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors")
        Download-File -Uri "$baseUrl/diffusion_models/WAN/wan2.2_t2v_high_low_14B_fp8_scaled.safetensors" -OutFile (Join-Path $wanDiffDir "wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors")
    }
    if ($T2VChoice -in 'C', 'F') {
        Download-File -Uri "$baseUrl/unet/WAN/Wan2.2-T2V-A14B-HighNoise-Q8_0.gguf" -OutFile (Join-Path $wanUnetDir "Wan2.2-T2V-A14B-HighNoise-Q8_0.gguf")
        Download-File -Uri "$baseUrl/unet/WAN/Wan2.2-T2V-A14B-LowNoise-Q8_0.gguf" -OutFile (Join-Path $wanUnetDir "Wan2.2-T2V-A14B-LowNoise-Q8_0.gguf")
    }
    if ($T2VChoice -in 'D', 'F') {
        Download-File -Uri "$baseUrl/unet/WAN/Wan2.2-T2V-A14B-HighNoise-Q5_K_S.gguf" -OutFile (Join-Path $wanUnetDir "Wan2.2-T2V-A14B-HighNoise-Q5_K_S.gguf")
        Download-File -Uri "$baseUrl/unet/WAN/Wan2.2-T2V-A14B-LowNoise-Q5_K_S.gguf" -OutFile (Join-Path $wanUnetDir "Wan2.2-T2V-A14B-LowNoise-Q5_K_S.gguf")
    }
    if ($T2VChoice -in 'E', 'F') {
        Download-File -Uri "$baseUrl/unet/WAN/Wan2.2-T2V-A14B-HighNoise-Q3_K_S.gguf" -OutFile (Join-Path $wanUnetDir "Wan2.2-T2V-A14B-HighNoise-Q3_K_S.gguf")
        Download-File -Uri "$baseUrl/unet/WAN/Wan2.2-T2V-A14B-LowNoise-Q3_K_S.gguf" -OutFile (Join-Path $wanUnetDir "Wan2.2-T2V-A14B-LowNoise-Q3_K_S.gguf")
    }
}

# image-to-video Models
if ($T2VChoice -ne 'G') {
    Write-Log "`nDownloading text-to-video Models..."
    if ($T2VChoice -in 'A', 'F') {
        Download-File -Uri "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_i2v_high_noise_14B_fp16.safetensors" -OutFile (Join-Path $wanDiffDir "wan2.2_i2v_high_noise_14B_fp16_scaled.safetensors")
        Download-File -Uri "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_I2v_low_noise_14B_fp16.safetensors" -OutFile (Join-Path $wanDiffDir "wan2.2_i2v_low_noise_14B_fp16_scaled.safetensors")
    }
    if ($T2VChoice -in 'B', 'F') {
        Download-File -Uri "$baseUrl/diffusion_models/WAN/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors" -OutFile (Join-Path $wanDiffDir "wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors")
        Download-File -Uri "$baseUrl/diffusion_models/WAN/wan2.2_i2v_high_low_14B_fp8_scaled.safetensors" -OutFile (Join-Path $wanDiffDir "wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors")
    }
    if ($T2VChoice -in 'C', 'F') {
        Download-File -Uri "$baseUrl/unet/WAN/Wan2.2-I2V-A14B-HighNoise-Q8_0.gguf" -OutFile (Join-Path $wanUnetDir "Wan2.2-I2V-A14B-HighNoise-Q8_0.gguf")
        Download-File -Uri "$baseUrl/unet/WAN/Wan2.2-T2V-A14B-LowNoise-Q8_0.gguf" -OutFile (Join-Path $wanUnetDir "Wan2.2-T2V-A14B-LowNoise-Q8_0.gguf")
    }
    if ($T2VChoice -in 'D', 'F') {
        Download-File -Uri "$baseUrl/unet/WAN/Wan2.2-I2V-A14B-HighNoise-Q5_K_S.gguf" -OutFile (Join-Path $wanUnetDir "Wan2.2-I2V-A14B-HighNoise-Q5_K_S.gguf")
        Download-File -Uri "$baseUrl/unet/WAN/Wan2.2-I2V-A14B-LowNoise-Q5_K_S.gguf" -OutFile (Join-Path $wanUnetDir "Wan2.2-I2V-A14B-LowNoise-Q5_K_S.gguf")
    }
    if ($T2VChoice -in 'E', 'F') {
        Download-File -Uri "$baseUrl/unet/WAN/Wan2.2-I2V-A14B-HighNoise-Q3_K_S.gguf" -OutFile (Join-Path $wanUnetDir "Wan2.2-I2V-A14B-HighNoise-Q3_K_S.gguf")
        Download-File -Uri "$baseUrl/unet/WAN/Wan2.2-I2V-A14B-LowNoise-Q3_K_S.gguf" -OutFile (Join-Path $wanUnetDir "Wan2.2-I2V-A14B-LowNoise-Q3_K_S.gguf")
    }
}

Write-Log "`nWAN2.2 model downloads complete." -Color Green
Read-Host "Press Enter to return to the main installer."