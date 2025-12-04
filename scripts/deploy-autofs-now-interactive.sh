#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
# Run this script - it will prompt for sudo password via GUI

set -euo pipefail

echo "Deploying autofs configuration..."

# Read password from env file
set -o allexport
source ~/.mkt/mounts.env
set +o allexport

SMB_PASSWORD_ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$SMB_PASSWORD', safe=''))")

# Clean up old mounts
umount ~/.mkt/flux ~/.mkt/space ~/.mkt/time 2>/dev/null || true
launchctl unload ~/Library/LaunchAgents/com.miket.storage-connect.plist 2>/dev/null || true
rm -f ~/flux ~/space ~/time

# Get sudo password via osascript
SUDO_PASSWORD=$(osascript <<EOF 2>/dev/null
tell application "System Events"
    activate
    display dialog "Autofs deployment requires administrator privileges. Please enter your password:" default answer "" with hidden answer with title "Sudo Password" buttons {"Cancel", "OK"} default button "OK"
    return text returned of result
end tell
EOF
)

if [ -z "$SUDO_PASSWORD" ]; then
    echo "Password prompt cancelled"
    exit 1
fi

# Configure autofs using sudo with password
echo "$SUDO_PASSWORD" | sudo -S bash <<EOF
set -euo pipefail

# Create mount base (use /Volumes - macOS SIP makes /mnt read-only)
mkdir -p /Volumes/motoko
chmod 755 /Volumes/motoko

# Add to auto_master
if ! grep -q "^/Volumes/motoko " /etc/auto_master; then
    echo "/Volumes/motoko /etc/auto.motoko --timeout=300" >> /etc/auto_master
fi

# Create autofs map
cat > /etc/auto.motoko <<AUTOMAP
# Autofs map for motoko SMB shares
flux -fstype=smbfs,soft,noowners,nosuid,rw ://mdt:${SMB_PASSWORD_ENCODED}@motoko/flux
space -fstype=smbfs,soft,noowners,nosuid,rw ://mdt:${SMB_PASSWORD_ENCODED}@motoko/space
time -fstype=smbfs,soft,noowners,nosuid,rw ://mdt:${SMB_PASSWORD_ENCODED}@motoko/time
AUTOMAP

chmod 600 /etc/auto.motoko  # Restrictive permissions - contains URL-encoded password

# Create symlinks
for share in flux space time; do
    rm -f /Users/miket/\$share
    ln -s /Volumes/motoko/\$share /Users/miket/\$share
done

# Reload autofs
automount -vc

echo "Autofs configured successfully"
EOF

echo ""
echo "Testing configuration..."
sleep 2

echo ""
echo "Testing mounts..."
ls ~/space ~/flux ~/time

echo ""
echo "Checking mount status..."
mount | grep autofs || echo "No autofs mounts yet (will mount on access)"
mount | grep smbfs || echo "No SMB mounts yet"

echo ""
echo "Done! Try accessing ~/space, ~/flux, or ~/time to trigger mounts."

