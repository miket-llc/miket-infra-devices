<#
.SYNOPSIS
    Automatically detects workstation usage and switches between workstation and LLM serving modes
.DESCRIPTION
    Monitors user activity, GPU usage, and Docker containers to automatically switch Wintermute
    between workstation mode (when in use) and LLM serving mode (when idle)
.PARAMETER CheckInterval
    How often to check for activity (in seconds). Default: 60
.PARAMETER IdleThreshold
    Minutes of inactivity before switching to LLM mode. Default: 5
.PARAMETER ForceMode
    Force a specific mode: 'workstation', 'llm', or 'auto'
#>

param(
    [int]$CheckInterval = 60,
    [int]$IdleThreshold = 5,
    [ValidateSet('workstation', 'llm', 'auto')]
    [string]$ForceMode = 'auto'
)

$ErrorActionPreference = "Stop"
$StatePath = "$env:LOCALAPPDATA\WintermuteMode"
$StateFile = "$StatePath\current_mode.json"
$LogFile = "$StatePath\auto_mode_switcher.log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $logMessage
    Write-Host $logMessage
}

function Initialize-State {
    if (-not (Test-Path $StatePath)) {
        New-Item -Path $StatePath -ItemType Directory -Force | Out-Null
    }
    
    if (-not (Test-Path $StateFile)) {
        $initialState = @{
            Mode = "workstation"
            LastSwitch = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Reason = "Initialization"
        }
        $initialState | ConvertTo-Json | Set-Content -Path $StateFile
    }
}

function Get-CurrentMode {
    if (Test-Path $StateFile) {
        try {
            $state = Get-Content $StateFile | ConvertFrom-Json
            return $state.Mode
        } catch {
            return "workstation"
        }
    }
    return "workstation"
}

function Set-Mode {
    param(
        [ValidateSet('workstation', 'llm')]
        [string]$Mode,
        [string]$Reason
    )
    
    $currentMode = Get-CurrentMode
    if ($currentMode -eq $Mode) {
        return $false
    }
    
    Write-Log "Switching from $currentMode to $Mode mode. Reason: $Reason"
    
    # Call the mode switcher script
    $scriptPath = Join-Path $PSScriptRoot "Set-WorkstationMode.ps1"
    if (-not (Test-Path $scriptPath)) {
        $scriptPath = Join-Path (Split-Path $PSScriptRoot -Parent) "scripts\Set-WorkstationMode.ps1"
    }
    
    if ($Mode -eq "workstation") {
        & $scriptPath -Mode "Productivity"
    } else {
        & $scriptPath -Mode "Development"
    }
    
    # Update state
    $state = @{
        Mode = $Mode
        LastSwitch = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Reason = $Reason
    }
    $state | ConvertTo-Json | Set-Content -Path $StateFile
    
    return $true
}

function Test-UserActive {
    # Check for active user sessions
    $sessions = Get-CimInstance -ClassName Win32_LogonSession | 
        Where-Object { $_.LogonType -eq 2 -or $_.LogonType -eq 10 } |
        Where-Object { $_.Status -eq "Active" }
    
    if ($sessions.Count -gt 0) {
        # Check if user is actually using the system
        $idleTime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
        $currentTime = Get-Date
        
        # Check for recent keyboard/mouse activity (Windows 10/11)
        $idleThreshold = New-TimeSpan -Minutes $IdleThreshold
        $lastInput = Get-CimInstance Win32_OperatingSystem | 
            Select-Object -ExpandProperty LastBootUpTime
        
        # Simple check: if system has been up less than threshold, consider active
        $uptime = $currentTime - $idleTime
        if ($uptime.TotalMinutes -lt $IdleThreshold) {
            return $true
        }
        
        # Check for running applications that indicate workstation use
        $workstationApps = @("chrome", "firefox", "code", "devenv", "steam", "discord", "spotify")
        $runningProcesses = Get-Process | Where-Object { $_.MainWindowTitle -ne "" }
        
        foreach ($app in $workstationApps) {
            if ($runningProcesses | Where-Object { $_.ProcessName -like "*$app*" }) {
                return $true
            }
        }
    }
    
    return $false
}

