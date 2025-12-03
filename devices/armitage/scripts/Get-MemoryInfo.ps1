# Simple memory diagnostic for Armitage
$outputFile = "C:\Users\mdt\dev\armitage\scripts\memory-info.txt"

# System Memory
$os = Get-CimInstance Win32_OperatingSystem
$totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
$freeGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
$usedGB = $totalGB - $freeGB
$pct = [math]::Round(($usedGB / $totalGB) * 100, 1)

"=== Armitage Memory Diagnostic ===" | Out-File -FilePath $outputFile
"Generated: $(Get-Date)" | Out-File -FilePath $outputFile -Append
"" | Out-File -FilePath $outputFile -Append
"System Memory:" | Out-File -FilePath $outputFile -Append
"  Total: $totalGB GB" | Out-File -FilePath $outputFile -Append
"  Used: $usedGB GB ($pct percent)" | Out-File -FilePath $outputFile -Append
"  Free: $freeGB GB" | Out-File -FilePath $outputFile -Append
"" | Out-File -FilePath $outputFile -Append

# Top processes
"Top 15 Processes by Memory:" | Out-File -FilePath $outputFile -Append
Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 15 | ForEach-Object {
    $memGB = [math]::Round($_.WorkingSet / 1GB, 2)
    "  $($_.ProcessName): $memGB GB (PID: $($_.Id))" | Out-File -FilePath $outputFile -Append
}
"" | Out-File -FilePath $outputFile -Append

# WSL2 status
"WSL2 Status:" | Out-File -FilePath $outputFile -Append
wsl --list --verbose 2>&1 | Out-File -FilePath $outputFile -Append
"" | Out-File -FilePath $outputFile -Append

# .wslconfig check
$wslConfig = "$env:USERPROFILE\.wslconfig"
if (Test-Path $wslConfig) {
    ".wslconfig found:" | Out-File -FilePath $outputFile -Append
    Get-Content $wslConfig | Out-File -FilePath $outputFile -Append
} else {
    ".wslconfig NOT found" | Out-File -FilePath $outputFile -Append
}
"" | Out-File -FilePath $outputFile -Append

# Docker processes
"Docker/Podman Processes:" | Out-File -FilePath $outputFile -Append
$dockerProcs = Get-Process | Where-Object { $_.ProcessName -like "*docker*" -or $_.ProcessName -like "*podman*" } -ErrorAction SilentlyContinue
if ($dockerProcs) {
    $dockerProcs | Group-Object ProcessName | ForEach-Object {
        $memGB = [math]::Round(($_.Group | Measure-Object -Property WorkingSet -Sum).Sum / 1GB, 2)
        "  $($_.Name): $($_.Count) process(es), $memGB GB total" | Out-File -FilePath $outputFile -Append
    }
} else {
    "  No Docker/Podman processes found" | Out-File -FilePath $outputFile -Append
}

Write-Host "Memory diagnostic written to: $outputFile"

