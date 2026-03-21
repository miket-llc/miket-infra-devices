---
document_title: "Fix NoMachine on akira After Hard Freeze / Unclean Shutdown"
author: "Claude Code (Opus 4.6)"
last_updated: 2026-03-21
status: Active
---

# Fix NoMachine on akira After Hard Freeze / Unclean Shutdown

**Applies to:** akira (Fedora 43 KDE, Wayland, AMD Radeon 890M iGPU)

**Symptom:** After a hard freeze or unclean shutdown, NoMachine connections from
armitage (or any client) fail with:
- "Session Negotiation Failed"
- "Connection reset by peer" (Error 104)
- "Cannot detect any display running"
- Black screen after connecting

**Root Cause:** NoMachine's embedded Redis database (`/usr/NX/var/db/server.db`)
is corrupted by the unclean shutdown. The error `ERR Background save already in
progress` appears in `/usr/NX/var/log/server.log` on every connection attempt.
This corruption survives simple restarts because the embedded Redis process
re-reads the corrupt RDB on startup.

Additionally, KDE on akira runs on **Wayland** (not X11). NoMachine uses EGL
screen capture for Wayland, which requires `libnxegl.so` to be LD_PRELOAD'd
into `kwin_wayland`. After a reinstall, this preload is missing from the
running kwin process.

## Quick Fix (Try First)

If the symptom is "session negotiation failed" or error 104, try clearing the
Redis state:

```bash
# 1. Stop NX completely via systemd (prevents auto-restart)
sudo systemctl stop nxserver

# 2. Kill ALL NX processes (the daemon may survive systemctl stop)
sudo pkill -9 -f "nxserver|nxnode|nxd|nxrunner"
sleep 2

# 3. Verify everything is dead
ps aux | grep "[n]x"
# Should return nothing. If processes remain, kill -9 them by PID.

# 4. Delete the corrupted Redis DB
sudo rm -f /usr/NX/var/db/server.db

# 5. Clear temp state
sudo rm -rf /tmp/.NX-*

# 6. Start fresh
sudo systemctl start nxserver

# 7. Re-authorize X display access (required after crash)
xhost +local:
xhost +SI:localuser:nx

# 8. Verify display detection
sleep 5
sudo /usr/NX/bin/nxserver --list
# Should show display 0 with a session ID
```

If `--list` shows a session and the client connects with video, you're done.

## Full Fix (If Quick Fix Doesn't Work)

If the Redis error persists after deleting `server.db`, the installation is
corrupted and must be reinstalled.

```bash
# 1. Stop and uninstall
sudo systemctl stop nxserver
sudo rpm -e nomachine

# 2. Clear the stale LD_PRELOAD (NX injects libnxegl.so into the session)
# This will show "cannot be preloaded" errors on every command until reinstall.
# It's harmless but annoying. It goes away after reinstall.

# 3. Reinstall from the Ansible-managed RPM
# The RPM is stored locally on the device (see nomachine_server role defaults)
sudo rpm -ivh --nodigest --nosignature /home/mdt/Downloads/nomachine_*.rpm
# Or use Ansible:
# ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/nomachine_deploy.yml --limit akira

# 4. Re-authorize X display access
xhost +local:
xhost +SI:localuser:nx

# 5. Verify display detection
sleep 5
sudo /usr/NX/bin/nxserver --status
sudo /usr/NX/bin/nxserver --list
```

### Post-Reinstall: Wayland EGL Capture

After reinstalling, you will likely get a **black screen** when connecting.
This happens because `kwin_wayland` was started before the reinstall and
doesn't have `libnxegl.so` preloaded.

**Fix: Switch to DRM capture mode (no logout required):**

```bash
sudo sed -i 's/^#WaylandModes egl,drm,compositor/WaylandModes drm,compositor,egl/' /usr/NX/etc/node.cfg
sudo /usr/NX/bin/nxserver --restart
```

DRM capture reads directly from the GPU framebuffer — no LD_PRELOAD needed.

**Alternative: Log out and back in to KDE.** This restarts kwin with the
`libnxegl.so` preload, enabling EGL capture. This is more reliable long-term
but requires ending the current desktop session.

## Wayland-Specific Configuration (akira)

akira runs KDE Plasma on Wayland. Key NoMachine config for Wayland:

### /usr/NX/etc/node.cfg

```
# EGL capture must be enabled for Wayland physical desktop shadowing
EnableEGLCapture 1

# Capture method priority — drm first (no preload needed), then egl
WaylandModes drm,compositor,egl

# KDE Plasma Wayland desktop command
DefaultDesktopCommand "/usr/libexec/plasma-dbus-run-session-if-needed /usr/bin/startplasma-wayland"
```

### X Display Access

NoMachine's `nx` user needs X11 access (via XWayland on :0) for session
discovery. After any reboot or crash, run:

```bash
xhost +local:
xhost +SI:localuser:nx
```

To make this persistent, add to `~/.config/autostart/` or the KDE startup
scripts. Currently this is a manual step after each reboot.

## Diagnostic Commands

```bash
# Check NoMachine status
sudo /usr/NX/bin/nxserver --status

# List detected displays (should show display 0)
sudo /usr/NX/bin/nxserver --list

# Connection history (look for Failed/Finished)
sudo /usr/NX/bin/nxserver --history

# Server log (look for Redis errors, framebuffer failures)
sudo tail -50 /usr/NX/var/log/server.log

# Check if nxnode is enabled (MUST be enabled for display detection)
# If disabled, the --list will always be empty
sudo /usr/NX/bin/nxserver --status | grep nxnode

# Check Wayland session
loginctl show-session $(loginctl list-sessions --no-legend | grep seat0 | awk '{print $1}') -p Type
# Should show: Type=wayland

# Check if kwin has libnxegl.so preloaded
cat /proc/$(pgrep -f "kwin_wayland --wayland")/environ | tr '\0' '\n' | grep LD_PRELOAD
# Should contain /usr/NX/lib/libnxegl.so (only after a fresh login post-install)

# Check X display access for nx user
sudo -u nx DISPLAY=:0 xdpyinfo 2>&1 | head -3
# Should show display info, not "Authorization required"
```

## Key Error Signatures

| Error in server.log | Meaning | Fix |
|---|---|---|
| `ERR Background save already in progress` | Corrupted Redis DB | Delete `server.db`, restart |
| `NXFrameBuffer failed to start` | Can't capture screen | Check WaylandModes, xhost, EGL preload |
| `Node address list cannot be empty` | nxnode not running | Reinstall if restart doesn't fix |
| `Cannot specify is local node base on ':'` | Corrupted node config | Reinstall NoMachine |
| `nxnode: Disabled` in --status | Display detection disabled | Reinstall (config corruption) |

## Version Notes

- **9.2.18** — Ansible-managed version, known working on akira with Wayland/KDE
- **9.3.7** — Was installed on akira, corrupted after freeze. Downgraded back to 9.2.18.
  If upgrading again, test Wayland capture before committing.

## Related

- `docs/runbooks/fix-count-zero-nomachine-session-negotiation.md`
- `docs/runbooks/fix-motoko-nomachine-kde-lockscreen.md`
- `docs/guides/nomachine-keystroke-dropping-troubleshooting.md`
- `ansible/roles/nomachine_server/` — Ansible role for deployment
- `ansible/host_vars/akira.yml` — akira-specific config (remote_protocol: nomachine)
