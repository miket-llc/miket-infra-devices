#!/bin/bash
# Setup TigerVNC on motoko to share GNOME session
# Run this directly on motoko

set -e

echo "=========================================="
echo "Setting up TigerVNC on motoko"
echo "=========================================="
echo ""

# Install TigerVNC
echo "Installing TigerVNC..."
sudo apt-get update
sudo apt-get install -y tigervnc-standalone-server

# Get display (should be :0 for GNOME)
DISPLAY=$(ps aux | grep -E '[X]org' | head -1 | awk '{for(i=1;i<=NF;i++) if($i ~ /:[0-9]+/) print $i}' | head -1)
DISPLAY=${DISPLAY:-:0}
DISPLAY_NUM=$(echo $DISPLAY | sed 's/://')

echo "Detected display: $DISPLAY"

# Create .vnc directory
mkdir -p ~/.vnc
chmod 755 ~/.vnc

# Create password file (motoko123)
echo "Setting VNC password to: motoko123"
echo -e "motoko123\nmotoko123\nn" | vncpasswd ~/.vnc/tigervnc-passwd
chmod 600 ~/.vnc/tigervnc-passwd

# Get XAUTHORITY
XAUTH=$(ls /run/user/$(id -u)/gdm/Xauthority 2>/dev/null || echo "/run/user/1000/gdm/Xauthority")
echo "Using XAUTHORITY: $XAUTH"

# Create systemd service
sudo tee /etc/systemd/system/tigervnc.service > /dev/null <<EOF
[Unit]
Description=TigerVNC x0vncserver (Display Sharing - GNOME Session)
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=simple
User=mdt
Group=mdt
WorkingDirectory=/home/mdt
Environment="HOME=/home/mdt"
Environment="DISPLAY=$DISPLAY"
Environment="XAUTHORITY=$XAUTH"
ExecStartPre=/bin/sh -c 'DISPLAY=$DISPLAY XAUTHORITY=$XAUTH xset q &>/dev/null || sleep 2'
ExecStart=/usr/bin/x0vncserver -display $DISPLAY -rfbport 5900 -PasswordFile /home/mdt/.vnc/tigervnc-passwd -SecurityTypes VncAuth -AlwaysShared -localhost no -fg
Restart=on-failure
RestartSec=10
TimeoutStartSec=30

[Install]
WantedBy=default.target
EOF

# Enable and start service
echo ""
echo "Enabling and starting TigerVNC service..."
sudo systemctl daemon-reload
sudo systemctl enable tigervnc.service
sudo systemctl restart tigervnc.service

# Wait a moment
sleep 2

# Check status
echo ""
echo "Checking service status..."
sudo systemctl status tigervnc.service --no-pager -l || true

echo ""
echo "=========================================="
echo "✅ TigerVNC setup complete!"
echo "=========================================="
echo ""
echo "Connection details:"
echo "  Host: motoko.pangolin-vega.ts.net"
echo "  Port: 5900"
echo "  Password: motoko123"
echo ""
echo "Connect from Linux:"
echo "  vnc motoko"
echo "  or: vncviewer motoko.pangolin-vega.ts.net:5900"
echo ""
echo "Connect from Windows:"
echo "  vnc motoko"
echo "  or: Launch TigerVNC viewer and connect to motoko.pangolin-vega.ts.net:5900"
echo ""
echo "Connect from macOS:"
echo "  vnc motoko"
echo "  or: open vnc://motoko.pangolin-vega.ts.net:5900"
echo ""

