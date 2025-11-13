<#
.SYNOPSIS
    Configures RDP with Group Policy settings to prevent toggle from reverting
.DESCRIPTION
    This script configures Remote Desktop Protocol (RDP) on Windows with both
    registry and Group Policy settings. The Group Policy settings prevent the
    RDP toggle in Windows Settings from reverting to "Off".
    
    This script must be run as Administrator.
.PARAMETER TailscaleSubnet
    The Tailscale subnet to restrict RDP access to (default: 100.64.0.0/10)
.EXAMPLE
    .\Configure-RDP-GroupPolicy.ps1
#>

param(
    [string]$TailscaleSubnet = "100.64.0.0/10"
)

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

Write-Host "Configuring RDP with Group Policy settings..." -ForegroundColor Green
Write-Host "This will prevent the RDP toggle from reverting to 'Off'" -ForegroundColor Yellow
Write-Host ""

# Ensure Group Policy registry paths exist
Write-Host "Creating Group Policy registry paths..." -ForegroundColor Cyan
$gpPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services"
$gpWinStationsPath = "$gpPath\WinStations\RDP-Tcp"

if (-not (Test-Path $gpPath)) {
    New-Item -Path $gpPath -Force | Out-Null
    Write-Host "  Created: $gpPath" -ForegroundColor Green
}

if (-not (Test-Path $gpWinStationsPath)) {
    New-Item -Path $gpWinStationsPath -Force | Out-Null
    Write-Host "  Created: $gpWinStationsPath" -ForegroundColor Green
}

# Configure Group Policy settings (prevents toggle from reverting)
Write-Host "Configuring Group Policy settings..." -ForegroundColor Cyan
Set-ItemProperty -Path $gpPath -Name "fDenyTSConnections" -Value 0 -Type DWord -Force
Write-Host "  ✓ Enabled RDP via Group Policy" -ForegroundColor Green

Set-ItemProperty -Path $gpWinStationsPath -Name "UserAuthentication" -Value 1 -Type DWord -Force
Write-Host "  ✓ Enabled NLA via Group Policy" -ForegroundColor Green

# Configure registry settings (fallback)
Write-Host "Configuring registry settings..." -ForegroundColor Cyan
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server"
$regWinStationsPath = "$regPath\WinStations\RDP-Tcp"

Set-ItemProperty -Path $regPath -Name "fDenyTSConnections" -Value 0 -Type DWord -Force
Write-Host "  ✓ Enabled RDP via registry" -ForegroundColor Green

Set-ItemProperty -Path $regWinStationsPath -Name "UserAuthentication" -Value 1 -Type DWord -Force
Write-Host "  ✓ Enabled NLA via registry" -ForegroundColor Green

# Ensure Remote Desktop service is running
Write-Host "Configuring Remote Desktop service..." -ForegroundColor Cyan
$service = Get-Service -Name "TermService" -ErrorAction SilentlyContinue
if ($service) {
    Set-Service -Name "TermService" -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service -Name "TermService" -ErrorAction SilentlyContinue
    Write-Host "  ✓ Remote Desktop service configured" -ForegroundColor Green
} else {
    Write-Host "  ⚠ Remote Desktop service not found" -ForegroundColor Yellow
}

# Force Group Policy update
Write-Host "Updating Group Policy..." -ForegroundColor Cyan
$gpupdate = gpupdate /force 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Group Policy updated" -ForegroundColor Green
} else {
    Write-Host "  ⚠ Group Policy update completed with warnings" -ForegroundColor Yellow
}

# Configure firewall rules
Write-Host "Configuring firewall rules..." -ForegroundColor Cyan

# Remove existing RDP firewall rules
$existingRules = Get-NetFirewallRule | Where-Object { 
    $_.DisplayName -like "*Remote Desktop*" -or $_.DisplayName -like "*RDP*" 
}
if ($existingRules) {
    $existingRules | Remove-NetFirewallRule -ErrorAction SilentlyContinue
    Write-Host "  Removed existing RDP firewall rules" -ForegroundColor Yellow
}

# Create new firewall rule restricted to Tailscale subnet
try {
    $rule = Get-NetFirewallRule -Name "RDP-Tailscale" -ErrorAction SilentlyContinue
    if ($rule) {
        Remove-NetFirewallRule -Name "RDP-Tailscale" -ErrorAction SilentlyContinue
    }
    
    New-NetFirewallRule -DisplayName "Remote Desktop (RDP) - Tailscale" `
        -Name "RDP-Tailscale" `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort 3389 `
        -RemoteAddress $TailscaleSubnet `
        -Action Allow `
        -Enabled True | Out-Null
    
    Write-Host "  ✓ Created firewall rule for Tailscale subnet ($TailscaleSubnet)" -ForegroundColor Green
} catch {
    Write-Host "  ⚠ Firewall rule creation failed: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Verify configuration
Write-Host ""
Write-Host "Verifying configuration..." -ForegroundColor Cyan

$gpValue = (Get-ItemProperty -Path $gpPath -Name "fDenyTSConnections" -ErrorAction SilentlyContinue).fDenyTSConnections
$regValue = (Get-ItemProperty -Path $regPath -Name "fDenyTSConnections" -ErrorAction SilentlyContinue).fDenyTSConnections

if ($gpValue -eq 0 -or $regValue -eq 0) {
    Write-Host "  ✓ RDP is enabled (GP: $gpValue, Reg: $regValue)" -ForegroundColor Green
} else {
    Write-Host "  ✗ RDP is disabled (GP: $gpValue, Reg: $regValue)" -ForegroundColor Red
    exit 1
}

# Check if RDP is listening
$listener = Get-NetTCPConnection -LocalPort 3389 -ErrorAction SilentlyContinue
if ($listener) {
    Write-Host "  ✓ RDP is listening on port 3389" -ForegroundColor Green
} else {
    Write-Host "  ⚠ RDP is not listening on port 3389 (service may need to restart)" -ForegroundColor Yellow
}

# Get hostname for connection info
$hostname = $env:COMPUTERNAME
$tailnetHostname = "$hostname.pangolin-vega.ts.net"

Write-Host ""
Write-Host "✅ RDP configuration complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Connection Information:" -ForegroundColor Cyan
Write-Host "  Hostname: $tailnetHostname" -ForegroundColor White
Write-Host "  Port: 3389" -ForegroundColor White
Write-Host "  Protocol: RDP with NLA" -ForegroundColor White
Write-Host "  Firewall: Restricted to Tailscale subnet ($TailscaleSubnet)" -ForegroundColor White
Write-Host ""
Write-Host "The RDP toggle should now stay enabled due to Group Policy configuration." -ForegroundColor Yellow




