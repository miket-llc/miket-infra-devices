# Get recent sleep/wake events
$events = Get-WinEvent -FilterHashtable @{
    LogName = 'System'
    ProviderName = 'Microsoft-Windows-Kernel-Power'
    StartTime = (Get-Date).AddHours(-48)
} -ErrorAction SilentlyContinue | Select-Object -First 20

Write-Host "Recent Power Events (last 48 hours):" -ForegroundColor Cyan
Write-Host ""
$events | Format-Table TimeCreated, Id, LevelDisplayName -AutoSize

Write-Host ""
Write-Host "Error/Warning Events:" -ForegroundColor Yellow
$errorEvents = $events | Where-Object { $_.LevelDisplayName -in @('Error', 'Warning') } | Select-Object -First 5
if ($errorEvents) {
    $errorEvents | Format-List TimeCreated, Id, LevelDisplayName, Message
} else {
    Write-Host "No error/warning events found" -ForegroundColor Green
}

