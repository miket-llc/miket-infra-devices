#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.

# Detect USB drive and partitions for 20TB drive setup
# Run this script on akira to identify partitions before running Ansible playbook

set -e

echo "🔍 Detecting USB drive and partitions..."
echo ""

# Get all block devices
echo "📦 Block Devices:"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE,LABEL,UUID

echo ""
echo "🔎 Looking for partitions..."

# Find Time Machine partition (APFS)
TIMEMACHINE=$(lsblk -o NAME,LABEL,FSTYPE -n | grep -i "time\|machine" | head -1 | awk '{print $1}' || echo "")
if [ -n "$TIMEMACHINE" ]; then
    echo "✅ Time Machine partition detected: /dev/$TIMEMACHINE"
    blkid "/dev/$TIMEMACHINE" | grep -o 'UUID="[^"]*"' || echo "   UUID: (check with blkid)"
else
    echo "⚠️  Time Machine partition not found by label"
fi

# Find space partition
SPACE=$(lsblk -o NAME,LABEL,FSTYPE -n | grep -i "space" | head -1 | awk '{print $1}' || echo "")
if [ -n "$SPACE" ]; then
    echo "✅ Space partition detected: /dev/$SPACE"
    blkid "/dev/$SPACE" | grep -o 'UUID="[^"]*"' || echo "   UUID: (check with blkid)"
    CURRENT_FS=$(blkid -o value -s TYPE "/dev/$SPACE" 2>/dev/null || echo "unknown")
    echo "   Current filesystem: $CURRENT_FS"
    if [ "$CURRENT_FS" != "ext4" ]; then
        echo "   ⚠️  Will be reformatted to ext4"
    fi
else
    echo "⚠️  Space partition not found by label"
fi

echo ""
echo "💡 To configure, run:"
echo "   cd ~/miket-infra-devices/ansible"
echo "   ansible-playbook -i inventory/hosts.yml playbooks/akira/configure-usb-storage.yml --limit akira --connection=local"



