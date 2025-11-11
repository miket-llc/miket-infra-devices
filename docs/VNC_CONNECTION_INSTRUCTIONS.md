# VNC Connection Instructions for motoko

## Connection Details
- **Host**: motoko.pangolin-vega.ts.net
- **Port**: 5900
- **Password**: motoko123
- **Protocol**: VNC (TigerVNC)
- **Session**: Shares existing GNOME desktop session

## Connect from Linux

### Using helper script (if deployed):
```bash
vnc motoko
```

### Using Remmina (recommended):
```bash
remmina -c vnc://motoko.pangolin-vega.ts.net:5900
# Password: motoko123
```

### Using TigerVNC viewer:
```bash
vncviewer motoko.pangolin-vega.ts.net:5900
# Password: motoko123
```

## Connect from Windows

### Using helper script (if deployed):
```cmd
vnc motoko
```

### Using TigerVNC viewer directly:
1. Launch TigerVNC Viewer (from Start Menu or `C:\Program Files\TigerVNC\vncviewer.exe`)
2. Enter: `motoko.pangolin-vega.ts.net:5900`
3. Password: `motoko123`

### Command line:
```cmd
"C:\Program Files\TigerVNC\vncviewer.exe" motoko.pangolin-vega.ts.net:5900
```

## Connect from macOS

### Using helper script (if deployed):
```bash
vnc motoko
```

### Using Screen Sharing (built-in):
```bash
open vnc://motoko.pangolin-vega.ts.net:5900
# Password: motoko123
```

Or:
1. Open Finder
2. Press Cmd+K (Connect to Server)
3. Enter: `vnc://motoko.pangolin-vega.ts.net:5900`
4. Password: `motoko123`

## Troubleshooting

### Connection refused:
- Check if TigerVNC service is running: `sudo systemctl status tigervnc`
- Verify port is accessible: `nc -zv motoko.pangolin-vega.ts.net 5900`

### Authentication failed:
- Verify password is correct: `motoko123`
- Check password file exists: `ls -la ~/.vnc/tigervnc-passwd` (on motoko)

### Blank screen:
- Verify GNOME session is running
- Check display: `echo $DISPLAY` (should be :0)
- Restart TigerVNC: `sudo systemctl restart tigervnc`

### Setup TigerVNC on motoko:
Run the setup script directly on motoko:
```bash
./scripts/setup-tigervnc-motoko.sh
```

