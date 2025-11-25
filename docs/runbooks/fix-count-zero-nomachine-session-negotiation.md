---
document_title: "Fix NoMachine Session Negotiation Failed on count-zero"
author: "Codex-CA-001 (Chief Architect)"
last_updated: 2025-11-27
status: Active
---

# Fix NoMachine "Session Negotiation Failed" on count-zero

**Issue:** After attempting to configure NoMachine, connections show "Session Negotiation failed" error.

**Root Cause:** Configuration changes weren't applied (requires sudo), or directory permissions issue.

## Quick Fix

**On count-zero, run these commands:**

```bash
# 1. Check and fix directory permissions (if needed)
sudo chown -R nx:root /usr/NX/var/db/limits 2>/dev/null || \
sudo chown -R nx:wheel '/Library/Application Support/NoMachine/var/nx' 2>/dev/null || \
echo "Directory permissions check complete"

# 2. Add session configuration to the MAIN config file
sudo bash -c 'cat >> /Applications/NoMachine.app/Contents/Frameworks/etc/server.cfg << EOF

# Enable console session sharing for macOS
EnableNewSession 1
EnableConsoleSessionSharing 1
EnableSessionSharing 1
EnableNXDisplayOutput 1
EOF'

# 3. Restart NoMachine server
sudo /etc/NX/nxserver --restart

# 4. Wait a few seconds and verify
sleep 3
ps aux | grep nxserver | grep daemon
netstat -an | grep 4000 | grep LISTEN
```

## Alternative: Try "New Session" Instead

If console session still doesn't work:

1. On wintermute/armitage NoMachine client
2. When connecting to count-zero, select **"New Session"** instead of "Console Session"
3. This creates a new desktop session instead of sharing the existing one

## Verify Configuration

```bash
# Check that settings were added
grep -i 'EnableConsoleSessionSharing\|EnableSessionSharing\|EnableNXDisplayOutput' \
  /Applications/NoMachine.app/Contents/Frameworks/etc/server.cfg

# Should show:
# EnableNewSession 1
# EnableConsoleSessionSharing 1
# EnableSessionSharing 1
# EnableNXDisplayOutput 1
```

## If Still Failing

1. Check logs: `tail -50 '/Library/Application Support/NoMachine/var/log/server.log'`
2. Verify server is running: `ps aux | grep nxserver | grep daemon`
3. Test port: `netstat -an | grep 4000 | grep LISTEN`
4. Try connecting with "New Session" type instead

