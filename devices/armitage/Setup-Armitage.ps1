<#
.SYNOPSIS
    Initial setup script for Armitage Windows workstation
.DESCRIPTION
    Configures the Armitage workstation with necessary tools, services, and optimizations
    for development and gaming workflows
#>

param(
    [switch]$SkipDocker,
    [switch]$SkipWSL,
    [switch]$SkipTailscale,
    [switch]$SkipNvidia
)

$ErrorActionPreference = "Stop"

Write-Host @"
╔═══════════════════════════════════════╗
║   Armitage Workstation Setup          ║
║   Windows 11 + RTX 4070               ║
╚═══════════════════════════════════════╝
"@ -ForegroundColor Cyan

# Check for admin privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script must be run as Administrator. Please restart PowerShell as Administrator."
    exit 1
}

function Install-WSL2 {
    if ($SkipWSL) {
        Write-Host "Skipping WSL2 installation" -ForegroundColor Yellow
        return
    }
    
    Write-Host "`n📦 Installing WSL2..." -ForegroundColor Green
    
    # Enable WSL feature
    dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
    
    # Enable Virtual Machine feature
    dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
    
    # Set WSL2 as default
    wsl --set-default-version 2
    
    # Install Ubuntu 22.04
    Write-Host "Installing Ubuntu 22.04 for WSL2..."
    wsl --install -d Ubuntu-22.04
    
    Write-Host "✅ WSL2 installation complete" -ForegroundColor Green
}

function Install-DockerDesktop {
    if ($SkipDocker) {
        Write-Host "Skipping Docker Desktop installation" -ForegroundColor Yellow
        return
    }
    
    Write-Host "`n📦 Setting up Docker Desktop..." -ForegroundColor Green
    
    # Check if Docker Desktop is installed
    $dockerPath = "${env:ProgramFiles}\Docker\Docker\Docker Desktop.exe"
    
    if (Test-Path $dockerPath) {
        Write-Host "Docker Desktop is already installed" -ForegroundColor Yellow
    }
    else {
        Write-Host "Please install Docker Desktop manually from: https://www.docker.com/products/docker-desktop"
        Write-Host "Ensure WSL2 backend is enabled during installation"
        Read-Host "Press Enter once Docker Desktop is installed"
    }
    
    Write-Host "✅ Docker Desktop setup complete" -ForegroundColor Green
}

function Configure-NvidiaTools {
    if ($SkipNvidia) {
        Write-Host "Skipping NVIDIA configuration" -ForegroundColor Yellow
        return
    }
    
    Write-Host "`n🎮 Configuring NVIDIA GPU..." -ForegroundColor Green
    
    # Check for NVIDIA GPU
    $gpu = Get-WmiObject Win32_VideoController | Where-Object { $_.Name -like "*NVIDIA*RTX 4070*" }
    
    if (-not $gpu) {
        Write-Warning "NVIDIA RTX 4070 not detected. Skipping GPU configuration."
        return
    }
    
    Write-Host "Found: $($gpu.Name)"
    
    # Check for NVIDIA drivers
    $nvidiaSmi = "${env:ProgramFiles}\NVIDIA Corporation\NVSMI\nvidia-smi.exe"
    
    if (Test-Path $nvidiaSmi) {
        Write-Host "NVIDIA drivers installed"
        & $nvidiaSmi --query-gpu=name,driver_version,memory.total --format=csv,noheader
    }
    else {
        Write-Warning "NVIDIA drivers not found. Please install the latest drivers from nvidia.com"
    }
    
    # Enable GPU scheduling
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
    Set-ItemProperty -Path $regPath -Name "HwSchMode" -Value 2 -Type DWord
    Write-Host "Hardware-accelerated GPU scheduling enabled"
    
    Write-Host "✅ NVIDIA configuration complete" -ForegroundColor Green
}

