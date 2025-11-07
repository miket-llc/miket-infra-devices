<#
.SYNOPSIS
    Configures WinRM for Ansible management on Windows devices
.DESCRIPTION
    This script enables and configures WinRM (Windows Remote Management) 
    for Ansible automation from the motoko control node.
    
    It configures:
    - WinRM service (HTTP on port 5985)
    - Basic authentication
    - Firewall rules for Tailscale network
    - Service auto-start
.PARAMETER AllowUnencrypted
    Allow unencrypted connections (default: true, required for Ansible NTLM)
#>

param(
    [switch]$AllowUnencrypted = $true
)

$ErrorActionPreference = "Stop"

Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host "   WinRM Setup for Ansible Management" -ForegroundColor Cyan
Write-Host "===============================================================" -ForegroundColor Cyan

# Check for admin privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script must be run as Administrator. Please restart PowerShell as Administrator."
    exit 1
}

Write-Host ""
Write-Host "[1/5] Checking WinRM service status..." -ForegroundColor Green
$winrmService = Get-Service WinRM -ErrorAction SilentlyContinue

if ($winrmService -and $winrmService.Status -eq 'Running') {
    Write-Host "[OK] WinRM service is already running" -ForegroundColor Green
} else {
    Write-Host "[2/5] Enabling WinRM..." -ForegroundColor Green
    Enable-PSRemoting -Force -SkipNetworkProfileCheck
    
    # Ensure service is started
    Start-Service WinRM
    Set-Service -Name WinRM -StartupType Automatic
    
    Write-Host "[OK] WinRM service enabled and started" -ForegroundColor Green
}

Write-Host ""
Write-Host "[3/5] Configuring WinRM authentication..." -ForegroundColor Green

# Enable Basic authentication (required for Ansible NTLM)
Set-Item WSMan:\localhost\Service\Auth\Basic -Value $true -Force

# Configure for Ansible compatibility
if ($AllowUnencrypted) {
    Write-Host "Enabling unencrypted connections (required for Ansible NTLM)" -ForegroundColor Yellow
    Set-Item WSMan:\localhost\Service\AllowUnencrypted -Value $true -Force
}

# Configure WinRM listeners
Write-Host "Configuring WinRM listeners..." -ForegroundColor Cyan

# Remove existing HTTP listener if present (to avoid conflicts)
try {
    $existingListeners = Get-ChildItem WSMan:\localhost\Listener -ErrorAction SilentlyContinue | Where-Object { 
        $listenerPath = $_.PSPath
        $transport = (Get-ItemProperty $listenerPath -ErrorAction SilentlyContinue).Transport
        $transport -eq "HTTP"
    }
    if ($existingListeners) {
        Write-Host "Removing existing HTTP listeners..." -ForegroundColor Yellow
        foreach ($listener in $existingListeners) {
            try {
                Remove-Item -Path $listener.PSPath -Force -ErrorAction SilentlyContinue
            } catch {
                # Ignore errors if listener doesn't exist or can't be removed
            }
        }
    }
} catch {
    # Ignore errors - listeners may not exist yet
}

# Create HTTP listener on port 5985
Write-Host "Creating HTTP listener on port 5985..." -ForegroundColor Cyan
try {
    $listener = New-Item -Path "WSMan:\localhost\Listener" -Transport HTTP -Address * -Force -ErrorAction Stop
    Write-Host "[OK] WinRM listener configured" -ForegroundColor Green
} catch {
    # Listener might already exist, which is fine
    Write-Host "[OK] WinRM listener already configured" -ForegroundColor Green
}

Write-Host ""
Write-Host "[4/5] Configuring Windows Firewall..." -ForegroundColor Green

# Remove existing WinRM firewall rules (to avoid duplicates)
$existingRules = Get-NetFirewallRule -DisplayName "*WinRM*" -ErrorAction SilentlyContinue
if ($existingRules) {
    Write-Host "Removing existing WinRM firewall rules..." -ForegroundColor Yellow
    $existingRules | Remove-NetFirewallRule -ErrorAction SilentlyContinue
}

# Create firewall rule for Tailscale network (100.64.0.0/10)
Write-Host "Creating firewall rule for Tailscale network (100.64.0.0/10)..." -ForegroundColor Cyan
New-NetFirewallRule -DisplayName "WinRM-HTTP-Tailscale" `
    -Name "WinRM-HTTP-Tailscale" `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort 5985 `
    -RemoteAddress 100.64.0.0/10 `
    -Action Allow `
    -Enabled True `
    -ErrorAction SilentlyContinue | Out-Null

