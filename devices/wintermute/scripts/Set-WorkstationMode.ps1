<#
.SYNOPSIS
    Manages workstation modes for Wintermute (gaming vs productivity vs development)
.DESCRIPTION
    Switches between gaming, productivity, and development modes by adjusting Windows settings,
    services, and GPU configurations for optimal performance
.PARAMETER Mode
    The mode to switch to: Gaming, Productivity, or Development
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Gaming", "Productivity", "Development")]
    [string]$Mode
)

$ErrorActionPreference = "Stop"

# Configuration for each mode
$ModeConfigs = @{
    Gaming = @{
        Description = "Optimized for gaming, streaming, and flight sims"
        Services = @{
            Stop = @(
                "WSearch",          # Windows Search
                "SysMain",          # Superfetch
                "DiagTrack",        # Diagnostics Tracking
                "TabletInputService" # Touch Keyboard
            )
            Start = @()
        }
        PowerPlan = "High performance"
        GameMode = $true
        GPUSettings = @{
            PreferMaxPerformance = $true
            DisableVSync = $false
        }
    }
    
    Productivity = @{
        Description = "Balanced for daily work"
        Services = @{
            Stop = @()
            Start = @(
                "WSearch",
                "SysMain"
            )
        }
        PowerPlan = "Balanced"
        GameMode = $false
        GPUSettings = @{
            PreferMaxPerformance = $false
            DisableVSync = $false
        }
    }
    
    Development = @{
        Description = "Optimized for development with Docker, WSL2, and vLLM"
        Services = @{
            Stop = @(
                "DiagTrack",
                "TabletInputService"
            )
            Start = @(
                "WSearch",
                "com.docker.service",
                "LxssManager"  # WSL
            )
        }
        PowerPlan = "Balanced"
        GameMode = $false
        GPUSettings = @{
            PreferMaxPerformance = $true  # For CUDA workloads
            DisableVSync = $true
        }
    }
}

function Set-WindowsGameMode {
    param([bool]$Enable)
    
    $regPath = "HKCU:\Software\Microsoft\GameBar"
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }
    
    $value = if ($Enable) { 1 } else { 0 }
    Set-ItemProperty -Path $regPath -Name "AutoGameModeEnabled" -Value $value -Type DWord
    Write-Host "Windows Game Mode: $(if ($Enable) { 'Enabled' } else { 'Disabled' })"
}

function Set-PowerPlan {
    param([string]$PlanName)
    
    $plans = @{
        "High performance" = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
        "Balanced" = "381b4222-f694-41f0-9685-ff5bb260df2e"
        "Power saver" = "a1841308-3541-4fab-bc81-f71556f20b4a"
    }
    
    if ($plans.ContainsKey($PlanName)) {
        powercfg /setactive $plans[$PlanName]
        Write-Host "Power plan set to: $PlanName"
    }
}

function Set-NvidiaProfile {
    param($GPUSettings)
    
    # Check if NVIDIA GPU is present
    $nvidia = Get-WmiObject Win32_VideoController | Where-Object { $_.Name -like "*NVIDIA*" }
    
    if ($nvidia) {
        Write-Host "Configuring NVIDIA GPU settings..."
        
        # Use nvidia-smi if available
        $nvidiaSmi = "${env:ProgramFiles}\NVIDIA Corporation\NVSMI\nvidia-smi.exe"
        if (Test-Path $nvidiaSmi) {
            if ($GPUSettings.PreferMaxPerformance) {
                & $nvidiaSmi -pm 1  # Enable persistence mode
                Write-Host "NVIDIA Persistence Mode: Enabled"
            }
            else {
                & $nvidiaSmi -pm 0  # Disable persistence mode
                Write-Host "NVIDIA Persistence Mode: Disabled"
            }
        }
    }
}

function Stop-Services {
    param([string[]]$ServiceNames)
    
    foreach ($service in $ServiceNames) {
        try {
            $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
            if ($svc -and $svc.Status -eq 'Running') {
                Stop-Service -Name $service -Force
                Write-Host "Stopped service: $service"
            }
        }
        catch {
            Write-Warning "Could not stop service $service : $_"
        }
    }
}

function Start-Services {
    param([string[]]$ServiceNames)
    
    foreach ($service in $ServiceNames) {
        try {
            $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
            if ($svc -and $svc.Status -ne 'Running') {
                Start-Service -Name $service
                Write-Host "Started service: $service"
            }
        }
        catch {
            Write-Warning "Could not start service $service : $_"
        }
    }
}

function Save-ModeState {
    param([string]$Mode)
    
    $statePath = "$env:LOCALAPPDATA\WintermuteMode"
    if (-not (Test-Path $statePath)) {
        New-Item -Path $statePath -ItemType Directory -Force | Out-Null
    }
    
    $state = @{
        Mode = $Mode
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        User = $env:USERNAME
    }
    
    $state | ConvertTo-Json | Set-Content -Path "$statePath\current_mode.json"
}

# Main execution
Write-Host "`nSwitching Wintermute to $Mode mode..." -ForegroundColor Cyan
Write-Host $ModeConfigs[$Mode].Description

# Check for admin privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script requires administrator privileges for some operations."
    Write-Warning "Some settings may not be applied."
}

$config = $ModeConfigs[$Mode]

# Stop services
if ($config.Services.Stop.Count -gt 0) {
    Write-Host "`nStopping services..."
    Stop-Services -ServiceNames $config.Services.Stop
}

# Start services
if ($config.Services.Start.Count -gt 0) {
    Write-Host "`nStarting services..."
    Start-Services -ServiceNames $config.Services.Start
}

# Set power plan
Write-Host "`nSetting power plan..."
Set-PowerPlan -PlanName $config.PowerPlan

# Configure Game Mode
Write-Host "`nConfiguring Windows Game Mode..."
Set-WindowsGameMode -Enable $config.GameMode

# Configure GPU
Write-Host "`nConfiguring GPU settings..."
Set-NvidiaProfile -GPUSettings $config.GPUSettings

# Save state
Save-ModeState -Mode $Mode

Write-Host "`n✅ Successfully switched to $Mode mode!" -ForegroundColor Green
Write-Host "Mode configuration saved to: $env:LOCALAPPDATA\WintermuteMode\current_mode.json"

