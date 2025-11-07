<#
.SYNOPSIS
    Configures Tailscale on Windows devices with appropriate tags
.DESCRIPTION
    This script sets up Tailscale on Windows devices (Armitage, Wintermute)
    with tags as defined in miket-infra/infra/tailscale/entra-prod/devices.tf
.PARAMETER DeviceName
    Name of the device (defaults to hostname)
#>

param(
    [string]$DeviceName = $env:COMPUTERNAME
)

$ErrorActionPreference = "Stop"

Write-Host "Setting up Tailscale for: $DeviceName" -ForegroundColor Green

# Define device tags based on hostname
# These must match the tags defined in miket-infra/infra/tailscale/entra-prod/devices.tf
$deviceConfig = @{
    "ARMITAGE" = @{
        Tags = "tag:workstation,tag:windows,tag:gaming"
        SSH = $false  # Windows uses RDP/WinRM instead
        ExitNode = $false
    }
    "WINTERMUTE" = @{
        Tags = "tag:workstation,tag:windows,tag:gaming"
        SSH = $false
        ExitNode = $false
    }
}

$config = $deviceConfig[$DeviceName.ToUpper()]
if (-not $config) {
    Write-Error "Unknown device: $DeviceName"
    Write-Host "Please add device configuration to this script" -ForegroundColor Red
    exit 1
}

# Check if Tailscale is installed
$tailscalePath = "${env:ProgramFiles(x86)}\Tailscale\tailscale.exe"
if (-not (Test-Path $tailscalePath)) {
    $tailscalePath = "${env:ProgramFiles}\Tailscale\tailscale.exe"
}

if (-not (Test-Path $tailscalePath)) {
    Write-Host "Tailscale is not installed" -ForegroundColor Red
    Write-Host "Installing Tailscale..." -ForegroundColor Yellow
    
    # Download and install Tailscale
    $installerUrl = "https://pkgs.tailscale.com/stable/tailscale-setup-latest-amd64.msi"
    $installerPath = "$env:TEMP\tailscale-setup.msi"
    
    Write-Host "Downloading Tailscale installer..."
    Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath
    
    Write-Host "Installing Tailscale..."
    Start-Process msiexec.exe -ArgumentList "/i", $installerPath, "/quiet", "/norestart" -Wait
    
    # Refresh path
    $tailscalePath = "${env:ProgramFiles(x86)}\Tailscale\tailscale.exe"
    if (-not (Test-Path $tailscalePath)) {
        $tailscalePath = "${env:ProgramFiles}\Tailscale\tailscale.exe"
    }
}

# Check current status
Write-Host "Checking current Tailscale status..." -ForegroundColor Cyan
try {
    $status = & $tailscalePath status --json | ConvertFrom-Json
    if ($status.BackendState -eq "Running") {
        Write-Host "Tailscale is already connected" -ForegroundColor Yellow
        
        $currentTags = $status.Self.Tags -join ","
        Write-Host "Current tags: $($currentTags ?? 'none')"
        
        $response = Read-Host "Reconfigure with new tags? (y/N)"
        if ($response -ne 'y') {
            Write-Host "Keeping current configuration"
            exit 0
        }
    }
}
catch {
    Write-Host "Tailscale not connected yet"
}

# Build Tailscale up command
Write-Host "`nConfiguring Tailscale..." -ForegroundColor Green
Write-Host "Tags: $($config.Tags)"

$tailscaleArgs = @("up")
$tailscaleArgs += "--advertise-tags=$($config.Tags)"
$tailscaleArgs += "--accept-routes"

if ($config.ExitNode) {
    $tailscaleArgs += "--advertise-exit-node"
}

# Note: Windows doesn't use Tailscale SSH, it uses WinRM
Write-Host "Remote access: WinRM (port 5985/5986)"

Write-Host "Running: tailscale $($tailscaleArgs -join ' ')"
& $tailscalePath $tailscaleArgs

# Wait for connection
Start-Sleep -Seconds 3

# Verify connection
try {
    $finalStatus = & $tailscalePath status --json | ConvertFrom-Json
    if ($finalStatus.BackendState -eq "Running") {
        Write-Host "`n✅ Tailscale configured successfully!" -ForegroundColor Green
        & $tailscalePath status
    }
    else {
        Write-Host "❌ Tailscale configuration may need manual completion" -ForegroundColor Yellow
        Write-Host "Please check the Tailscale system tray icon"
    }
}
catch {
    Write-Host "❌ Could not verify Tailscale status" -ForegroundColor Red
}

# Enable WinRM for Ansible management
Write-Host "`nConfiguring WinRM for Ansible management..." -ForegroundColor Green

# Check if WinRM is configured
$winrmStatus = Get-Service WinRM
if ($winrmStatus.Status -ne 'Running') {
    Write-Host "Enabling WinRM..."
    Enable-PSRemoting -Force -SkipNetworkProfileCheck
    
    # Configure WinRM for Ansible
    Set-Item WSMan:\localhost\Service\Auth\Basic -Value $true
    Set-Item WSMan:\localhost\Service\AllowUnencrypted -Value $true
    
    # Set WinRM to automatic
    Set-Service -Name WinRM -StartupType Automatic
    
    # Configure firewall (allow from Tailscale network)
    New-NetFirewallRule -DisplayName "WinRM-HTTP-Tailscale" `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort 5985 `
        -RemoteAddress 100.64.0.0/10 `
        -Action Allow `
        -ErrorAction SilentlyContinue
}

Write-Host "`n✅ Setup complete!" -ForegroundColor Green
Write-Host "Device $DeviceName is now connected to the Tailnet with tags: $($config.Tags)"
Write-Host "`nThis device can now be managed via Ansible from motoko using:"
Write-Host "  ansible $($DeviceName.ToLower()) -m win_ping" -ForegroundColor Cyan