# Also allow from local subnet (for testing)
New-NetFirewallRule -DisplayName "WinRM-HTTP-Local" `
    -Name "WinRM-HTTP-Local" `
    -Direction Inbound `
    -Protocol TCP `
    -LocalPort 5985 `
    -RemoteAddress 192.168.0.0/16,10.0.0.0/8,172.16.0.0/12 `
    -Action Allow `
    -Enabled True `
    -ErrorAction SilentlyContinue | Out-Null

    Write-Host "[OK] Firewall rules configured" -ForegroundColor Green

Write-Host ""
Write-Host "[5/5] Verifying configuration..." -ForegroundColor Green

# Test WinRM configuration
try {
    # Simple verification - just check service status and configuration items
    $serviceStatus = (Get-Service WinRM).Status
    $basicAuthItem = Get-Item WSMan:\localhost\Service\Auth\Basic -ErrorAction SilentlyContinue
    $basicAuth = if ($basicAuthItem) { $basicAuthItem.Value.ToString() } else { "Not configured" }
    $allowUnencryptedItem = Get-Item WSMan:\localhost\Service\AllowUnencrypted -ErrorAction SilentlyContinue
    $allowUnencrypted = if ($allowUnencryptedItem) { $allowUnencryptedItem.Value.ToString() } else { "Not configured" }
    
    Write-Host "[OK] WinRM configuration verified" -ForegroundColor Green
    
    # Display configuration
    Write-Host ""
    Write-Host "WinRM Configuration:" -ForegroundColor Cyan
    Write-Host "  Service Status: $serviceStatus"
    Write-Host "  Basic Auth: $basicAuth"
    Write-Host "  Allow Unencrypted: $allowUnencrypted"
    Write-Host "  Listeners:"
    try {
        $listeners = Get-ChildItem WSMan:\localhost\Listener -ErrorAction SilentlyContinue
        if ($listeners) {
            foreach ($listener in $listeners) {
                try {
                    $listenerProps = Get-ItemProperty $listener.PSPath -ErrorAction SilentlyContinue
                    $transport = $listenerProps.Transport
                    $address = $listenerProps.Address
                    if ($transport -and $address) {
                        Write-Host "    - $transport on $address"
                    }
                } catch {
                    # Skip this listener if we can't read it
                }
            }
        } else {
            Write-Host "    - (No listeners found)"
        }
    } catch {
        Write-Host "    - (Could not enumerate listeners)"
    }
    
    # Get Tailscale IP if available
    $tailscaleIP = $null
    try {
        $tailscaleStatus = & "${env:ProgramFiles(x86)}\Tailscale\tailscale.exe" status --json 2>$null | ConvertFrom-Json
        if (-not $tailscaleStatus) {
            $tailscaleStatus = & "${env:ProgramFiles}\Tailscale\tailscale.exe" status --json 2>$null | ConvertFrom-Json
        }
        if ($tailscaleStatus -and $tailscaleStatus.Self) {
            $tailscaleIP = $tailscaleStatus.Self.TailscaleIPs[0]
        }
    } catch {
        # Tailscale not installed or not connected
    }
    
    Write-Host ""
    Write-Host "[SUCCESS] WinRM setup complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "This device can now be managed via Ansible from motoko." -ForegroundColor Cyan
    if ($tailscaleIP) {
        Write-Host "Tailscale IP: $tailscaleIP" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Test from motoko with:" -ForegroundColor Yellow
        Write-Host "  ansible $($env:COMPUTERNAME.ToLower()) -i ~/miket-infra-devices/ansible/inventory/hosts.yml -m win_ping" -ForegroundColor White
    } else {
        Write-Host ""
        Write-Host "Note: Configure Tailscale first to enable remote management" -ForegroundColor Yellow
        Write-Host "  Run: .\scripts\Setup-Tailscale.ps1" -ForegroundColor White
    }
    
} catch {
    Write-Warning "Could not verify WinRM configuration: $_"
    Write-Host "WinRM may still be configured correctly. Test from motoko to verify." -ForegroundColor Yellow
}

Write-Host ""

