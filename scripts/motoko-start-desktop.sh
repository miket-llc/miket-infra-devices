#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
# Quick script to start desktop on motoko

set -e

echo "=== Starting Desktop on Motoko ==="
echo ""

# 1. Start GDM
echo "[1/5] Starting GDM..."
sudo systemctl start gdm3
sudo systemctl enable gdm3

# 2. Ensure autologin is configured
echo "[2/5] Configuring autologin..."
sudo mkdir -p /etc/pop-os/gdm3
sudo tee /etc/pop-os/gdm3/custom.conf > /dev/null <<EOF
[daemon]
WaylandEnable=false
AutomaticLoginEnable=true
AutomaticLogin=mdt
EOF

# 3. Ensure force-gdm-start service exists and is enabled
echo "[3/5] Ensuring force-gdm-start service..."
sudo mkdir -p /etc/systemd/system/gdm.service.d
sudo tee /etc/systemd/system/gdm.service.d/override.conf > /dev/null <<EOF
[Unit]
ConditionPathExists=
ConditionPathExists=/usr/sbin/gdm3

[Service]
Restart=always
RestartSec=5
EOF

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

sudo systemctl daemon-reload
sudo systemctl enable force-gdm-start.service

# 4. Restart GDM
echo "[4/5] Restarting GDM..."
sudo systemctl restart gdm3

# 5. Wait and verify
echo "[5/5] Waiting for desktop to start..."
sleep 15

echo ""
echo "=== Verification ==="
sudo systemctl status gdm3 --no-pager | grep "Active:" || true
ps aux | grep gnome-session | grep -v grep || echo "Desktop session not detected yet"

echo ""
echo "✅ Desktop should be starting. If not visible, check:"
echo "   - sudo systemctl status gdm3"
echo "   - sudo journalctl -u gdm3 -n 50"

