# Bootstrap script to create local automation account (mdt) on Windows
# This is a ONE-TIME bootstrap step - all future account management via Ansible
# Run as Administrator
#
# Usage:
#   .\scripts\bootstrap-windows-automation-account.ps1

param(
    [string]$AccountName = "mdt",
    [string]$Password = "MonkeyB0y",
    [string]$Description = "MDT - Infrastructure automation account"
)

#Requires -RunAsAdministrator

Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host "   Bootstrap: Windows Automation Account Setup" -ForegroundColor Cyan
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This script creates the local automation account required for Ansible."
Write-Host "After this, all account management should be done via Ansible (IaC/CaC)."
Write-Host ""

# Check if account already exists
$existingAccount = Get-LocalUser -Name $AccountName -ErrorAction SilentlyContinue
if ($existingAccount) {
    Write-Host "[INFO] Account '$AccountName' already exists" -ForegroundColor Yellow
    $accountExists = $true
} else {
    Write-Host "[STEP] Creating account '$AccountName'..." -ForegroundColor Green
    
    try {
        $securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
        New-LocalUser -Name $AccountName `
            -Password $securePassword `
            -Description $Description `
            -PasswordNeverExpires `
            -UserMayNotChangePassword `
            -ErrorAction Stop
        
        Write-Host "[OK] Account created successfully" -ForegroundColor Green
        $accountExists = $true
    } catch {
        Write-Host "[ERROR] Failed to create account: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Add to Administrators group
if ($accountExists) {
    Write-Host "[STEP] Adding to Administrators group..." -ForegroundColor Green
    
    try {
        $group = Get-LocalGroup -Name "Administrators" -ErrorAction Stop
        $user = Get-LocalUser -Name $AccountName -ErrorAction Stop
        
        $isMember = Get-LocalGroupMember -Group $group -Member $user -ErrorAction SilentlyContinue
        if ($isMember) {
            Write-Host "[OK] Already a member of Administrators group" -ForegroundColor Yellow
        } else {
            Add-LocalGroupMember -Group $group -Member $user -ErrorAction Stop
            Write-Host "[OK] Added to Administrators group" -ForegroundColor Green
        }
    } catch {
        Write-Host "[ERROR] Failed to add to Administrators: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Verify
Write-Host ""
Write-Host "[STEP] Verifying account setup..." -ForegroundColor Green
$user = Get-LocalUser -Name $AccountName -ErrorAction SilentlyContinue
$isAdmin = Get-LocalGroupMember -Group "Administrators" | Where-Object { $_.Name -like "*$AccountName*" }

if ($user -and $isAdmin) {
    Write-Host ""
    Write-Host "===============================================================" -ForegroundColor Green
    Write-Host "   [SUCCESS] Automation Account Setup Complete!" -ForegroundColor Green
    Write-Host "===============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Account Details:" -ForegroundColor Cyan
    Write-Host "  Name: $($user.Name)"
    Write-Host "  Description: $($user.Description)"
    Write-Host "  Enabled: $($user.Enabled)"
    Write-Host "  Administrators: Yes"
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. From motoko, test WinRM connectivity:"
    Write-Host "     ansible armitage -i ~/miket-infra-devices/ansible/inventory/hosts.yml -m win_ping"
    Write-Host ""
    Write-Host "  2. All future account management via Ansible (IaC/CaC)"
    Write-Host ""
} else {
    Write-Host "[ERROR] Account verification failed" -ForegroundColor Red
    exit 1
}

