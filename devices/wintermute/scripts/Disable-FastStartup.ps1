# Disable Fast Startup
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
$regName = "HiberbootEnabled"

try {
    $currentValue = Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue
    if ($currentValue -and $currentValue.$regName -eq 1) {
        Set-ItemProperty -Path $regPath -Name $regName -Value 0
        Write-Host "Fast Startup disabled"
    } else {
        Write-Host "Fast Startup already disabled"
    }
} catch {
    # Create the property if it doesn't exist
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }
    Set-ItemProperty -Path $regPath -Name $regName -Value 0
    Write-Host "Fast Startup disabled"
}

