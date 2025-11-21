#!/bin/bash
# GNOME Shell Emergency Recovery Script
# Run this script if GNOME Shell is frozen or unresponsive
# Location: devices/motoko/scripts/gnome-shell-recovery.sh

set -euo pipefail

echo "=== GNOME Shell Emergency Recovery ==="
echo "This script will attempt to recover a frozen GNOME Shell"
echo ""

# Step 1: Remove the disable-extensions file if it exists
DISABLE_FILE="/run/user/$(id -u)/gnome-shell-disable-extensions"
if [ -f "$DISABLE_FILE" ]; then
    echo "[1/5] Removing disable-extensions file..."
    rm -f "$DISABLE_FILE"
    echo "      ✓ Removed $DISABLE_FILE"
else
    echo "[1/5] No disable-extensions file found (good)"
fi

# Step 2: Check current gnome-shell status
echo "[2/5] Checking gnome-shell status..."
if pgrep -u "$USER" gnome-shell > /dev/null; then
    GNOME_PID=$(pgrep -u "$USER" gnome-shell | head -1)
    GNOME_CPU=$(ps -p "$GNOME_PID" -o %cpu= | tr -d ' ')
    echo "      gnome-shell running (PID: $GNOME_PID, CPU: ${GNOME_CPU}%)"
else
    echo "      ✗ gnome-shell is NOT running"
fi

# Step 3: Kill gnome-shell gracefully first, then forcefully
echo "[3/5] Restarting gnome-shell..."
if pkill -TERM gnome-shell; then
    echo "      Sent SIGTERM to gnome-shell"
    sleep 2
fi

if pgrep -u "$USER" gnome-shell > /dev/null; then
    echo "      Still running, sending SIGKILL..."
    pkill -KILL gnome-shell
    sleep 1
fi

# Step 4: Wait for gnome-shell to restart
echo "[4/5] Waiting for gnome-shell to restart..."
for i in {1..10}; do
    if pgrep -u "$USER" gnome-shell > /dev/null; then
        NEW_PID=$(pgrep -u "$USER" gnome-shell | head -1)
        echo "      ✓ gnome-shell restarted (PID: $NEW_PID)"
        break
    fi
    echo "      Waiting... ($i/10)"
    sleep 1
done

# Step 5: Verify recovery
echo "[5/5] Verifying recovery..."
if pgrep -u "$USER" gnome-shell > /dev/null; then
    FINAL_PID=$(pgrep -u "$USER" gnome-shell | head -1)
    FINAL_CPU=$(ps -p "$FINAL_PID" -o %cpu= | tr -d ' ')
    echo "      ✓ RECOVERY SUCCESSFUL"
    echo "      gnome-shell running (PID: $FINAL_PID, CPU: ${FINAL_CPU}%)"
    echo ""
    echo "=== Recovery Complete ==="
    echo "Your GNOME Shell should now be responsive."
else
    echo "      ✗ RECOVERY FAILED"
    echo "      gnome-shell did not restart automatically"
    echo ""
    echo "=== Manual Recovery Required ==="
    echo "Please restart GDM with: sudo systemctl restart gdm"
fi


