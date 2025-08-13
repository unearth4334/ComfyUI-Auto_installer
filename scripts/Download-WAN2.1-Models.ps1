param(
    # Accepts the installation path from the main script.
    # Defaults to its own directory if run standalone.
    [string]$InstallPath = $PSScriptRoot
)

<#
.SYNOPSIS
    A PowerShell script to interactively download WAN 2.1 models for ComfyUI.
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
            if ($gpuMemoryGiB -ge 24) { Write-Log "Recommendation: bf16/fp16 or GGUF Q8_0." -Color Cyan } elseif ($gpuMemoryGiB -ge 16) { Write-Log "Recommendation: fp8 or GGUF Q5_K_M." -Color Cyan } else { Write-Log "Recommendation: GGUF Q3_K_S." -Color Cyan }
        }
    } catch { Write-Log "Could not retrieve GPU information. Error: $($_.Exception.Message)" -Color Red }
} else { Write-Log "No NVIDIA GPU detected (nvidia-smi not found). Please choose based on your hardware." -Color Gray }
Write-Log "-------------------------------------------------------------------------------"

# --- Ask all questions ---
$baseChoice = Ask-Question "Do you want to download WAN base models?" @("A) bf16", "B) fp16", "C) fp8", "D) All", "E) No") @("A", "B", "C", "D", "E")
$ggufT2VChoice = Ask-Question "Do you want to download WAN text-to-video GGUF models?" @("A) Q8_0", "B) Q5_K_M", "C) Q3_K_S", "D) All", "E) No") @("A", "B", "C", "D", "E")
$gguf480Choice = Ask-Question "Do you want to download WAN image-to-video 480p GGUF models?" @("A) Q8_0", "B) Q5_K_M", "C) Q3_K_S", "D) All", "E) No") @("A", "B", "C", "D", "E")
$gguf720Choice = Ask-Question "Do you want to download WAN image-to-video 720p GGUF models?" @("A) Q8_0", "B) Q5_K_M", "C) Q3_K_S", "D) All", "E) No") @("A", "B", "C", "D", "E")
$controlChoice = Ask-Question "Do you want to download WAN FUN CONTROL base models?" @("A) bf16", "B) fp8", "C) All", "D) No") @("A", "B", "C", "D")
$controlGgufChoice = Ask-Question "Do you want to download WAN FUN CONTROL GGUF models?" @("A) Q8_0", "B) Q5_K_M", "C) Q3_K_S", "D) All", "E) No") @("A", "B", "C", "D", "E")
$vaceChoice = Ask-Question "Do you want to download WAN VACE base models?" @("A) fp16", "B) fp8", "C) All", "D) No") @("A", "B", "C", "D")
$vaceGgufChoice = Ask-Question "Do you want to download WAN VACE GGUF models?" @("A) Q8_0", "B) Q5_K_M", "C) Q4_K_S", "D) All", "E) No") @("A", "B", "C", "D", "E")

# --- Download files based on answers ---
Write-Log "`nStarting WAN model downloads..." -Color Cyan
$baseUrl = "https://huggingface.co/UmeAiRT/ComfyUI-Auto_installer/resolve/main/models"
$wanDiffDir = Join-Path $modelsPath "diffusion_models\WAN"; $wanUnetDir = Join-Path $modelsPath "unet\WAN"; $clipDir = Join-Path $modelsPath "clip"; $vaeDir  = Join-Path $modelsPath "vae" ; $visionDir  = Join-Path $modelsPath "clip_vision"
New-Item -Path $wanDiffDir, $wanUnetDir, $clipDir, $vaeDir -ItemType Directory -Force | Out-Null
$doDownload = ($baseChoice -ne 'E' -or $ggufT2VChoice -ne 'E' -or $gguf480Choice -ne 'E' -or $gguf720Choice -ne 'E' -or $controlChoice -ne 'D' -or $controlGgufChoice -ne 'E' -or $vaceChoice -ne 'D' -or $vaceGgufChoice -ne 'E')

if($doDownload) {
    Download-File -Uri "$baseUrl/vae/wan_2.1_vae.safetensors" -OutFile (Join-Path $vaeDir "wan_2.1_vae.safetensors")
    Download-File -Uri "$baseUrl/clip/umt5-xxl-encoder-fp8-e4m3fn-scaled.safetensors" -OutFile (Join-Path $clipDir "umt5-xxl-encoder-fp8-e4m3fn-scaled.safetensors")
    Download-File -Uri "$baseUrl/clip_vision/clip_vision_h.safetensors" -OutFile (Join-Path $visionDir "clip_vision_h.safetensors")
}

