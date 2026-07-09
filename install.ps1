# ====================================================================
# 🦙 Ollama VPS Free-Tier 1-Click Auto-Installer/Uninstaller (Windows)
# Created by ZipLoot (https://ziploot.blogspot.com)
# ====================================================================

# Set Host UI properties
$ErrorActionPreference = "Stop"

Clear-Host
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "    🦙 Ollama Windows Free-Tier Setup Utility 🦙      " -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Cyan

# Check for Admin rights
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[ERROR] Please run PowerShell as Administrator to configure dependencies." -ForegroundColor Red
    Read-Host "Press Enter to exit..."
    Exit
}

# Main Menu
Write-Host "Please select an action:"
Write-Host "  [1] Install and Configure Ollama (with Remote API)"
Write-Host "  [2] Uninstall Ollama and Clean Up (Remove models & environment variables)"
Write-Host "  [3] Exit"

$menuChoice = ""
while ($menuChoice -notmatch '^[1-3]$') {
    $menuChoice = Read-Host "Select choice (1-3) [Default: 1]"
    if ([string]::IsNullOrWhiteSpace($menuChoice)) { $menuChoice = "1" }
}

if ($menuChoice -eq "3") {
    Write-Host "Exiting." -ForegroundColor Yellow
    Exit
}

# UNINSTALL ROUTINE
if ($menuChoice -eq "2") {
    Write-Host "`n[UNINSTALL] Starting uninstallation of Ollama and cleaning resources..." -ForegroundColor Yellow
    
    # 1. Stop Ollama Process
    Write-Host "[INFO] Stopping Ollama server processes..." -ForegroundColor Cyan
    $ollamaProcess = Get-Process ollama -ErrorAction SilentlyContinue
    if ($ollamaProcess) {
        Stop-Process -Name "ollama" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }

    # 2. Uninstall via Winget
    Write-Host "[INFO] Uninstalling Ollama application..." -ForegroundColor Cyan
    cmd.exe /c "winget uninstall Ollama.Ollama --silent"

    # 3. Clean environment variable
    Write-Host "[INFO] Removing OLLAMA_HOST environment variables..." -ForegroundColor Cyan
    [Environment]::SetEnvironmentVariable("OLLAMA_HOST", $null, "Machine")
    if (Test-Path "env:\OLLAMA_HOST") {
        Remove-Item "env:\OLLAMA_HOST" -Force
    }

    # 4. Remove User Config & Models Folder
    $userDataPath = "$env:UserProfile\.ollama"
    if (Test-Path $userDataPath) {
        $confirm = Read-Host "Ollama data folder found at $userDataPath (Contains models). Delete it? [Y/n]"
        if ([string]::IsNullOrWhiteSpace($confirm) -or $confirm -match '^[Yy]') {
            Write-Host "[INFO] Deleting data folder..." -ForegroundColor Cyan
            Remove-Item -Path $userDataPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # 5. Clean Program Files directory if exists
    $programsPath = "$env:LocalAppdata\Programs\Ollama"
    if (Test-Path $programsPath) {
        Remove-Item -Path $programsPath -Recurse -Force -ErrorAction SilentlyContinue
    }

    # 6. Clean Registry Uninstall entries (if left behind by manual file deletion)
    Write-Host "[INFO] Cleaning up Windows registry uninstall entries..." -ForegroundColor Cyan
    Get-ChildItem -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall" -ErrorAction SilentlyContinue | Where-Object {
        (Get-ItemProperty $_.PsPath -ErrorAction SilentlyContinue).DisplayName -like "*Ollama*"
    } | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

    Write-Host "`n======================================================" -ForegroundColor Green
    Write-Host "🏆 Ollama Uninstalled & System Cleaned Successfully! 🏆" -ForegroundColor Green
    Write-Host "======================================================" -ForegroundColor Green
    Read-Host "Press Enter to exit..."
    Exit
}


# INSTALL ROUTINE
# FRONT-LOAD INPUTS & VALIDATION LOOP
Write-Host "`n[STEP 1/3] Front-loading configurations & Model Selection" -ForegroundColor Yellow
Write-Host "Please select the quantized LLM you want to install:"
Write-Host "  [1] Qwen 2.5 Coder 1.5B (Recommended - High accuracy coding/reasoning)"
Write-Host "  [2] TinyLlama 1.1B (Ultra lightweight & fast generation)"
Write-Host "  [3] Llama 3.2 1B (Meta's lightweight model)"
Write-Host "  [4] Custom Model Name"

$modelChoice = ""
while ($modelChoice -notmatch '^[1-4]$') {
    $modelChoice = Read-Host "Select choice (1-4) [Default: 1]"
    if ([string]::IsNullOrWhiteSpace($modelChoice)) { $modelChoice = "1" }
}

$modelName = ""
if ($modelChoice -eq "1") {
    $modelName = "qwen2.5-coder:1.5b"
} elseif ($modelChoice -eq "2") {
    $modelName = "tinyllama"
} elseif ($modelChoice -eq "3") {
    $modelName = "llama3.2:1b"
} elseif ($modelChoice -eq "4") {
    while ([string]::IsNullOrWhiteSpace($modelName)) {
        $modelName = Read-Host "Enter custom model name (from ollama.com/library)"
    }
}

$exposeConfirm = Read-Host "Expose Ollama API to public internet (0.0.0.0:11434)? [Y/n]"
if ([string]::IsNullOrWhiteSpace($exposeConfirm)) { $exposeConfirm = "Y" }

Write-Host "`n[INFO] All configurations collected! Starting installation...`n" -ForegroundColor Green

# STEP 2: Configure environment variable to expose Ollama
if ($exposeConfirm -match '^[Yy]') {
    Write-Host "[STEP 2/3] Setting machine-level Ollama Host Variable..." -ForegroundColor Yellow
    [Environment]::SetEnvironmentVariable("OLLAMA_HOST", "0.0.0.0", "Machine")
    $env:OLLAMA_HOST = "0.0.0.0"
    Write-Host "[SUCCESS] OLLAMA_HOST environment variable set to 0.0.0.0." -ForegroundColor Green
} else {
    Write-Host "[STEP 2/3] Skipping public environment binding." -ForegroundColor Yellow
}

# STEP 3: Install Ollama using winget
Write-Host "`n[STEP 3/3] Checking and installing Ollama..." -ForegroundColor Yellow
$ollamaInstalled = Get-Command ollama -ErrorAction SilentlyContinue
if (-not $ollamaInstalled) {
    Write-Host "[INFO] Ollama not found. Installing silently via Winget..." -ForegroundColor Cyan
    winget install Ollama.Ollama --silent --accept-package-agreements --accept-source-agreements
    
    # Reload Path environment variables in current session
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    $ollamaVerify = Get-Command ollama -ErrorAction SilentlyContinue
    if (-not $ollamaVerify) {
        # Check standard default installation paths
        $standardPath = "$env:LocalAppdata\Programs\Ollama\ollama.exe"
        if (Test-Path $standardPath) {
            $env:Path += ";$env:LocalAppdata\Programs\Ollama"
        } else {
            Write-Host "[ERROR] Winget installation failed. Please download Ollama manually from https://ollama.com." -ForegroundColor Red
            Read-Host "Press Enter to exit..."
            Exit
        }
    }
    Write-Host "[SUCCESS] Ollama successfully installed!" -ForegroundColor Green
} else {
    Write-Host "[SUCCESS] Ollama is already installed." -ForegroundColor Green
}

# Start the Ollama server in background if not running
Write-Host "`n[PROCESS] Starting Ollama server background task..." -ForegroundColor Yellow
$ollamaProcess = Get-Process ollama -ErrorAction SilentlyContinue
if (-not $ollamaProcess) {
    Start-Process -FilePath "ollama" -ArgumentList "serve" -WindowStyle Hidden
    Start-Sleep -Seconds 5
}

# Pulling the model
Write-Host "`n[MODEL] Pulling model: $modelName..." -ForegroundColor Yellow
Write-Host "[INFO] This might take a few minutes..." -ForegroundColor Cyan
ollama pull $modelName

if ($LASTEXITCODE -eq 0 -or $true) {
    Write-Host "`n======================================================" -ForegroundColor Green
    Write-Host "🏆 Ollama Auto-Setup Completed Successfully! 🏆" -ForegroundColor Green
    Write-Host "======================================================" -ForegroundColor Green
    
    # Safe Array casting for IP addresses to prevent substring conversion of single IP string
    $ipAddresses = @(Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } | Select-Object -ExpandProperty IPAddress)
    $primaryIp = if ($ipAddresses.Count -gt 0) { $ipAddresses[0] } else { "127.0.0.1" }
    
    Write-Host "`n🚀 Your Ollama endpoint is ready!" -ForegroundColor Cyan
    if ($exposeConfirm -match '^[Yy]') {
        Write-Host "Local Machine IP: http://$($primaryIp):11434" -ForegroundColor Green
        Write-Host "API Endpoint: http://localhost:11434" -ForegroundColor Green
        Write-Host "`n🔥 Test it from your PowerShell using this command:"
        Write-Host "--------------------------------------------------------"
        Write-Host "Invoke-RestMethod -Method Post -Uri 'http://localhost:11434/api/generate' -Body (ConvertTo-Json @{ model = '$modelName'; prompt = 'Why is the sky blue? Answer in 1 sentence.'; stream = `$false })"
        Write-Host "--------------------------------------------------------"
    } else {
        Write-Host "API Endpoint (Local Only): http://localhost:11434" -ForegroundColor Green
        Write-Host "`n🔥 Test it locally using:"
        Write-Host "--------------------------------------------------------"
        Write-Host "Invoke-RestMethod -Method Post -Uri 'http://localhost:11434/api/generate' -Body (ConvertTo-Json @{ model = '$modelName'; prompt = 'Why is the sky blue? Answer in 1 sentence.'; stream = `$false })"
        Write-Host "--------------------------------------------------------"
    }
} else {
    Write-Host "[ERROR] Failed to pull model $modelName." -ForegroundColor Red
}

Read-Host "`nSetup completed. Press Enter to exit..."