function Install-Tailscale {
    if ($SkipTailscale) {
        Write-Host "Skipping Tailscale installation" -ForegroundColor Yellow
        return
    }
    
    Write-Host "`n🔐 Setting up Tailscale..." -ForegroundColor Green
    
    # Check if Tailscale is installed
    $tailscale = Get-Command tailscale -ErrorAction SilentlyContinue
    
    if ($tailscale) {
        Write-Host "Tailscale is already installed"
        tailscale status
    }
    else {
        Write-Host "Installing Tailscale..."
        # Download and install Tailscale
        $url = "https://pkgs.tailscale.com/stable/tailscale-setup-latest-amd64.msi"
        $installer = "$env:TEMP\tailscale-setup.msi"
        
        Invoke-WebRequest -Uri $url -OutFile $installer
        Start-Process msiexec.exe -ArgumentList "/i", $installer, "/quiet" -Wait
        
        Write-Host "Tailscale installed. Please authenticate with: tailscale up"
    }
    
    Write-Host "✅ Tailscale setup complete" -ForegroundColor Green
}

function Configure-PowerSettings {
    Write-Host "`n⚡ Configuring power settings..." -ForegroundColor Green
    
    # Create Ultimate Performance power plan if it doesn't exist
    powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61
    
    # Disable USB selective suspend
    powercfg /SETACVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
    
    # Disable PCI Express Link State Power Management
    powercfg /SETACVALUEINDEX SCHEME_CURRENT 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0
    
    Write-Host "✅ Power settings configured" -ForegroundColor Green
}

function Configure-WindowsFeatures {
    Write-Host "`n🔧 Configuring Windows features..." -ForegroundColor Green
    
    # Enable Windows features for development
    $features = @(
        "Microsoft-Hyper-V-All",
        "Microsoft-Windows-Subsystem-Linux",
        "VirtualMachinePlatform",
        "Containers-DisposableClientVM"  # Windows Sandbox
    )
    
    foreach ($feature in $features) {
        Write-Host "Enabling $feature..."
        Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart -ErrorAction SilentlyContinue
    }
    
    # Disable unnecessary features
    Write-Host "Disabling telemetry services..."
    Get-Service DiagTrack,dmwappushservice -ErrorAction SilentlyContinue | Stop-Service -PassThru | Set-Service -StartupType Disabled
    
    Write-Host "✅ Windows features configured" -ForegroundColor Green
}

function Create-DesktopShortcuts {
    Write-Host "`n🔗 Creating desktop shortcuts..." -ForegroundColor Green
    
    $desktop = [Environment]::GetFolderPath("Desktop")
    
    # Create shortcut for mode switcher
    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("$desktop\Armitage Mode Switcher.lnk")
    $Shortcut.TargetPath = "powershell.exe"
    $scriptPath = Join-Path $PSScriptRoot "scripts\Set-WorkstationMode.ps1"
    $Shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$scriptPath`""
    $Shortcut.IconLocation = "shell32.dll,24"
    $Shortcut.Save()
    
    Write-Host "✅ Desktop shortcuts created" -ForegroundColor Green
}

# Main execution
try {
    Install-WSL2
    Install-DockerDesktop
    Configure-NvidiaTools
    Install-Tailscale
    Configure-PowerSettings
    Configure-WindowsFeatures
    Create-DesktopShortcuts
    
    Write-Host @"

╔═══════════════════════════════════════════════════════════╗
║   ✅ Armitage Setup Complete!                             ║
╠═══════════════════════════════════════════════════════════╣
║   Next steps:                                             ║
║   1. Restart your computer to apply all changes          ║
║   2. Run 'tailscale up' to connect to Tailnet           ║
║   3. Use Mode Switcher shortcut to switch modes         ║
║   4. Configure WSL2 GPU support if needed               ║
╚═══════════════════════════════════════════════════════════╝
"@ -ForegroundColor Green
    
    $restart = Read-Host "`nRestart now? (Y/N)"
    if ($restart -eq 'Y') {
        Restart-Computer -Force
    }
}
catch {
    Write-Error "Setup failed: $_"
    exit 1
}