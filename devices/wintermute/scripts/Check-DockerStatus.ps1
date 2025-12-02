# Check Docker Desktop status
Write-Host "Docker Desktop Status Check" -ForegroundColor Cyan
Write-Host ""

# Check processes
Write-Host "Docker Processes:" -ForegroundColor Yellow
$dockerProcs = Get-Process | Where-Object {
    $_.ProcessName -like "*docker*" -or 
    $_.ProcessName -like "*Docker*" -or
    $_.ProcessName -like "*com.docker*"
}
if ($dockerProcs) {
    $dockerProcs | Format-Table ProcessName, Id, CPU, WorkingSet -AutoSize
} else {
    Write-Host "  No Docker processes found" -ForegroundColor Green
}
Write-Host ""

# Check services
Write-Host "Docker Services:" -ForegroundColor Yellow
$dockerSvcs = Get-Service | Where-Object {
    $_.Name -like "*docker*"
}
if ($dockerSvcs) {
    $dockerSvcs | Format-Table Name, Status, StartType -AutoSize
} else {
    Write-Host "  No Docker services found" -ForegroundColor Green
}
Write-Host ""

# Check WSL2 docker-desktop
Write-Host "WSL2 docker-desktop distro:" -ForegroundColor Yellow
$wslList = wsl --list --verbose 2>&1
if ($wslList -match "docker-desktop") {
    Write-Host "  docker-desktop distro found:" -ForegroundColor Yellow
    $wslList | Select-String "docker-desktop" | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
} else {
    Write-Host "  No docker-desktop distro found" -ForegroundColor Green
}

