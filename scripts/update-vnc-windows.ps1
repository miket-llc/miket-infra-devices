# PowerShell script to update VNC helper script on Windows
# Run this on each Windows machine (wintermute, armitage) as Administrator

$vncScript = @'
@echo off
REM VNC connection helper script
REM Usage: vnc HOSTNAME [PORT]

setlocal enabledelayedexpansion
set HOST=%~1
set PORT=%~2
if "!HOST!"=="" set HOST=motoko
if "!PORT!"=="" set PORT=5900

REM Use Tailscale MagicDNS
ping -n 1 !HOST!.pangolin-vega.ts.net >nul 2>&1
if !errorlevel!==0 (
    set TARGET=!HOST!.pangolin-vega.ts.net:!PORT!
) else (
    set TARGET=!HOST!:!PORT!
)

REM Find TigerVNC viewer
set VNCVIEWER=
if exist "C:\Program Files\TigerVNC\vncviewer.exe" (
    set "VNCVIEWER=C:\Program Files\TigerVNC\vncviewer.exe"
) else if exist "C:\Program Files (x86)\TigerVNC\vncviewer.exe" (
    set "VNCVIEWER=C:\Program Files (x86)\TigerVNC\vncviewer.exe"
) else if exist "C:\ProgramData\chocolatey\lib\tigervnc\tools\vncviewer.exe" (
    set "VNCVIEWER=C:\ProgramData\chocolatey\lib\tigervnc\tools\vncviewer.exe"
)

if "!VNCVIEWER!"=="" (
    echo Error: TigerVNC viewer not found. Install via: choco install tigervnc
    exit /b 1
)

REM Launch TigerVNC viewer
REM Password for motoko: motoko123 (will be prompted)
start "" "!VNCVIEWER!" "!TARGET!"
'@

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "ERROR: This script must be run as Administrator" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

# Write the script to System32
$targetPath = "C:\Windows\System32\vnc.bat"
try {
    $vncScript | Out-File -FilePath $targetPath -Encoding ASCII -Force
    Write-Host "✅ Successfully updated vnc.bat at $targetPath" -ForegroundColor Green
    Write-Host ""
    Write-Host "Test it with: vnc motoko" -ForegroundColor Cyan
    Write-Host "Password: motoko123" -ForegroundColor Cyan
} catch {
    Write-Host "ERROR: Failed to write to $targetPath" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

