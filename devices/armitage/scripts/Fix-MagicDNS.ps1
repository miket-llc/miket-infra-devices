<#
.SYNOPSIS
    Quick fix for MagicDNS on Armitage (Windows)
.DESCRIPTION
    This script remediates the MagicDNS issue by re-enrolling Tailscale with --accept-dns flag.
    This is a one-time fix for devices that were enrolled before the setup scripts were updated.
    
    Run this script as Administrator on the Windows device.
    
    Usage: .\Fix-MagicDNS.ps1
#>

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

Write-Host "`n🔧 MagicDNS Remediation Script for Armitage" -ForegroundColor Cyan
Write-Host "==========================================`n" -ForegroundColor Cyan

# Find Tailscale executable
$tailscalePath = "${env:ProgramFiles(x86)}\Tailscale\tailscale.exe"
if (-not (Test-Path $tailscalePath)) {
    $tailscalePath = "${env:ProgramFiles}\Tailscale\tailscale.exe"
}

if (-not (Test-Path $tailscalePath)) {
    Write-Error "Tailscale is not installed. Please install Tailscale first."
    exit 1
}

Write-Host "Found Tailscale at: $tailscalePath" -ForegroundColor Green

# Check current status
Write-Host "`nChecking current Tailscale status..." -ForegroundColor Yellow
try {
    $status = & $tailscalePath status --json | ConvertFrom-Json
    
    if ($status.BackendState -ne "Running") {
        Write-Error "Tailscale is not running. Please start Tailscale first."
        exit 1
    }
    
    Write-Host "✅ Tailscale is running" -ForegroundColor Green
    
    # Get current tags
    $currentTags = if ($status.Self.Tags -and $status.Self.Tags.Count -gt 0) {
        $status.Self.Tags -join ","
    } else {
        # Fallback to default tags for armitage
        "tag:workstation,tag:windows,tag:gaming"
    }
    
    Write-Host "Current tags: $currentTags" -ForegroundColor Cyan
    
    # Check if DNS is already configured
    $dnsConfigured = $false
    if ($status.Self.DNS) {
        Write-Host "DNS server: $($status.Self.DNS)" -ForegroundColor Cyan
        $dnsConfigured = $true
    } else {
        Write-Host "⚠️  DNS not configured (this is the problem we're fixing)" -ForegroundColor Yellow
    }
    
} catch {
    Write-Error "Could not get Tailscale status: $_"
    exit 1
}

# Confirm before proceeding
Write-Host "`nThis will reset and re-enroll Tailscale with --accept-dns flag." -ForegroundColor Yellow
$confirm = Read-Host "Continue? (y/N)"
if ($confirm -ne 'y' -and $confirm -ne 'Y') {
    Write-Host "Aborted." -ForegroundColor Yellow
    exit 0
}

# Step 1: Reset Tailscale
Write-Host "`n[Step 1/3] Resetting Tailscale connection..." -ForegroundColor Green
& $tailscalePath up --reset
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Reset command completed (this is normal)"
}

Start-Sleep -Seconds 2

# Step 2: Re-enroll with --accept-dns
Write-Host "`n[Step 2/3] Re-enrolling with --accept-dns..." -ForegroundColor Green
Write-Host "Tags: $currentTags" -ForegroundColor Cyan
Write-Host "Flags: --accept-dns --accept-routes" -ForegroundColor Cyan

$tailscaleArgs = @(
    "up",
    "--advertise-tags=$currentTags",
    "--accept-routes",
    "--accept-dns"  # CRITICAL: This fixes MagicDNS
)

Write-Host "Running: tailscale $($tailscaleArgs -join ' ')" -ForegroundColor Gray
& $tailscalePath $tailscaleArgs

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to re-enroll Tailscale. You may need to authenticate via the Tailscale GUI."
    exit 1
}

Write-Host "✅ Re-enrollment initiated" -ForegroundColor Green

# Wait for connection to establish
Write-Host "`nWaiting for connection to establish..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# Step 3: Verify fix
Write-Host "`n[Step 3/3] Verifying MagicDNS fix..." -ForegroundColor Green
try {
    $finalStatus = & $tailscalePath status --json | ConvertFrom-Json
    
    if ($finalStatus.BackendState -eq "Running") {
        Write-Host "✅ Tailscale is running" -ForegroundColor Green
        
        # Check DNS configuration
        if ($finalStatus.Self.DNS) {
            Write-Host "✅ DNS configured: $($finalStatus.Self.DNS)" -ForegroundColor Green
        } else {
            Write-Warning "⚠️  DNS not yet configured. This may take a few moments."
            Write-Host "   Run 'tailscale status --json | ConvertFrom-Json | Select-Object -ExpandProperty Self | Select-Object DNS' to check later."
        }
        
        # Show status
        Write-Host "`nTailscale Status:" -ForegroundColor Cyan
        & $tailscalePath status
        
    } else {
        Write-Warning "Tailscale may need manual authentication. Check the system tray icon."
    }
    
} catch {
    Write-Warning "Could not verify status: $_"
}

Write-Host "`n✅ Remediation complete!" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Test hostname resolution: ping motoko" -ForegroundColor Cyan
Write-Host "2. Verify DNS: tailscale status --json | ConvertFrom-Json | Select-Object -ExpandProperty Self | Select-Object DNS" -ForegroundColor Cyan
Write-Host "3. Test RDP: Test-NetConnection -ComputerName motoko -Port 3389" -ForegroundColor Cyan

