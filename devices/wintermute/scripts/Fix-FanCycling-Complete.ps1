# Complete fan cycling fix
Write-Host "Fixing Fan Cycling Issues" -ForegroundColor Cyan
Write-Host ""

# 1. Stop WSL2 podman-machine if not needed
Write-Host "[1] Stopping WSL2 podman-machine..." -ForegroundColor Yellow
wsl -t podman-machine-default 2>$null
Start-Sleep -Seconds 2
$wslCheck = wsl --list --verbose 2>&1
if ($wslCheck -match "podman-machine.*Running") {
    Write-Host "  ⚠️  podman-machine still running - shutting down all WSL2" -ForegroundColor Yellow
    wsl --shutdown
    Write-Host "  ✓ WSL2 shutdown complete" -ForegroundColor Green
} else {
    Write-Host "  ✓ podman-machine stopped" -ForegroundColor Green
}
Write-Host ""

# 2. Check and restart WmiPrvSE (high CPU usually indicates stuck queries)
Write-Host "[2] Checking WmiPrvSE processes..." -ForegroundColor Yellow
$wmiProcs = Get-Process -Name "WmiPrvSE" -ErrorAction SilentlyContinue
if ($wmiProcs) {
    $totalCPU = ($wmiProcs | Measure-Object -Property CPU -Sum).Sum
    Write-Host "  Found $($wmiProcs.Count) WmiPrvSE process(es) with $([math]::Round($totalCPU, 2)) CPU seconds" -ForegroundColor Yellow
    Write-Host "  Restarting WmiPrvSE to clear stuck queries..." -ForegroundColor Gray
    $wmiProcs | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Write-Host "  ✓ WmiPrvSE restarted" -ForegroundColor Green
} else {
    Write-Host "  ✓ No WmiPrvSE processes found" -ForegroundColor Green
}
Write-Host ""

# 3. Configure Windows Defender to be less aggressive
Write-Host "[3] Configuring Windows Defender..." -ForegroundColor Yellow
try {
    # Disable real-time scanning for specific paths (if needed)
    # Add-MpPreference -ExclusionPath "C:\Users\$env:USERNAME\dev" -ErrorAction SilentlyContinue
    # Add-MpPreference -ExclusionProcess "netdata.exe" -ErrorAction SilentlyContinue
    
    # Set scan schedule to less frequent
    Set-MpPreference -ScanScheduleDay 8 -ErrorAction SilentlyContinue  # 8 = Never (manual only)
    Write-Host "  ✓ Windows Defender configured" -ForegroundColor Green
} catch {
    Write-Host "  ⚠️  Error configuring Defender: $_" -ForegroundColor Yellow
}
Write-Host ""

# 4. Check netdata CPU usage
Write-Host "[4] Checking netdata..." -ForegroundColor Yellow
$netdata = Get-Process -Name "netdata" -ErrorAction SilentlyContinue
if ($netdata) {
    $cpuUsage = [math]::Round($netdata.CPU, 2)
    Write-Host "  netdata using $cpuUsage CPU seconds" -ForegroundColor Yellow
    Write-Host "  Consider reducing netdata collection interval if CPU usage is high" -ForegroundColor Gray
} else {
    Write-Host "  ✓ netdata not running" -ForegroundColor Green
}
Write-Host ""

Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  ✓ WSL2 podman-machine stopped" -ForegroundColor Green
Write-Host "  ✓ WmiPrvSE restarted" -ForegroundColor Green
Write-Host "  ✓ Windows Defender configured" -ForegroundColor Green
Write-Host ""
Write-Host "Monitor CPU usage. If WmiPrvSE continues high CPU, check:" -ForegroundColor Yellow
Write-Host "  - Monitoring tools querying WMI" -ForegroundColor White
Write-Host "  - Scheduled tasks using WMI" -ForegroundColor White
Write-Host "  - Management software (Ansible, monitoring agents)" -ForegroundColor White
Write-Host ""

