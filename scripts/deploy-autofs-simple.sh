#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
#
# deploy-autofs-simple.sh
# Simple autofs deployment script
# Run this ON count-zero - will prompt for sudo password

set -euo pipefail

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Autofs Deployment for count-zero${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# Check secrets file
SMB_ENV_FILE="${HOME}/.mkt/mounts.env"
if [ ! -f "$SMB_ENV_FILE" ]; then
    echo "Error: Secrets file missing: $SMB_ENV_FILE"
    exit 1
fi

# Read and encode password
set -o allexport
source "$SMB_ENV_FILE"
set +o allexport

SMB_PASSWORD_ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$SMB_PASSWORD', safe=''))")

# Clean up old mounts (no sudo needed)
echo "Cleaning up old mounts..."
umount ~/.mkt/flux ~/.mkt/space ~/.mkt/time 2>/dev/null || true
launchctl unload ~/Library/LaunchAgents/com.miket.storage-connect.plist 2>/dev/null || true
rm -f ~/flux ~/space ~/time
echo -e "${GREEN}✓ Old mounts cleaned up${NC}"
echo ""

# Now run sudo commands
echo "Configuring autofs (requires sudo)..."
echo ""

sudo bash <<SUDO_SCRIPT
set -euo pipefail

AUTOFS_MOUNT_BASE="/mnt/motoko"
AUTOFS_TIMEOUT=300
AUTOFS_MASTER="/etc/auto_master"
AUTOFS_MAP="/etc/auto.motoko"
SMB_SERVER="motoko"
SMB_USERNAME="mdt"
SMB_PASSWORD_ENCODED="$SMB_PASSWORD_ENCODED"
USER_HOME="$HOME"

# Create mount base
mkdir -p "\$AUTOFS_MOUNT_BASE"
chmod 755 "\$AUTOFS_MOUNT_BASE"
echo "Created mount base: \$AUTOFS_MOUNT_BASE"

# Add to auto_master if not present
if ! grep -q "^\${AUTOFS_MOUNT_BASE} " "\$AUTOFS_MASTER"; then
    echo "\${AUTOFS_MOUNT_BASE} \${AUTOFS_MAP} --timeout=\${AUTOFS_TIMEOUT}" >> "\$AUTOFS_MASTER"
    echo "Added entry to \$AUTOFS_MASTER"
else
    echo "Entry already exists in \$AUTOFS_MASTER"
fi

# Create autofs map
cat > "\$AUTOFS_MAP" <<EOF
# Autofs map for motoko SMB shares
# Auto-generated - do not edit manually
flux -fstype=smbfs,soft,noowners,nosuid,rw ://\${SMB_USERNAME}:\${SMB_PASSWORD_ENCODED}@\${SMB_SERVER}/flux
space -fstype=smbfs,soft,noowners,nosuid,rw ://\${SMB_USERNAME}:\${SMB_PASSWORD_ENCODED}@\${SMB_SERVER}/space
time -fstype=smbfs,soft,noowners,nosuid,rw ://\${SMB_USERNAME}:\${SMB_PASSWORD_ENCODED}@\${SMB_SERVER}/time
EOF

chmod 644 "\$AUTOFS_MAP"
echo "Created autofs map: \$AUTOFS_MAP"

# Create user symlinks
for share in flux space time; do
    LINK_PATH="\${USER_HOME}/\${share}"
    TARGET_PATH="\${AUTOFS_MOUNT_BASE}/\${share}"
    rm -f "\$LINK_PATH"
    ln -s "\$TARGET_PATH" "\$LINK_PATH"
    echo "Created symlink: \$LINK_PATH -> \$TARGET_PATH"
done

# Reload autofs
automount -vc
echo "Reloaded autofs configuration"
SUDO_SCRIPT

echo ""
echo -e "${GREEN}✓ Autofs deployment complete!${NC}"
echo ""
echo "Testing configuration..."
./scripts/test-autofs-count-zero.sh