function Test-GPUInUse {
    # Check if GPU is being used by non-Docker processes
    $nvidiaSmi = "${env:ProgramFiles}\NVIDIA Corporation\NVSMI\nvidia-smi.exe"
    
    if (-not (Test-Path $nvidiaSmi)) {
        return $false
    }
    
    try {
        $gpuInfo = & $nvidiaSmi --query-compute-apps=pid,process_name --format=csv,noheader 2>&1
        if ($LASTEXITCODE -eq 0 -and $gpuInfo) {
            # Check if any non-Docker processes are using GPU
            $processes = $gpuInfo | ForEach-Object {
                if ($_ -match '(\d+),\s*(.+)') {
                    [PSCustomObject]@{
                        PID = $matches[1]
                        Process = $matches[2]
                    }
                }
            }
            
            $nonDockerProcesses = $processes | Where-Object { 
                $_.Process -notlike "*docker*" -and 
                $_.Process -notlike "*vllm*" -and
                $_.Process -notlike "*nvidia*"
            }
            
            return ($nonDockerProcesses.Count -gt 0)
        }
    } catch {
        Write-Log "Error checking GPU usage: $_" "WARN"
    }
    
    return $false
}

function Test-DockerRunning {
    # Check if Docker Desktop is running
    $dockerService = Get-Service -Name "com.docker.service" -ErrorAction SilentlyContinue
    if ($dockerService -and $dockerService.Status -eq 'Running') {
        # Check if Docker daemon is accessible
        try {
            docker ps 2>&1 | Out-Null
            return ($LASTEXITCODE -eq 0)
        } catch {
            return $false
        }
    }
    return $false
}

function Test-VLLMContainerRunning {
    if (-not (Test-DockerRunning)) {
        return $false
    }
    
    try {
        $containers = docker ps --format "{{.Names}}" 2>&1
        if ($LASTEXITCODE -eq 0) {
            return ($containers -like "*vllm*")
        }
    } catch {
        return $false
    }
    
    return $false
}

function Start-VLLMContainer {
    Write-Log "Starting vLLM container..."
    
    # Check if vLLM script exists
    $vllmScript = Join-Path $PSScriptRoot "Start-VLLM.ps1"
    if (Test-Path $vllmScript) {
        & $vllmScript
    } else {
        Write-Log "vLLM startup script not found at $vllmScript" "WARN"
    }
}

function Stop-VLLMContainer {
    Write-Log "Stopping vLLM container..."
    
    try {
        docker stop $(docker ps -q --filter "name=vllm") 2>&1 | Out-Null
        Write-Log "vLLM container stopped"
    } catch {
        Write-Log "Error stopping vLLM container: $_" "WARN"
    }
}

function Main {
    Initialize-State
    
    if ($ForceMode -ne 'auto') {
        if ($ForceMode -eq 'workstation') {
            Set-Mode -Mode "workstation" -Reason "Forced by user"
            Stop-VLLMContainer
        } elseif ($ForceMode -eq 'llm') {
            Set-Mode -Mode "llm" -Reason "Forced by user"
            Start-VLLMContainer
        }
        return
    }
    
    # Auto mode detection
    $userActive = Test-UserActive
    $gpuInUse = Test-GPUInUse
    $vllmRunning = Test-VLLMContainerRunning
    $currentMode = Get-CurrentMode
    
    Write-Log "Status check - UserActive: $userActive, GPUInUse: $gpuInUse, VLLMRunning: $vllmRunning, CurrentMode: $currentMode"
    
    if ($userActive -or $gpuInUse) {
        # Workstation is in use - switch to workstation mode
        if ($currentMode -ne "workstation") {
            Set-Mode -Mode "workstation" -Reason "User activity detected"
            Stop-VLLMContainer
        }
    } else {
        # Workstation is idle - switch to LLM serving mode
        if ($currentMode -ne "llm") {
            Set-Mode -Mode "llm" -Reason "System idle - switching to LLM serving"
            Start-VLLMContainer
        } elseif (-not $vllmRunning) {
            # Already in LLM mode but container not running - start it
            Start-VLLMContainer
        }
    }
}

# Run as continuous loop or one-time check
if ($MyInvocation.InvocationName -ne '.') {
    if ($args.Count -eq 0) {
        # Continuous monitoring mode
        Write-Log "Starting automatic mode switcher (check interval: $CheckInterval seconds)"
        while ($true) {
            Main
            Start-Sleep -Seconds $CheckInterval
        }
    } else {
        # One-time check
        Main
    }
}

