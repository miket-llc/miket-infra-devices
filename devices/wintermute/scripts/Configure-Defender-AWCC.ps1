# Configure Windows Defender and Alienware Command Center
Write-Host "Configuring Windows Defender and AWCC" -ForegroundColor Cyan
Write-Host ""

# Windows Defender - reduce scanning
Write-Host "[1] Configuring Windows Defender..." -ForegroundColor Yellow
try {
    # Disable scheduled scans (set to manual only)
    Set-MpPreference -ScanScheduleDay 8 -ErrorAction SilentlyContinue  # 8 = Never
    
    # Reduce real-time scanning impact
    Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
    Set-MpPreference -DisableBehaviorMonitoring $false -ErrorAction SilentlyContinue
    
    # Add exclusions for dev directories
    $devPath = "C:\Users\$env:USERNAME\dev"
    if (Test-Path $devPath) {
        Add-MpPreference -ExclusionPath $devPath -ErrorAction SilentlyContinue
        Write-Host "  Added exclusion for dev directory" -ForegroundColor Green
    }
    
    Write-Host "  Windows Defender configured" -ForegroundColor Green
} catch {
    Write-Host "  Error configuring Defender: $_" -ForegroundColor Yellow
}
Write-Host ""

# Alienware Command Center - stop if not needed
Write-Host "[2] Checking Alienware Command Center..." -ForegroundColor Yellow
$awcc = Get-Process -Name "AWCC*" -ErrorAction SilentlyContinue
if ($awcc) {
    Write-Host "  Found AWCC processes:" -ForegroundColor Yellow
    $awcc | ForEach-Object {
        Write-Host "    $($_.ProcessName) (PID: $($_.Id))" -ForegroundColor Gray
    }
    Write-Host "  AWCC can cause CPU spikes. Stop if not needed:" -ForegroundColor Yellow
    Write-Host "    Get-Process AWCC* | Stop-Process -Force" -ForegroundColor White
} else {
    Write-Host "  No AWCC processes found" -ForegroundColor Green
}
Write-Host ""

Write-Host "Done. Monitor fan activity." -ForegroundColor Cyan
Write-Host ""


