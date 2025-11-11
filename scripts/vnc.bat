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

