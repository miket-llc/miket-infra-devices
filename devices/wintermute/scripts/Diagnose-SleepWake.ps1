<#
.SYNOPSIS
    Diagnoses Windows sleep/wake issues on Wintermute
.DESCRIPTION
    Checks Windows Event Logs, power settings, GPU drivers, and USB devices
    to identify why the system may have failed to wake from sleep
#>

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Wintermute Sleep/Wake Diagnostics" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check for admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Warning "Some checks require administrator privileges. Run as Administrator for full diagnostics."
    Write-Host ""
}

# 1. Check Recent Sleep/Wake Events
Write-Host "[1] Checking Windows Event Logs for Sleep/Wake Events..." -ForegroundColor Yellow
Write-Host ""

try {
    # Get sleep events from last 24 hours
    # Key event IDs: 42 (sleep), 107 (resume), 109 (hibernate), 131 (hibernate resume), 6008 (unexpected shutdown)
    $sleepEvents = Get-WinEvent -FilterHashtable @{
        LogName = 'System'
        ProviderName = 'Microsoft-Windows-Kernel-Power'
        StartTime = (Get-Date).AddHours(-24)
    } -ErrorAction SilentlyContinue | Where-Object {
        # Filter for important power events
        $_.Id -in @(42, 107, 109, 131, 6008) -or 
        ($_.Id -ge 506 -and $_.Id -le 600) -or
        ($_.LevelDisplayName -eq 'Error' -or $_.LevelDisplayName -eq 'Warning')
    }
    
    if ($sleepEvents) {
        Write-Host "  Recent sleep/wake events found:" -ForegroundColor Cyan
        $sleepEvents | Select-Object -First 10 | ForEach-Object {
            $time = $_.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
            $id = $_.Id
            $message = $_.Message -replace "`n", " " -replace "`r", ""
            if ($message.Length -gt 100) { $message = $message.Substring(0, 100) + "..." }
            Write-Host "    [$time] Event ID $id : $message" -ForegroundColor Gray
        }
        
        # Check for specific error events
        $errorEvents = $sleepEvents | Where-Object { $_.LevelDisplayName -eq 'Error' -or $_.LevelDisplayName -eq 'Warning' }
        if ($errorEvents) {
            Write-Host ""
            Write-Host "  ⚠️  ERROR/WARNING events found:" -ForegroundColor Red
            $errorEvents | Select-Object -First 5 | ForEach-Object {
                Write-Host "    Event ID $($_.Id) at $($_.TimeCreated): $($_.Message.Substring(0, [Math]::Min(150, $_.Message.Length)))" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "  ⚠️  No recent sleep/wake events found in last 24 hours" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ⚠️  Error reading event logs: $_" -ForegroundColor Yellow
}

Write-Host ""

# 2. Check Power Settings
Write-Host "[2] Checking Power Settings..." -ForegroundColor Yellow
Write-Host ""

try {
    $powerPlan = powercfg /getactivescheme
    Write-Host "  Active Power Plan:" -ForegroundColor Cyan
    Write-Host "    $powerPlan" -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "  Sleep Settings (AC Power):" -ForegroundColor Cyan
    $sleepTimeout = powercfg /query SCHEME_CURRENT SUB_SLEEP STANDBYIDLE 2>&1
    if ($sleepTimeout -match "AC.*(\d+)") {
        $minutes = [int]$matches[1] / 60
        Write-Host "    Sleep after idle: $minutes minutes" -ForegroundColor Gray
    } else {
        Write-Host "    Sleep after idle: Never (or not configured)" -ForegroundColor Gray
    }
    
    $hibernateTimeout = powercfg /query SCHEME_CURRENT SUB_SLEEP HIBERNATEIDLE 2>&1
    if ($hibernateTimeout -match "AC.*(\d+)") {
        $minutes = [int]$matches[1] / 60
        Write-Host "    Hibernate after idle: $minutes minutes" -ForegroundColor Gray
    } else {
        Write-Host "    Hibernate after idle: Never (or not configured)" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "  USB Selective Suspend:" -ForegroundColor Cyan
    $usbSuspend = powercfg /query SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 2>&1
    if ($usbSuspend -match "Enabled") {
        Write-Host "    ⚠️  USB Selective Suspend: Enabled (may prevent wake)" -ForegroundColor Yellow
    } else {
        Write-Host "    USB Selective Suspend: Disabled" -ForegroundColor Green
    }
    
} catch {
    Write-Host "  ⚠️  Error checking power settings: $_" -ForegroundColor Yellow
}

Write-Host ""

# 3. Check GPU Driver Status
Write-Host "[3] Checking GPU Driver Status..." -ForegroundColor Yellow
Write-Host ""

$nvidiaSmi = "${env:ProgramFiles}\NVIDIA Corporation\NVSMI\nvidia-smi.exe"
if (Test-Path $nvidiaSmi) {
    try {
        $gpuInfo = & $nvidiaSmi --query-gpu=driver_version,name,power.management --format=csv,noheader,nounits 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  GPU Information:" -ForegroundColor Cyan
            Write-Host "    $gpuInfo" -ForegroundColor Gray
            
            # Check for driver issues
            $driverVersion = ($gpuInfo -split ',')[0].Trim()
            Write-Host ""
            Write-Host "  Driver Version: $driverVersion" -ForegroundColor Cyan
            
            # Check for known GPU wake issues
            Write-Host ""
            Write-Host "  ⚠️  Note: NVIDIA GPUs can sometimes prevent system wake from sleep" -ForegroundColor Yellow
            Write-Host "     If this persists, try updating NVIDIA drivers or disabling" -ForegroundColor Yellow
            Write-Host "     'Fast Startup' in Windows Power Options" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  ⚠️  Error checking GPU: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ⚠️  nvidia-smi not found" -ForegroundColor Yellow
}

Write-Host ""

# 4. Check USB Devices That May Prevent Wake
Write-Host "[4] Checking USB Devices..." -ForegroundColor Yellow
Write-Host ""

try {
    $usbDevices = Get-PnpDevice | Where-Object { $_.Class -eq 'USB' -and $_.Status -eq 'OK' }
    if ($usbDevices) {
        Write-Host "  USB devices found:" -ForegroundColor Cyan
        $usbDevices | Select-Object -First 10 | ForEach-Object {
            $wakeEnabled = $_.InstanceId
            Write-Host "    $($_.FriendlyName)" -ForegroundColor Gray
        }
        Write-Host ""
        Write-Host "  ⚠️  Some USB devices can prevent system wake from sleep" -ForegroundColor Yellow
        Write-Host "     Check Device Manager > USB devices > Power Management" -ForegroundColor Yellow
        Write-Host "     Disable 'Allow this device to wake the computer' if not needed" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ⚠️  Error checking USB devices: $_" -ForegroundColor Yellow
}

Write-Host ""

# 5. Check System Uptime and Last Sleep
Write-Host "[5] Checking System Uptime..." -ForegroundColor Yellow
Write-Host ""

try {
    $uptime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    $now = Get-Date
    $uptimeDuration = $now - $uptime
    
    Write-Host "  Last Boot: $($uptime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Cyan
    Write-Host "  Uptime: $($uptimeDuration.Days) days, $($uptimeDuration.Hours) hours, $($uptimeDuration.Minutes) minutes" -ForegroundColor Cyan
    
    if ($uptimeDuration.TotalHours -lt 24) {
        Write-Host ""
        Write-Host "  ⚠️  System was recently rebooted (within 24 hours)" -ForegroundColor Yellow
        Write-Host "     This may indicate the sleep/wake failure occurred recently" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ⚠️  Error checking uptime: $_" -ForegroundColor Yellow
}

Write-Host ""

# 6. Check Docker/WSL2 Status (may affect sleep)
Write-Host "[6] Checking Docker/WSL2 Status..." -ForegroundColor Yellow
Write-Host ""

try {
    $dockerService = Get-Service -Name "com.docker.service" -ErrorAction SilentlyContinue
    if ($dockerService) {
        Write-Host "  Docker Desktop Service: $($dockerService.Status)" -ForegroundColor Cyan
        
        if ($dockerService.Status -eq 'Running') {
            Write-Host ""
            Write-Host "  ⚠️  Docker Desktop is running" -ForegroundColor Yellow
            Write-Host "     Docker/WSL2 can sometimes interfere with sleep/wake" -ForegroundColor Yellow
            
            # Check for running containers
            try {
                $containers = docker ps --format "{{.Names}}" 2>&1
                if ($containers -and $LASTEXITCODE -eq 0) {
                    $containerList = $containers -join ", "
                    Write-Host "     Running containers: $containerList" -ForegroundColor Gray
                }
            } catch {
                # Docker command may fail, ignore
            }
        }
    }
    
    # Check WSL2
    try {
        $wslStatus = wsl --status 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "  WSL2 Status:" -ForegroundColor Cyan
            Write-Host "    $($wslStatus -join "`n    ")" -ForegroundColor Gray
        }
    } catch {
        # WSL may not be available
    }
} catch {
    Write-Host "  ⚠️  Error checking Docker/WSL2: $_" -ForegroundColor Yellow
}

Write-Host ""

# Summary and Recommendations
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Recommendations:" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. Check Windows Event Viewer for detailed errors:" -ForegroundColor Yellow
Write-Host "   Event Viewer > Windows Logs > System" -ForegroundColor White
Write-Host "   Filter by Source: 'Microsoft-Windows-Kernel-Power'" -ForegroundColor White
Write-Host "   Look for Event IDs: 42, 107, 109, 131, 506-600" -ForegroundColor White
Write-Host ""

Write-Host "2. Common causes of sleep/wake failures:" -ForegroundColor Yellow
Write-Host "   - GPU driver issues (update NVIDIA drivers)" -ForegroundColor White
Write-Host "   - USB devices preventing wake (disable wake on USB devices)" -ForegroundColor White
Write-Host "   - Fast Startup enabled (disable in Power Options)" -ForegroundColor White
Write-Host "   - Docker/WSL2 running (may interfere with sleep)" -ForegroundColor White
Write-Host "   - Power supply issues (check PSU)" -ForegroundColor White
Write-Host ""

Write-Host "3. Quick fixes to try:" -ForegroundColor Yellow
Write-Host "   - Update NVIDIA drivers to latest version" -ForegroundColor White
Write-Host "   - Disable Fast Startup: Control Panel > Power Options > Choose what power buttons do" -ForegroundColor White
Write-Host "   - Check USB device wake settings in Device Manager" -ForegroundColor White
Write-Host "   - Stop Docker containers before sleep: docker stop vllm-wintermute" -ForegroundColor White
Write-Host ""

Write-Host "4. To view detailed event logs:" -ForegroundColor Yellow
Write-Host "   Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-Kernel-Power'} |" -ForegroundColor White
Write-Host "     Where-Object {`$_.TimeCreated -gt (Get-Date).AddHours(-24)} |" -ForegroundColor White
Write-Host "     Format-List TimeCreated, Id, LevelDisplayName, Message" -ForegroundColor White
Write-Host ""

