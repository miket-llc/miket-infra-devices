#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
#
# deploy-autofs-interactive.sh
# Deploy autofs configuration with interactive sudo prompt
# Run this ON count-zero

set -euo pipefail

# Get sudo password using AppleScript
get_sudo_password() {
    osascript <<EOF
tell application "System Events"
    activate
    display dialog "Autofs deployment requires administrator privileges. Please enter your password:" default answer "" with hidden answer with title "Sudo Password"
    set thePassword to text returned of result
    return thePassword
end tell
EOF
}

# Configuration
SMB_SERVER="motoko"
SMB_USERNAME="mdt"
SMB_ENV_FILE="${HOME}/.mkt/mounts.env"
AUTOFS_MOUNT_BASE="/mnt/motoko"
AUTOFS_TIMEOUT=300

# Read SMB password
if [ ! -f "$SMB_ENV_FILE" ]; then
    echo "Error: Secrets file missing: $SMB_ENV_FILE"
    exit 1
fi

set -o allexport
source "$SMB_ENV_FILE"
set +o allexport

SMB_PASSWORD_ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$SMB_PASSWORD', safe=''))")

# Get sudo password
SUDO_PASSWORD=$(get_sudo_password)

# Create deployment script
DEPLOY_SCRIPT=$(cat <<SCRIPT
#!/bin/bash
set -euo pipefail

AUTOFS_MOUNT_BASE="$AUTOFS_MOUNT_BASE"
AUTOFS_TIMEOUT=$AUTOFS_TIMEOUT
AUTOFS_MASTER="/etc/auto_master"
AUTOFS_MAP="/etc/auto.motoko"
SMB_SERVER="$SMB_SERVER"
SMB_USERNAME="$SMB_USERNAME"
SMB_PASSWORD_ENCODED="$SMB_PASSWORD_ENCODED"
USER_HOME="$HOME"

# Create mount base
mkdir -p "\$AUTOFS_MOUNT_BASE"
chmod 755 "\$AUTOFS_MOUNT_BASE"

# Add to auto_master if not present
if ! grep -q "^\${AUTOFS_MOUNT_BASE} " "\$AUTOFS_MASTER"; then
    echo "\${AUTOFS_MOUNT_BASE} \${AUTOFS_MAP} --timeout=\${AUTOFS_TIMEOUT}" >> "\$AUTOFS_MASTER"
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

# Create user symlinks
for share in flux space time; do
    LINK_PATH="\${USER_HOME}/\${share}"
    TARGET_PATH="\${AUTOFS_MOUNT_BASE}/\${share}"
    rm -f "\$LINK_PATH"
    ln -s "\$TARGET_PATH" "\$LINK_PATH"
done

# Reload autofs
automount -vc

echo "Autofs configured successfully"
SCRIPT
)

# Execute with sudo
echo "$SUDO_PASSWORD" | sudo -S bash <<< "$DEPLOY_SCRIPT"

echo ""
echo "Deployment complete! Testing configuration..."
./scripts/test-autofs-count-zero.sh

