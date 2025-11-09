<#
.SYNOPSIS
    Installs NVIDIA Container Toolkit in WSL2 Ubuntu for Docker Desktop GPU support
.DESCRIPTION
    This script automates the installation of NVIDIA Container Toolkit in WSL2,
    which is required for Docker containers to access NVIDIA GPUs on Windows.
    
    Run this script as Administrator on Windows.
#>

$ErrorActionPreference = "Stop"

Write-Host @"
╔═══════════════════════════════════════════════════════════════╗
║   NVIDIA Container Toolkit Installer for WSL2                ║
║   Docker Desktop GPU Support                                  ║
╚═══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

# Check for admin privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script must be run as Administrator. Please restart PowerShell as Administrator."
    exit 1
}

# Find Ubuntu distro
Write-Host "`n[1/5] Finding Ubuntu WSL2 distribution..." -ForegroundColor Yellow
try {
    $wslList = wsl --list --verbose 2>&1
    $ubuntuLine = ($wslList -split "`n" | Where-Object { $_ -match "Ubuntu" } | Select-Object -First 1)
    
    if (-not $ubuntuLine) {
        Write-Error "No Ubuntu distribution found in WSL2. Please install Ubuntu first: wsl --install -d Ubuntu-22.04"
        exit 1
    }
    
    $ubuntuDistro = ($ubuntuLine -split '\s+')[0]
    Write-Host "  ✅ Found Ubuntu distribution: $ubuntuDistro" -ForegroundColor Green
    
    # Start the distro if not running
    if ($ubuntuLine -notmatch "Running") {
        Write-Host "  Starting Ubuntu distribution..." -ForegroundColor Yellow
        wsl -d $ubuntuDistro -- echo "Starting" 2>&1 | Out-Null
        Start-Sleep -Seconds 3
    }
} catch {
    Write-Error "Error finding Ubuntu distribution: $_"
    exit 1
}

# Check if NVIDIA Container Toolkit is already installed
Write-Host "`n[2/5] Checking if NVIDIA Container Toolkit is already installed..." -ForegroundColor Yellow
try {
    $checkInstalled = wsl -d $ubuntuDistro -- bash -c "dpkg -l | grep nvidia-container-toolkit" 2>&1
    if ($LASTEXITCODE -eq 0 -and $checkInstalled) {
        Write-Host "  ✅ NVIDIA Container Toolkit is already installed" -ForegroundColor Green
        Write-Host "  $checkInstalled" -ForegroundColor Cyan
        
        $response = Read-Host "  Do you want to reinstall? (y/N)"
        if ($response -ne "y" -and $response -ne "Y") {
            Write-Host "  Skipping installation." -ForegroundColor Yellow
            exit 0
        }
    }
} catch {
    Write-Host "  ℹ️  NVIDIA Container Toolkit not found, proceeding with installation..." -ForegroundColor Cyan
}

# Install NVIDIA Container Toolkit
Write-Host "`n[3/5] Installing NVIDIA Container Toolkit..." -ForegroundColor Yellow
Write-Host "  This may take a few minutes..." -ForegroundColor Cyan

$installScript = @"
set -e
echo '[$(date +%H:%M:%S)] Updating package list...'
sudo apt-get update -qq

echo '[$(date +%H:%M:%S)] Installing prerequisites...'
sudo apt-get install -y -qq curl ca-certificates gnupg lsb-release

echo '[$(date +%H:%M:%S)] Adding NVIDIA Container Toolkit repository...'
distribution=\$(. /etc/os-release;echo \$ID\$VERSION_ID)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/\$distribution/libnvidia-container.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null

echo '[$(date +%H:%M:%S)] Installing NVIDIA Container Toolkit...'
sudo apt-get update -qq
sudo apt-get install -y -qq nvidia-container-toolkit

echo '[$(date +%H:%M:%S)] ✅ Installation complete!'
"@

