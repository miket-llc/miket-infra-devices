# Stop high CPU processes causing fan cycling
Write-Host "Stopping High CPU Processes" -ForegroundColor Cyan
Write-Host ""

# Stop WSL2 completely
Write-Host "[1] Shutting down WSL2..." -ForegroundColor Yellow
wsl --shutdown 2>$null
Write-Host "  WSL2 shutdown complete" -ForegroundColor Green
Write-Host ""

# Stop netdata temporarily to test
Write-Host "[2] Stopping netdata..." -ForegroundColor Yellow
$netdata = Get-Service -Name "netdata" -ErrorAction SilentlyContinue
if ($netdata -and $netdata.Status -eq "Running") {
    Stop-Service -Name "netdata" -ErrorAction SilentlyContinue
    Write-Host "  netdata stopped (can restart later if needed)" -ForegroundColor Green
} else {
    Write-Host "  netdata not running" -ForegroundColor Green
}
Write-Host ""

# Restart WmiPrvSE to clear stuck queries
Write-Host "[3] Restarting WmiPrvSE..." -ForegroundColor Yellow
Get-Process -Name "WmiPrvSE" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Write-Host "  WmiPrvSE restarted" -ForegroundColor Green
Write-Host ""

# Check current CPU usage
Write-Host "[4] Current top CPU processes:" -ForegroundColor Yellow
Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 ProcessName, CPU, WorkingSet | Format-Table -AutoSize
Write-Host ""

Write-Host "Done. Monitor fan activity." -ForegroundColor Cyan
Write-Host "If fan cycling stops, netdata was likely the cause." -ForegroundColor Yellow
Write-Host ""


