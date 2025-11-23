<#
.SYNOPSIS
    Configures NoMachine firewall rules and disables RDP
.DESCRIPTION
    This script:
    - Configures firewall to allow NoMachine (port 4000) only from Tailscale subnet
    - Blocks NoMachine from public/private LANs
    - Disables Windows RDP
    - Ensures NoMachine service starts at boot
#>

$ErrorActionPreference = "Stop"

Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host "   NoMachine Firewall Configuration" -ForegroundColor Cyan
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host ""

# Check for admin privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script must be run as Administrator. Please restart PowerShell as Administrator."
    exit 1
}

# === 1. FIREWALL: Allow NoMachine ONLY from Tailscale ===
Write-Host "[1/3] Configuring Firewall..." -ForegroundColor Cyan

try {
    # Remove any loose/default rules from the installer
    $existingRules = Get-NetFirewallRule -DisplayName "*NoMachine*" -ErrorAction SilentlyContinue
    if ($existingRules) {
        Write-Host "  Removing existing NoMachine firewall rules..." -ForegroundColor Yellow
        $existingRules | Remove-NetFirewallRule -ErrorAction SilentlyContinue
    }

    # Allow TCP 4000 from Tailscale Subnet (100.64.0.0/10)
    Write-Host "  Creating allow rule for Tailscale subnet (100.64.0.0/10)..." -ForegroundColor Cyan
    $allowRule = Get-NetFirewallRule -Name "NoMachine-Tailscale-In" -ErrorAction SilentlyContinue
    if ($allowRule) {
        Remove-NetFirewallRule -Name "NoMachine-Tailscale-In" -ErrorAction SilentlyContinue
    }
    
    New-NetFirewallRule -DisplayName "NoMachine Tailscale In" `
        -Name "NoMachine-Tailscale-In" `
        -Direction Inbound `
        -LocalPort 4000 `
        -Protocol TCP `
        -Action Allow `
        -RemoteAddress 100.64.0.0/10 `
        -Description "Allow NoMachine access via Tailscale VPN only" `
        -Enabled True `
        -Profile Any `
        -ErrorAction Stop
    
    Write-Host "  [OK] Allow rule created" -ForegroundColor Green

    # Explicitly Block NoMachine from Public/Private LANs (Safety Net)
    # Note: Block rules are processed before Allow rules, so this provides defense in depth
    Write-Host "  Creating block rule for non-Tailscale networks..." -ForegroundColor Cyan
    $blockRule = Get-NetFirewallRule -Name "NoMachine-Block-WAN-LAN" -ErrorAction SilentlyContinue
    if ($blockRule) {
        Remove-NetFirewallRule -Name "NoMachine-Block-WAN-LAN" -ErrorAction SilentlyContinue
    }
    
    # Create block rule with multiple address ranges
    # Using array syntax for multiple ranges
    $blockAddresses = @(
        "0.0.0.0-99.255.255.255",
        "101.0.0.0-255.255.255.255"
    )
    
    New-NetFirewallRule -DisplayName "NoMachine Block WAN/LAN" `
        -Name "NoMachine-Block-WAN-LAN" `
        -Direction Inbound `
        -LocalPort 4000 `
        -Protocol TCP `
        -Action Block `
        -RemoteAddress $blockAddresses `
        -Description "Block NoMachine from non-Tailscale networks" `
        -Enabled True `
        -Profile Any `
        -ErrorAction Stop
    
    Write-Host "  [OK] Block rule created" -ForegroundColor Green
    Write-Host "[OK] Firewall configuration complete" -ForegroundColor Green
    
} catch {
    Write-Error "Failed to configure firewall: $_"
    exit 1
}

Write-Host ""

# === 2. SECURITY: Disable Windows RDP ===
Write-Host "[2/3] Disabling RDP..." -ForegroundColor Cyan

try {
    # Disable 'Allow remote connections to this computer'
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 1 -ErrorAction Stop
    Write-Host "  [OK] RDP registry setting updated" -ForegroundColor Green

    # Disable the RDP Firewall Rules
    $rdpRules = Get-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue
    if ($rdpRules) {
        $rdpRules | Disable-NetFirewallRule -ErrorAction SilentlyContinue
        Write-Host "  [OK] RDP firewall rules disabled" -ForegroundColor Green
    } else {
        Write-Host "  [INFO] No RDP firewall rules found to disable" -ForegroundColor Yellow
    }
    
    Write-Host "[OK] RDP disabled" -ForegroundColor Green
    
} catch {
    Write-Error "Failed to disable RDP: $_"
    exit 1
}

Write-Host ""

# === 3. SERVICE: Ensure NoMachine Starts at Boot ===
Write-Host "[3/3] Verifying NoMachine Service..." -ForegroundColor Cyan

try {
    # Check if service exists
    $service = Get-Service -Name "nxserver" -ErrorAction SilentlyContinue
    
    if (-not $service) {
        # Try alternative service names
        $altNames = @("NoMachine", "nxserver", "nx", "NoMachine*")
        $service = $null
        
        foreach ($name in $altNames) {
            $service = Get-Service -Name $name -ErrorAction SilentlyContinue
            if ($service) {
                Write-Host "  Found service: $($service.Name)" -ForegroundColor Yellow
                break
            }
        }
        
        if (-not $service) {
            Write-Warning "NoMachine service not found. Please ensure NoMachine is installed."
            Write-Host "  Searched for: nxserver, NoMachine, nx" -ForegroundColor Yellow
            Write-Host "  [SKIP] Service configuration skipped" -ForegroundColor Yellow
            exit 0
        }
    }
    
    # Configure service
    Write-Host "  Configuring service: $($service.Name)" -ForegroundColor Cyan
    Set-Service -Name $service.Name -StartupType Automatic -ErrorAction Stop
    
    # Start service if not running
    if ($service.Status -ne 'Running') {
        Write-Host "  Starting service..." -ForegroundColor Cyan
        Start-Service -Name $service.Name -ErrorAction Stop
        Write-Host "  [OK] Service started" -ForegroundColor Green
    } else {
        Write-Host "  [OK] Service already running" -ForegroundColor Green
    }
    
    Write-Host "[OK] NoMachine service configured" -ForegroundColor Green
    
} catch {
    Write-Error "Failed to configure NoMachine service: $_"
    Write-Host "  Note: Ensure NoMachine is installed before running this script" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "===============================================================" -ForegroundColor Green
Write-Host "   Configuration Complete!" -ForegroundColor Green
Write-Host "===============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  ✓ Firewall: NoMachine (port 4000) allowed from Tailscale only" -ForegroundColor Green
Write-Host "  ✓ Firewall: NoMachine blocked from WAN/LAN" -ForegroundColor Green
Write-Host "  ✓ RDP: Disabled" -ForegroundColor Green
Write-Host "  ✓ NoMachine: Service configured for auto-start" -ForegroundColor Green
Write-Host ""

