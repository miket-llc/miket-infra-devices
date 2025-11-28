# Copyright (c) 2025 MikeT LLC. All rights reserved.

---
document_title: "Fix NoMachine KDE Lock Screen / Display Manager Conflicts"
author: "Chief Architect"
last_updated: 2025-11-28
status: Active
related_initiatives:
  - initiatives/device-onboarding
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md
---

# Fix NoMachine KDE Lock Screen / Display Manager Conflicts

**Purpose:** Troubleshoot and fix NoMachine connection issues when KDE displays a lock screen or the desktop is unresponsive.

**Target Device:** motoko (Linux, Pop!_OS/Ubuntu with KDE Plasma)

---

## Symptoms

- NoMachine connects but shows only lock screen
- Lock screen is unresponsive to input
- NoMachine creates virtual displays instead of connecting to physical desktop
- Multiple display managers (SDDM + GDM) running simultaneously

---

## Root Cause Analysis

The most common causes:

1. **Dual Display Manager Conflict**: Both SDDM (KDE) and GDM3 (GNOME) are running
2. **Virtual vs Physical Desktop**: NoMachine connects to virtual display instead of physical
3. **Screen Lock Active**: KDE screen locker is active and blocking input
4. **Session Confusion**: Multiple X displays causing session routing issues

---

## Diagnostic Commands

```bash
# Check which display managers are running
systemctl status sddm gdm3 --no-pager

# List active sessions
loginctl list-sessions

# Check X displays
ls -la /tmp/.X11-unix/

# Check KDE processes
ps aux | grep -E "(plasma|kwin|startplasma)" | grep -v grep

# Check NoMachine sessions
sudo /usr/NX/bin/nxserver --list

# Check for screen locker
ps aux | grep kscreenlocker | grep -v grep
```

---

## Fix Procedure

### Step 1: Kill Screen Locker (if active)

```bash
# Unlock all sessions
sudo loginctl unlock-sessions

# Force kill screen locker if still running
pkill -9 -f kscreenlocker_greet
```

### Step 2: Disable Conflicting Display Manager (GDM3)

```bash
# Stop GDM3
sudo systemctl stop gdm3

# Disable and mask GDM3 permanently
sudo systemctl disable gdm3
sudo systemctl mask gdm3

# Verify only SDDM is active
systemctl is-active sddm
systemctl is-enabled gdm3  # Should show "masked"
```

### Step 3: Configure SDDM for KDE Autologin

```bash
# Create SDDM autologin config
sudo mkdir -p /etc/sddm.conf.d
cat << 'EOF' | sudo tee /etc/sddm.conf.d/autologin.conf
[Autologin]
User=mdt
Session=plasma
Relogin=false

[General]
HaltCommand=/usr/bin/systemctl poweroff
RebootCommand=/usr/bin/systemctl reboot

[Theme]
Current=breeze
EOF
```

### Step 4: Configure NoMachine for Physical Desktop

Add to `/usr/NX/etc/server.cfg`:

```bash
cat << 'EOF' | sudo tee -a /usr/NX/etc/server.cfg

# PHC: Force physical desktop connection
PhysicalDesktopMode 2
CreateDisplay 0
EOF
```

### Step 5: Restart Services

```bash
# Kill any stale sessions on conflicting ttys
sudo pkill -9 -t tty3 2>/dev/null || true

# Restart SDDM
sudo systemctl restart sddm

# Wait for KDE to start
sleep 5

# Restart NoMachine
sudo /usr/NX/bin/nxserver --restart

# Verify single session on display :0
sudo /usr/NX/bin/nxserver --list
```

---

## Verification

After fixes, verify:

```bash
# Single display manager (SDDM)
systemctl is-active sddm  # Should be "active"
systemctl is-enabled gdm3  # Should be "masked"

# KDE running
ps aux | grep plasmashell | grep -v grep  # Should show process

# Single NoMachine session on display :0
sudo /usr/NX/bin/nxserver --list
# Expected: Display 0, Username mdt

# Port 4000 listening on Tailscale IP
ss -tulnp | grep 4000
# Expected: tcp LISTEN on 100.92.23.71:4000
```

---

## Prevention

### Ansible Role Updates

The `remote_server_linux_nomachine` role should:

1. Check for and disable GDM3 if present
2. Configure SDDM autologin
3. Set `PhysicalDesktopMode 2` and `CreateDisplay 0` in NoMachine config

### System Configuration

1. Only one display manager should be installed/enabled
2. Pop!_OS defaults to GDM3 - must be disabled for KDE
3. NoMachine should be configured to prefer physical desktop

---

## Related Documentation

- [NoMachine Client Testing](nomachine-client-testing.md)
- [NoMachine Installer Sources](nomachine-installer-sources.md)
- [Tailscale Device Setup](TAILSCALE_DEVICE_SETUP.md)

---

## Troubleshooting History

| Date | Issue | Resolution |
|------|-------|------------|
| 2025-11-28 | Lock screen unresponsive, SDDM+GDM3 conflict | Masked GDM3, configured SDDM autologin, set PhysicalDesktopMode 2 |
| 2025-11-28 | Frozen buffer, "another process interrupted desktop effects" | Restarted kwin_x11 --replace and NoMachine |

---

## Quick Fix: Frozen Display / Compositor Crash

If you see a frozen buffer with mouse moving, or "another process interrupted desktop effects":

```bash
# Restart KWin compositor
DISPLAY=:0 kwin_x11 --replace &

# Restart NoMachine
sudo /usr/NX/bin/nxserver --restart

# Reconnect via NoMachine
```

---

**End of Runbook**

