# Check NVIDIA devices
Write-Host "NVIDIA Devices:" -ForegroundColor Cyan
Get-PnpDevice | Where-Object {$_.FriendlyName -like "*NVIDIA*"} | Format-Table FriendlyName, Status, Class -AutoSize
Write-Host ""

# Check for NVIDIA-related errors
Write-Host "NVIDIA/GPU Related Errors (last 48 hours):" -ForegroundColor Cyan
$nvidiaErrors = Get-WinEvent -FilterHashtable @{
    LogName = 'System'
    Level = 2,3
    StartTime = (Get-Date).AddHours(-48)
} -ErrorAction SilentlyContinue | Where-Object {
    $_.ProviderName -like "*NVIDIA*" -or 
    $_.Message -like "*GPU*" -or 
    $_.Message -like "*graphics*"
} | Select-Object -First 10

if ($nvidiaErrors) {
    $nvidiaErrors | Format-Table TimeCreated, Id, LevelDisplayName, ProviderName -AutoSize
    Write-Host ""
    $nvidiaErrors | Format-List TimeCreated, Id, Message
} else {
    Write-Host "No NVIDIA-related errors found" -ForegroundColor Green
}
Write-Host ""

# Check for sleep/wake/power related errors
Write-Host "Sleep/Wake/Power Related Errors (last 48 hours):" -ForegroundColor Cyan
$powerErrors = Get-WinEvent -FilterHashtable @{
    LogName = 'System'
    Level = 2,3
    StartTime = (Get-Date).AddHours(-48)
} -ErrorAction SilentlyContinue | Where-Object {
    $_.Message -like "*sleep*" -or 
    $_.Message -like "*wake*" -or 
    $_.Message -like "*suspend*" -or
    $_.Message -like "*hibernate*"
} | Select-Object -First 10

if ($powerErrors) {
    $powerErrors | Format-Table TimeCreated, Id, LevelDisplayName, ProviderName -AutoSize
    Write-Host ""
    $powerErrors | Format-List TimeCreated, Id, Message
} else {
    Write-Host "No sleep/wake/power related errors found" -ForegroundColor Green
}

