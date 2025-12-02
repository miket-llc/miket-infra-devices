# Check power settings in detail
Write-Host "Power Plan Details:" -ForegroundColor Cyan
$activePlan = powercfg /getactivescheme
Write-Host $activePlan
Write-Host ""

Write-Host "Sleep Timeout (AC):" -ForegroundColor Cyan
powercfg /query SCHEME_CURRENT SUB_SLEEP STANDBYIDLE 2>&1
Write-Host ""

Write-Host "Hibernate Timeout (AC):" -ForegroundColor Cyan
powercfg /query SCHEME_CURRENT SUB_SLEEP HIBERNATEIDLE 2>&1
Write-Host ""

Write-Host "Fast Startup Status:" -ForegroundColor Cyan
$fastStartup = powercfg /query SCHEME_CURRENT SUB_BUTTONS SBUTTONACTION
Write-Host $fastStartup
Write-Host ""

Write-Host "USB Selective Suspend:" -ForegroundColor Cyan
powercfg /query SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 2>&1
Write-Host ""

Write-Host "USB Devices with Wake Enabled:" -ForegroundColor Cyan
$usbDevices = Get-PnpDevice | Where-Object { $_.Class -eq 'USB' -and $_.Status -eq 'OK' }
$wakeDevices = @()
foreach ($device in $usbDevices) {
    try {
        $wakeEnabled = (Get-CimInstance -Namespace "root\cimv2" -ClassName Win32_PnPEntity | Where-Object { $_.DeviceID -eq $device.InstanceId }).PowerManagementCapabilities
        if ($wakeEnabled -and $wakeEnabled -contains 4) {  # 4 = Can wake system
            $wakeDevices += $device.FriendlyName
        }
    } catch {
        # Skip if can't check
    }
}
if ($wakeDevices.Count -gt 0) {
    $wakeDevices | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
} else {
    Write-Host "  (Unable to determine - check Device Manager manually)" -ForegroundColor Gray
}

