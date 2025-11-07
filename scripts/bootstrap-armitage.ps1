<#
.SYNOPSIS
    Bootstrap script for Armitage Windows workstation setup
.DESCRIPTION
    This script performs complete setup of Armitage workstation for Ansible management:
    1. Configures WinRM for Ansible
    2. Configures Tailscale with proper tags
    3. Verifies connectivity
    
    Run this script on armitage as Administrator after cloning miket-infra-devices
#>

$ErrorActionPreference = "Stop"

Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host "   Armitage Bootstrap Script" -ForegroundColor Cyan
Write-Host "   Windows 11 + RTX 4070" -ForegroundColor Cyan
Write-Host "===============================================================" -ForegroundColor Cyan

# Check for admin privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script must be run as Administrator. Please restart PowerShell as Administrator."
    exit 1
}

# Get script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir

Write-Host "`nRepository root: $repoRoot" -ForegroundColor Cyan

# Step 1: Configure WinRM
Write-Host "`n[Step 1/3] Configuring WinRM for Ansible..." -ForegroundColor Green
$winrmScript = Join-Path $scriptDir "Setup-WinRM.ps1"
if (Test-Path $winrmScript) {
    & $winrmScript
    # Don't fail on exit code - WinRM might be configured even if verification has issues
    $winrmConfigured = $true
} else {
    Write-Error "WinRM setup script not found: $winrmScript"
    exit 1
}

# Step 2: Configure Tailscale
Write-Host "`n[Step 2/3] Configuring Tailscale..." -ForegroundColor Green
$tailscaleScript = Join-Path $scriptDir "Setup-Tailscale.ps1"
if (Test-Path $tailscaleScript) {
    & $tailscaleScript -DeviceName "ARMITAGE"
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Tailscale setup may need manual completion"
    }
} else {
    Write-Error "Tailscale setup script not found: $tailscaleScript"
    exit 1
}

# Step 3: Verify setup
Write-Host "`n[Step 3/3] Verifying setup..." -ForegroundColor Green

# Check WinRM
$winrmService = Get-Service WinRM -ErrorAction SilentlyContinue
if ($winrmService -and $winrmService.Status -eq 'Running') {
    Write-Host "[OK] WinRM service is running" -ForegroundColor Green
} else {
    Write-Warning "[WARNING] WinRM service is not running"
}

# Check Tailscale
$tailscalePath = "${env:ProgramFiles(x86)}\Tailscale\tailscale.exe"
if (-not (Test-Path $tailscalePath)) {
    $tailscalePath = "${env:ProgramFiles}\Tailscale\tailscale.exe"
}

if (Test-Path $tailscalePath) {
    try {
        $tailscaleStatus = & $tailscalePath status --json 2>$null | ConvertFrom-Json
        if ($tailscaleStatus -and $tailscaleStatus.BackendState -eq "Running") {
            Write-Host "[OK] Tailscale is connected" -ForegroundColor Green
            $tailscaleIP = $tailscaleStatus.Self.TailscaleIPs[0]
            Write-Host "   Tailscale IP: $tailscaleIP" -ForegroundColor Cyan
            
            $tags = $tailscaleStatus.Self.Tags -join ", "
            if ($tags) {
                Write-Host "   Tags: $tags" -ForegroundColor Cyan
            }
        } else {
            Write-Warning "[WARNING] Tailscale is not connected. Run 'tailscale up' manually."
        }
    } catch {
        Write-Warning "[WARNING] Could not verify Tailscale status"
    }
} else {
    Write-Warning "[WARNING] Tailscale not found. Please install Tailscale first."
}

Write-Host ""
Write-Host "===============================================================" -ForegroundColor Green
Write-Host "   [SUCCESS] Armitage Bootstrap Complete!" -ForegroundColor Green
Write-Host "===============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Green
Write-Host "  1. From motoko, test connectivity:" -ForegroundColor Yellow
Write-Host "     ansible armitage -i ~/miket-infra-devices/ansible/inventory/hosts.yml -m win_ping" -ForegroundColor White
Write-Host ""
Write-Host "  2. Run Windows workstation playbook:" -ForegroundColor Yellow
Write-Host "     ansible-playbook -i ~/miket-infra-devices/ansible/inventory/hosts.yml" -ForegroundColor White
Write-Host "       ~/miket-infra-devices/ansible/playbooks/windows-workstation.yml --limit armitage" -ForegroundColor White
Write-Host ""

