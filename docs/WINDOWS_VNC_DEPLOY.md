# Quick deployment instructions for Windows VNC script fix

## Option 1: Run PowerShell Script (Recommended)

Copy `scripts/update-vnc-windows.ps1` to each Windows machine and run:

```powershell
# Run PowerShell as Administrator
.\update-vnc-windows.ps1
```

## Option 2: Manual Copy

Copy the fixed `scripts/vnc.bat` to `C:\Windows\System32\vnc.bat` on each Windows machine:

```powershell
# Run PowerShell as Administrator
Copy-Item -Path "C:\path\to\miket-infra-devices\scripts\vnc.bat" -Destination "C:\Windows\System32\vnc.bat" -Force
```

## Option 3: Direct Command (Quick Fix)

Run this in PowerShell as Administrator on each Windows machine:

```powershell
@'
@echo off
setlocal enabledelayedexpansion
set HOST=%~1
set PORT=%~2
if "!HOST!"=="" set HOST=motoko
if "!PORT!"=="" set PORT=5900
ping -n 1 !HOST!.pangolin-vega.ts.net >nul 2>&1
if !errorlevel!==0 (
    set TARGET=!HOST!.pangolin-vega.ts.net:!PORT!
) else (
    set TARGET=!HOST!:!PORT!
)
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
start "" "!VNCVIEWER!" "!TARGET!"
'@ | Out-File -FilePath "C:\Windows\System32\vnc.bat" -Encoding ASCII -Force
```

## Test After Deployment

```cmd
vnc motoko
# Password: motoko123
```

## Machines to Update

- wintermute
- armitage

