# Quick check for fan cycling causes
Write-Host "Fan Cycling Diagnostic" -ForegroundColor Cyan
Write-Host ""

# CPU Usage
Write-Host "Top CPU Processes:" -ForegroundColor Yellow
Get-Process | Sort-Object CPU -Descending | Select-Object -First 5 | 
    Format-Table ProcessName, @{Name="CPU(s)";Expression={[math]::Round($_.CPU, 2)}}, @{Name="Memory(MB)";Expression={[math]::Round($_.WorkingSet/1MB, 2)}} -AutoSize
Write-Host ""

# GPU Usage
Write-Host "GPU Status:" -ForegroundColor Yellow
$nvidiaSmi = "${env:ProgramFiles}\NVIDIA Corporation\NVSMI\nvidia-smi.exe"
if (Test-Path $nvidiaSmi) {
    & $nvidiaSmi --query-gpu=utilization.gpu,utilization.memory,temperature.gpu,power.draw --format=csv,noheader,nounits
    Write-Host ""
    Write-Host "GPU Processes:" -ForegroundColor Yellow
    & $nvidiaSmi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader
} else {
    Write-Host "  nvidia-smi not found" -ForegroundColor Yellow
}
Write-Host ""

# WSL2 Status
Write-Host "WSL2 Distros:" -ForegroundColor Yellow
wsl --list --verbose
Write-Host ""

# Podman Status
Write-Host "Podman Containers:" -ForegroundColor Yellow
podman ps -a
Write-Host ""

# Windows Services that might cause load
Write-Host "Background Services Status:" -ForegroundColor Yellow
$services = @("WSearch", "wuauserv", "SysMain")
foreach ($svc in $services) {
    $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($s) {
        Write-Host "  $svc : $($s.Status)" -ForegroundColor $(if ($s.Status -eq "Running") { "Yellow" } else { "Green" })
    }
}





