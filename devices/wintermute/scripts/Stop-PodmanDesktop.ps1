# Stop Podman Desktop
Write-Host "Stopping Podman Desktop" -ForegroundColor Cyan
Write-Host ""

Get-Process | Where-Object {$_.ProcessName -like "Podman*"} | ForEach-Object {
    Write-Host "Stopping $($_.ProcessName) (PID: $($_.Id))" -ForegroundColor Yellow
    Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
}

Get-Service | Where-Object {$_.Name -like "*podman*"} | ForEach-Object {
    Write-Host "Stopping service $($_.Name)" -ForegroundColor Yellow
    Stop-Service -Name $_.Name -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Podman Desktop stopped" -ForegroundColor Green
Write-Host ""

# Show current top processes
Write-Host "Current top CPU processes:" -ForegroundColor Cyan
Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 ProcessName, CPU, WorkingSet | Format-Table -AutoSize





