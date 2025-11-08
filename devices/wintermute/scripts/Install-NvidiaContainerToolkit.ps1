<#
.SYNOPSIS
    Installs NVIDIA Container Toolkit in WSL2 Ubuntu 24.04
.DESCRIPTION
    This script runs the NVIDIA Container Toolkit installation script inside WSL2 Ubuntu 24.04.
    The actual installation script runs inside WSL2 for proper execution.
    
    This is a manual step for observability - you can watch the installation progress.
#>

param(
    [switch]$SkipVerification
)

$ErrorActionPreference = "Stop"

Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host "   NVIDIA Container Toolkit Installation" -ForegroundColor Cyan
Write-Host "   WSL2 Ubuntu 24.04" -ForegroundColor Cyan
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host ""

# Check if Ubuntu 24.04 is available
# Try to use Ubuntu-24.04 directly - if it fails, we'll catch it
$ubuntu24Name = "Ubuntu-24.04"

# Verify it exists by trying to get its status
$testOutput = wsl -d $ubuntu24Name -- echo "test" 2>&1
if ($LASTEXITCODE -ne 0 -and $testOutput -match "not found|does not exist") {
    Write-Host "Available distributions:" -ForegroundColor Yellow
    wsl --list --verbose
    Write-Error "Ubuntu 24.04 not found. Please install it first: wsl --install -d Ubuntu-24.04"
    exit 1
}

Write-Host "Found Ubuntu 24.04 distribution: $ubuntu24Name" -ForegroundColor Green

# Get script path
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$installScript = Join-Path $scriptDir "install-nvidia-container-toolkit.sh"

if (-not (Test-Path $installScript)) {
    Write-Error "Installation script not found: $installScript"
    exit 1
}

Write-Host "Copying installation script to WSL2..." -ForegroundColor Yellow
# Copy script to WSL2 home directory with Unix line endings
$wslHome = wsl -d $ubuntu24Name -- bash -c "echo `$HOME"
$wslScriptPath = "$wslHome/install-nvidia-container-toolkit.sh"

# Read the script and convert line endings, then write to WSL2
$scriptContent = Get-Content $installScript -Raw
# Convert CRLF to LF
$scriptContent = $scriptContent -replace "`r`n", "`n"
# Write to WSL2 using bash
$scriptContent | wsl -d $ubuntu24Name -- bash -c "cat > $wslScriptPath"

Write-Host "Making script executable..." -ForegroundColor Yellow
wsl -d $ubuntu24Name -- bash -c "chmod +x $wslScriptPath"

Write-Host ""
Write-Host "===============================================================" -ForegroundColor Green
Write-Host "   Running installation inside WSL2..." -ForegroundColor Green
Write-Host "===============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "IMPORTANT: This will prompt for your WSL2 sudo password." -ForegroundColor Yellow
Write-Host "If the script appears hung, it's waiting for password input." -ForegroundColor Yellow
Write-Host ""
Write-Host "Alternative: Run the installation manually inside WSL2:" -ForegroundColor Cyan
Write-Host "  1. Open WSL2: wsl -d Ubuntu-24.04" -ForegroundColor White
Write-Host "  2. Run: bash ~/install-nvidia-container-toolkit.sh" -ForegroundColor White
Write-Host ""
Write-Host "Press Ctrl+C to cancel and run manually, or wait for password prompt..." -ForegroundColor Yellow
Write-Host ""

# Run the installation script inside WSL2
# Note: This will hang waiting for sudo password - user needs to interact
wsl -d $ubuntu24Name -- bash -c "bash $wslScriptPath"

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "===============================================================" -ForegroundColor Green
    Write-Host "   Installation Complete!" -ForegroundColor Green
    Write-Host "===============================================================" -ForegroundColor Green
    Write-Host ""
    
    if (-not $SkipVerification) {
        Write-Host "Verifying installation..." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Testing GPU access from Docker..." -ForegroundColor Cyan
        wsl -d $ubuntu24Name -- bash -c "docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu24.04 nvidia-smi"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "✅ NVIDIA Container Toolkit is working correctly!" -ForegroundColor Green
        } else {
            Write-Host ""
            Write-Warning "⚠️  GPU test failed. Check Docker Desktop settings and ensure WSL2 backend is enabled."
        }
    }
} else {
    Write-Error "Installation failed. Check the output above for errors."
    exit 1
}

