#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.

# Setup TigerVNC on motoko to share GNOME session
# UPDATED: Includes headless laptop (lid closed) configuration
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

# Create systemd service for TigerVNC
echo "Creating TigerVNC service..."
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
Environment="DISPLAY=:0"
Environment="XAUTHORITY=$XAUTH"
ExecStartPre=/bin/sh -c 'DISPLAY=:0 XAUTHORITY=$XAUTH xset q &>/dev/null || sleep 2'
ExecStart=/usr/bin/x0vncserver -display :0 -rfbport 5900 -PasswordFile /home/mdt/.vnc/tigervnc-passwd -SecurityTypes VncAuth -AlwaysShared -localhost no -fg
Restart=on-failure
RestartSec=10
TimeoutStartSec=30

[Install]
WantedBy=default.target
EOF

# Configure GDM autologin
echo "Configuring GDM autologin..."
sudo tee /etc/pop-os/gdm3/custom.conf > /dev/null <<EOF
# GDM configuration storage

[daemon]
# Force Xorg (required for VNC)
WaylandEnable=false

# Autologin for headless operation
AutomaticLoginEnable=true
AutomaticLogin=mdt

[security]

[xdmcp]

[chooser]

[debug]
EOF

# Configure lid switch to ignore
echo "Configuring lid switch behavior..."
sudo sed -i 's/#HandleLidSwitch=suspend/HandleLidSwitch=ignore/' /etc/systemd/logind.conf
sudo sed -i 's/#HandleLidSwitchExternalPower=suspend/HandleLidSwitchExternalPower=ignore/' /etc/systemd/logind.conf
sudo sed -i 's/#HandleLidSwitchDocked=ignore/HandleLidSwitchDocked=ignore/' /etc/systemd/logind.conf

# Add kernel parameter to treat lid as open
echo "Adding kernel parameter for lid-closed operation..."
sudo kernelstub -a 'button.lid_init_state=open' || echo "Note: kernelstub failed, may already be set"

# Create GDM override to restart on failure
echo "Creating GDM service override..."
sudo mkdir -p /etc/systemd/system/gdm.service.d
sudo tee /etc/systemd/system/gdm.service.d/override.conf > /dev/null <<EOF
[Unit]
# Force GDM to start even with lid closed
ConditionPathExists=
ConditionPathExists=/usr/sbin/gdm3

[Service]
# Restart if it fails
Restart=always
RestartSec=5
EOF

# Create force-start service for GDM
echo "Creating force-start service for GDM..."
sudo tee /etc/systemd/system/force-gdm-start.service > /dev/null <<EOF
[Unit]
Description=Force GDM to start
After=multi-user.target
Wants=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/systemctl start gdm3
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Create autostart script for display configuration
echo "Creating display configuration autostart..."
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/disable-laptop-display.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Disable Laptop Display
Exec=sh -c "sleep 5 && DISPLAY=:0 xrandr --output eDP-1 --off --output HDMI-1-0 --auto --primary && DISPLAY=:0 xset s off && DISPLAY=:0 xset -dpms && DISPLAY=:0 xset s noblank"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF
chmod +x ~/.config/autostart/disable-laptop-display.desktop

# Disable power management via gsettings (run now, will persist)
echo "Disabling power management..."
export DISPLAY=:0
gsettings set org.gnome.desktop.screensaver idle-activation-enabled false || true
gsettings set org.gnome.desktop.screensaver lock-enabled false || true
gsettings set org.gnome.settings-daemon.plugins.power idle-dim false || true
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing' || true

# Enable and start services
echo ""
echo "Enabling services..."
sudo systemctl daemon-reload
sudo systemctl enable force-gdm-start.service
sudo systemctl enable tigervnc.service
sudo systemctl restart systemd-logind

echo ""
echo "==========================================="
echo "✅ TigerVNC setup complete!"
echo "==========================================="
echo ""
echo "Configuration applied:"
echo "  - TigerVNC x0vncserver on port 5900"
echo "  - GDM autologin for user mdt"
echo "  - Lid switch disabled (no suspend on close)"
echo "  - Laptop display will be disabled on login"
echo "  - HDMI-1-0 will be primary display"
echo "  - Power management disabled"
echo ""
echo "Connection details:"
echo "  Host: motoko.pangolin-vega.ts.net"
echo "  Port: 5900"
echo "  Password: motoko123"
echo ""
echo "⚠️  REBOOT REQUIRED for all changes to take effect"
echo "    Run: sudo reboot"
echo ""