try {
    Write-Host "  Running installation commands in WSL2..." -ForegroundColor Cyan
    wsl -d $ubuntuDistro -- bash -c $installScript
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ NVIDIA Container Toolkit installed successfully" -ForegroundColor Green
    } else {
        Write-Error "Installation failed with exit code $LASTEXITCODE"
        exit 1
    }
} catch {
    Write-Error "Error during installation: $_"
    exit 1
}

# Configure Docker runtime
Write-Host "`n[4/5] Configuring Docker runtime..." -ForegroundColor Yellow
Write-Host "  Note: Docker Desktop uses its own Docker daemon configuration" -ForegroundColor Cyan
Write-Host "  We'll configure the runtime, but you may need to restart Docker Desktop" -ForegroundColor Cyan

$configureScript = @"
set -e
echo '[$(date +%H:%M:%S)] Configuring NVIDIA runtime for Docker...'
sudo nvidia-ctk runtime configure --runtime=docker

echo '[$(date +%H:%M:%S)] ✅ Runtime configured!'
"@

try {
    wsl -d $ubuntuDistro -- bash -c $configureScript
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Docker runtime configured" -ForegroundColor Green
    } else {
        Write-Warning "Runtime configuration may have failed, but continuing..."
    }
} catch {
    Write-Warning "Error configuring runtime: $_"
}

# Verify installation
Write-Host "`n[5/5] Verifying installation..." -ForegroundColor Yellow
try {
    $verifyToolkit = wsl -d $ubuntuDistro -- bash -c "dpkg -l | grep nvidia-container-toolkit" 2>&1
    if ($LASTEXITCODE -eq 0 -and $verifyToolkit) {
        Write-Host "  ✅ NVIDIA Container Toolkit: $verifyToolkit" -ForegroundColor Green
    }
    
    $verifyRuntime = wsl -d $ubuntuDistro -- bash -c "which nvidia-container-runtime" 2>&1
    if ($LASTEXITCODE -eq 0 -and $verifyRuntime) {
        Write-Host "  ✅ nvidia-container-runtime: $verifyRuntime" -ForegroundColor Green
    }
    
    # Check GPU visibility in WSL2
    $gpuCheck = wsl -d $ubuntuDistro -- bash -c "nvidia-smi 2>&1" 2>&1
    if ($LASTEXITCODE -eq 0 -and $gpuCheck -match "NVIDIA") {
        Write-Host "  ✅ GPU is visible in WSL2" -ForegroundColor Green
    } else {
        Write-Warning "GPU may not be visible in WSL2. Ensure NVIDIA WSL2 drivers are installed."
    }
} catch {
    Write-Warning "Verification had some issues: $_"
}

# Summary and next steps
Write-Host "`n" -NoNewline
Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Installation Complete                                      ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

Write-Host "`n📋 Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Restart Docker Desktop (completely quit and restart)" -ForegroundColor White
Write-Host "  2. Run the debug script to verify:" -ForegroundColor White
Write-Host "     .\Debug-DockerNvidia.ps1" -ForegroundColor Yellow
Write-Host "  3. Test GPU support with:" -ForegroundColor White
Write-Host "     docker run --rm --gpus all nvidia/cuda:11.0.3-base-ubuntu20.04 nvidia-smi" -ForegroundColor Yellow
Write-Host "  4. If GPU test fails, ensure:" -ForegroundColor White
Write-Host "     - NVIDIA drivers are up to date on Windows" -ForegroundColor White
Write-Host "     - WSL2 CUDA drivers are installed from NVIDIA" -ForegroundColor White
Write-Host "     - Docker Desktop is using WSL2 backend" -ForegroundColor White

Write-Host "`n💡 Important Notes:" -ForegroundColor Cyan
Write-Host "  • Docker Desktop manages its own Docker daemon" -ForegroundColor White
Write-Host "  • The NVIDIA runtime config is in WSL2, but Docker Desktop needs to be restarted" -ForegroundColor White
Write-Host "  • If issues persist, check Docker Desktop Settings > Resources > WSL Integration" -ForegroundColor White

Write-Host "`n"



