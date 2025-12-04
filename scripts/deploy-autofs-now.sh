#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
# Run this script in your terminal - it will prompt for sudo password

set -euo pipefail

echo "Deploying autofs configuration..."

# Read password
set -o allexport
source ~/.mkt/mounts.env
set +o allexport

SMB_PASSWORD_ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$SMB_PASSWORD', safe=''))")

# Clean up old mounts
umount ~/.mkt/flux ~/.mkt/space ~/.mkt/time 2>/dev/null || true
launchctl unload ~/Library/LaunchAgents/com.miket.storage-connect.plist 2>/dev/null || true
rm -f ~/flux ~/space ~/time

# Configure autofs (requires sudo)
sudo bash <<EOF
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
./scripts/test-autofs-count-zero.sh

echo ""
echo "Testing mounts..."
ls ~/space ~/flux ~/time

echo ""
echo "Checking mount status..."
mount | grep autofs || echo "No autofs mounts yet (will mount on access)"
mount | grep smbfs || echo "No SMB mounts yet"

echo ""
echo "Done! Try accessing ~/space, ~/flux, or ~/time to trigger mounts."