# Base Models
if ($baseChoice -ne 'E') {
    Write-Log "`nDownloading Base Models..."
    if ($baseChoice -in 'A', 'D') {
        Download-File -Uri "$baseUrl/diffusion_models/WAN/wan2.1_t2v_14B_bf16.safetensors" -OutFile (Join-Path $wanDiffDir "wan2.1_t2v_14B_bf16.safetensors")
        Download-File -Uri "$baseUrl/diffusion_models/WAN/wan2.1_i2v_720p_14B_bf16.safetensors" -OutFile (Join-Path $wanDiffDir "wan2.1_i2v_720p_14B_bf16.safetensors")
        Download-File -Uri "$baseUrl/diffusion_models/WAN/wan2.1_i2v_480p_14B_bf16.safetensors" -OutFile (Join-Path $wanDiffDir "wan2.1_i2v_480p_14B_bf16.safetensors")
    }
    if ($baseChoice -in 'B', 'D') {
        Download-File -Uri "$baseUrl/diffusion_models/WAN/wan2.1_t2v_14B_fp16.safetensors" -OutFile (Join-Path $wanDiffDir "wan2.1_t2v_14B_fp16.safetensors")
        Download-File -Uri "$baseUrl/diffusion_models/WAN/wan2.1_i2v_720p_14B_fp16.safetensors" -OutFile (Join-Path $wanDiffDir "wan2.1_i2v_720p_14B_fp16.safetensors")
        Download-File -Uri "$baseUrl/diffusion_models/WAN/wan2.1_i2v_480p_14B_fp16.safetensors" -OutFile (Join-Path $wanDiffDir "wan2.1_i2v_480p_14B_fp16.safetensors")
    }
    if ($baseChoice -in 'C', 'D') {
        Download-File -Uri "$baseUrl/diffusion_models/WAN/wan2.1_t2v_14B_fp8_e4m3fn.safetensors" -OutFile (Join-Path $wanDiffDir "wan2.1_t2v_14B_fp8_e4m3fn.safetensors")
        Download-File -Uri "$baseUrl/diffusion_models/WAN/wan2.1_i2v_720p_14B_fp8_e4m3fn.safetensors" -OutFile (Join-Path $wanDiffDir "wan2.1_i2v_720p_14B_fp8_e4m3fn.safetensors")
        Download-File -Uri "$baseUrl/diffusion_models/WAN/wan2.1_i2v_480p_14B_fp8_e4m3fn.safetensors" -OutFile (Join-Path $wanDiffDir "wan2.1_i2v_480p_14B_fp8_e4m3fn.safetensors")
    }
}
# GGUF T2V
if ($ggufT2VChoice -ne 'E') {
    Write-Log "`nDownloading T2V GGUF Models..."
    if ($ggufT2VChoice -in 'A', 'D') {
        Download-File -Uri "$baseUrl/unet/WAN/wan2.1-t2v-14b-Q8_0.gguf" -OutFile (Join-Path $wanUnetDir "wan2.1-t2v-14b-Q8_0.gguf")
        Download-File -Uri "$baseUrl/clip/umt5-xxl-encoder-Q8_0.gguf" -OutFile (Join-Path $clipDir "umt5-xxl-encoder-Q8_0.gguf")
    }
    if ($ggufT2VChoice -in 'B', 'D') {
        Download-File -Uri "$baseUrl/unet/WAN/wan2.1-t2v-14b-Q5_K_M.gguf" -OutFile (Join-Path $wanUnetDir "wan2.1-t2v-14b-Q5_K_M.gguf")
        Download-File -Uri "$baseUrl/clip/umt5-xxl-encoder-Q5_K_M.gguf" -OutFile (Join-Path $clipDir "umt5-xxl-encoder-Q5_K_M.gguf")
    }
    if ($ggufT2VChoice -in 'C', 'D') {
        Download-File -Uri "$baseUrl/unet/WAN/wan2.1-t2v-14b-Q3_K_S.gguf" -OutFile (Join-Path $wanUnetDir "wan2.1-t2v-14b-Q3_K_S.gguf")
        Download-File -Uri "$baseUrl/clip/umt5-xxl-encoder-Q3_K_S.gguf" -OutFile (Join-Path $clipDir "umt5-xxl-encoder-Q3_K_S.gguf")
    }
}
# GGUF I2V 480p
if ($gguf480Choice -ne 'E') {
    Write-Log "`nDownloading I2V 480p GGUF Models..."
    if ($gguf480Choice -in 'A', 'D') {
        Download-File -Uri "$baseUrl/unet/WAN/wan2.1-i2v-14b-480p-Q8_0.gguf" -OutFile (Join-Path $wanUnetDir "wan2.1-i2v-14b-480p-Q8_0.gguf")
        Download-File -Uri "$baseUrl/clip/umt5-xxl-encoder-Q8_0.gguf" -OutFile (Join-Path $clipDir "umt5-xxl-encoder-Q8_0.gguf")
    }
    if ($gguf480Choice -in 'B', 'D') {
        Download-File -Uri "$baseUrl/unet/WAN/wan2.1-i2v-14b-480p-Q5_K_M.gguf" -OutFile (Join-Path $wanUnetDir "wan2.1-i2v-14b-480p-Q5_K_M.gguf")
        Download-File -Uri "$baseUrl/clip/umt5-xxl-encoder-Q5_K_M.gguf" -OutFile (Join-Path $clipDir "umt5-xxl-encoder-Q5_K_M.gguf")
    }
    if ($gguf480Choice -in 'C', 'D') {
        Download-File -Uri "$baseUrl/unet/WAN/wan2.1-i2v-14b-480p-Q3_K_S.gguf" -OutFile (Join-Path $wanUnetDir "wan2.1-i2v-14b-480p-Q3_K_S.gguf")
        Download-File -Uri "$baseUrl/clip/umt5-xxl-encoder-Q3_K_S.gguf" -OutFile (Join-Path $clipDir "umt5-xxl-encoder-Q3_K_S.gguf")
    }
}
# GGUF I2V 720p
if ($gguf720Choice -ne 'E') {
    Write-Log "`nDownloading I2V 720p GGUF Models..."
    if ($gguf720Choice -in 'A', 'D') {
        Download-File -Uri "$baseUrl/unet/WAN/wan2.1-i2v-14b-720p-Q8_0.gguf" -OutFile (Join-Path $wanUnetDir "wan2.1-i2v-14b-720p-Q8_0.gguf")
        Download-File -Uri "$baseUrl/clip/umt5-xxl-encoder-Q8_0.gguf" -OutFile (Join-Path $clipDir "umt5-xxl-encoder-Q8_0.gguf")
    }
    if ($gguf720Choice -in 'B', 'D') {
        Download-File -Uri "$baseUrl/unet/WAN/wan2.1-i2v-14b-720p-Q5_K_M.gguf" -OutFile (Join-Path $wanUnetDir "wan2.1-i2v-14b-720p-Q5_K_M.gguf")
        Download-File -Uri "$baseUrl/clip/umt5-xxl-encoder-Q5_K_M.gguf" -OutFile (Join-Path $clipDir "umt5-xxl-encoder-Q5_K_M.gguf")
    }
    if ($gguf720Choice -in 'C', 'D') {
        Download-File -Uri "$baseUrl/unet/WAN/wan2.1-i2v-14b-720p-Q3_K_S.gguf" -OutFile (Join-Path $wanUnetDir "wan2.1-i2v-14b-720p-Q3_K_S.gguf")
        Download-File -Uri "$baseUrl/clip/umt5-xxl-encoder-Q3_K_S.gguf" -OutFile (Join-Path $clipDir "umt5-xxl-encoder-Q3_K_S.gguf")
    }
}
# ControlNet Models
if ($controlChoice -ne 'D') {
    Write-Log "`nDownloading ControlNet Models..."
    if ($controlChoice -in 'A', 'C') {
        Download-File -Uri "$baseUrl/diffusion_models/WAN/wan2.1-fun-14B-control.safetensors" -OutFile (Join-Path $wanDiffDir "wan2.1-fun-14B-control.safetensors")
    }
    if ($controlChoice -in 'B', 'C') {
        Download-File -Uri "https://huggingface.co/TFMC/Wan2.1-Fun-V1.1-14B-InP-FP8/resolve/main/Wan2.1-Fun-V1_1-InP-14B_fp8_e4m3fn.safetensors" -OutFile (Join-Path $wanDiffDir "Wan2.1-Fun-V1_1-InP-14B_fp8_e4m3fn.safetensors")
    }
}
# ControlNet GGUF
if ($controlGgufChoice -ne 'E') {
    Write-Log "`nDownloading ControlNet GGUF Models..."
    if ($controlGgufChoice -in 'A', 'D') {
        Download-File -Uri "$baseUrl/unet/WAN/wan2.1-fun-14b-control-Q8_0.gguf" -OutFile (Join-Path $wanUnetDir "wan2.1-fun-14b-control-Q8_0.gguf")
        Download-File -Uri "$baseUrl/clip/umt5-xxl-encoder-Q8_0.gguf" -OutFile (Join-Path $clipDir "umt5-xxl-encoder-Q8_0.gguf")
    }
    if ($controlGgufChoice -in 'B', 'D') {
        Download-File -Uri "$baseUrl/unet/WAN/wan2.1-fun-14b-control-Q5_K_M.gguf" -OutFile (Join-Path $wanUnetDir "wan2.1-fun-14b-control-Q5_K_M.gguf")
        Download-File -Uri "$baseUrl/clip/umt5-xxl-encoder-Q5_K_M.gguf" -OutFile (Join-Path $clipDir "umt5-xxl-encoder-Q5_K_M.gguf")
    }
    if ($controlGgufChoice -in 'C', 'D') {
        Download-File -Uri "$baseUrl/unet/WAN/wan2.1-fun-14b-control-Q3_K_S.gguf" -OutFile (Join-Path $wanUnetDir "wan2.1-fun-14b-control-Q3_K_S.gguf")
        Download-File -Uri "$baseUrl/clip/umt5-xxl-encoder-Q3_K_S.gguf" -OutFile (Join-Path $clipDir "umt5-xxl-encoder-Q3_K_S.gguf")
    }
}
# VACE Models
if ($vaceChoice -ne 'D') {
    Write-Log "`nDownloading VACE Models..."
    if ($vaceChoice -in 'A', 'C') {
        Download-File -Uri "$baseUrl/diffusion_models/WAN/wan2.1_vace_14B_fp16.safetensors" -OutFile (Join-Path $wanDiffDir "wan2.1_vace_14B_fp16.safetensors")
    }
    if ($vaceChoice -in 'B', 'C') {
        Download-File -Uri "https://huggingface.co/Kamikaze-88/Wan2.1-VACE-14B-fp8/resolve/main/wan2.1_vace_14B_fp8_e4m3fn.safetensors" -OutFile (Join-Path $wanDiffDir "wan2.1_vace_14B_fp8_e4m3fn.safetensors")
    }
}
# VACE GGUF
if ($vaceGgufChoice -ne 'E') {
    Write-Log "`nDownloading VACE GGUF Models..."
    if ($vaceGgufChoice -in 'A', 'D') {
        Download-File -Uri "$baseUrl/unet/WAN/Wan2.1-VACE-14B-Q8_0.gguf" -OutFile (Join-Path $wanUnetDir "Wan2.1-VACE-14B-Q8_0.gguf")
        Download-File -Uri "$baseUrl/clip/umt5-xxl-encoder-Q8_0.gguf" -OutFile (Join-Path $clipDir "umt5-xxl-encoder-Q8_0.gguf")
    }
    if ($vaceGgufChoice -in 'B', 'D') {
        Download-File -Uri "$baseUrl/unet/WAN/Wan2.1-VACE-14B-Q5_K_S.gguf" -OutFile (Join-Path $wanUnetDir "Wan2.1-VACE-14B-Q5_K_S.gguf")
        Download-File -Uri "$baseUrl/clip/umt5-xxl-encoder-Q5_K_M.gguf" -OutFile (Join-Path $clipDir "umt5-xxl-encoder-Q5_K_M.gguf")
    }
    if ($vaceGgufChoice -in 'C', 'D') {
        Download-File -Uri "$baseUrl/unet/WAN/Wan2.1-VACE-14B-Q4_K_S.gguf" -OutFile (Join-Path $wanUnetDir "Wan2.1-VACE-14B-Q4_K_S.gguf")
        Download-File -Uri "$baseUrl/clip/umt5-xxl-encoder-Q3_K_S.gguf" -OutFile (Join-Path $clipDir "umt5-xxl-encoder-Q3_K_S.gguf")
    }
}

Write-Log "`nWAN model downloads complete." -Color Green
Read-Host "Press Enter to return to the main installer."