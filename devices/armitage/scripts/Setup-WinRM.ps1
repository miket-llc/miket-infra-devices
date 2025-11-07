<#
.SYNOPSIS
    Configures WinRM on Armitage for Ansible management
.DESCRIPTION
    Sets up Windows Remote Management (WinRM) to allow Ansible to manage this Windows workstation
    Run this script as Administrator on Armitage before deploying via Ansible
#>

$ErrorActionPreference = "Stop"

# Check for admin privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script must be run as Administrator"
    exit 1
}

Write-Host "Configuring WinRM for Ansible..." -ForegroundColor Green

# Enable WinRM
Write-Host "Enabling WinRM service..." -ForegroundColor Yellow
Enable-PSRemoting -Force -SkipNetworkProfileCheck

# Configure WinRM for HTTP (port 5985)
Write-Host "Configuring WinRM HTTP listener..." -ForegroundColor Yellow
winrm quickconfig -force -q

# Enable Basic authentication (required for Ansible)
Write-Host "Enabling Basic authentication..." -ForegroundColor Yellow
Set-Item WSMan:\localhost\Service\Auth\Basic -Value $true

# Allow unencrypted traffic (for local network/Tailscale)
Write-Host "Configuring WinRM settings..." -ForegroundColor Yellow
Set-Item WSMan:\localhost\Service\AllowUnencrypted -Value $true

# Configure firewall rule
Write-Host "Configuring firewall..." -ForegroundColor Yellow
$firewallRule = Get-NetFirewallRule -Name "WinRM-HTTP" -ErrorAction SilentlyContinue
if (-not $firewallRule) {
    New-NetFirewallRule -Name "WinRM-HTTP" -DisplayName "Windows Remote Management (HTTP-In)" -Enabled True -Profile Any -Protocol TCP -LocalPort 5985 -Action Allow
    Write-Host "Created firewall rule" -ForegroundColor Green
} else {
    Write-Host "Firewall rule already exists" -ForegroundColor Yellow
}

# Set WinRM service to automatic
Write-Host "Setting WinRM service to automatic..." -ForegroundColor Yellow
Set-Service -Name WinRM -StartupType Automatic
Start-Service -Name WinRM

# Configure trusted hosts (optional, for Tailscale network)
Write-Host "Configuring trusted hosts..." -ForegroundColor Yellow
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force

# Test WinRM
Write-Host "`nTesting WinRM configuration..." -ForegroundColor Yellow
try {
    $result = winrm id
    Write-Host "✅ WinRM is configured and running" -ForegroundColor Green
    Write-Host $result
} catch {
    Write-Warning "WinRM test failed: $_"
}

Write-Host "`n✅ WinRM configuration complete!" -ForegroundColor Green
Write-Host "`nYou can now manage this workstation via Ansible from motoko" -ForegroundColor Cyan
Write-Host "Test connection with:" -ForegroundColor Cyan
Write-Host "  ansible armitage -i ansible/inventory/hosts.yml -m win_ping -e 'ansible_password=MonkeyB0y'" -ForegroundColor White

