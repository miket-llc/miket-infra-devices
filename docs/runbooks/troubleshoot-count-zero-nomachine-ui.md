---
document_title: "Quick Reference: Troubleshoot NoMachine UI on count-zero"
author: "Codex-CA-001 (Chief Architect)"
last_updated: 2025-11-27
status: Active
related_initiatives:
  - initiatives/device-onboarding
---

# Quick Reference: Troubleshoot NoMachine UI on count-zero

**Issue:** NoMachine connections to count-zero from armitage/wintermute connect but UI doesn't render (blank screen).

**Quick Fix (5 minutes):**

## Step 1: Run Diagnostic Script

From wintermute (via SSH to count-zero):

```bash
ssh miket@count-zero.pangolin-vega.ts.net
cd ~/miket-infra-devices
./scripts/diagnose-nomachine-macos-ui.sh
```

Review the diagnostic report in `artifacts/nomachine-macos-ui-diagnostic-*.txt`

## Step 2: Grant Screen Recording Permission

**On count-zero (requires GUI access or user interaction):**

1. Open **System Preferences** → **Security & Privacy** → **Privacy** tab
2. Select **Screen Recording** from left sidebar
3. Click the **+** button
4. Navigate to `/usr/NX/bin/nxserver` and add it
5. Check the box to enable Screen Recording for NoMachine
6. Restart NoMachine: `sudo /usr/NX/bin/nxserver --restart`

## Step 3: Verify NoMachine Server Config

```bash
# On count-zero
sudo cat /Applications/NoMachine.app/Contents/Frameworks/etc/server.cfg | grep -i -E "(console|session|display)"

# Should show:
# EnableConsoleSessionSharing=1
# EnableSessionSharing=1
# EnableNXDisplayOutput=1
```

If missing, add these settings and restart:
```bash
sudo nano /Applications/NoMachine.app/Contents/Frameworks/etc/server.cfg
# Add the settings above
sudo /usr/NX/bin/nxserver --restart
```

## Step 4: Test Connection

From armitage or wintermute:
1. Open NoMachine client
2. Connect to `count-zero.pangolin-vega.ts.net:4000`
3. Use username: `miket`
4. Try **"New Session"** if "Console Session" doesn't work

## Common Issues

| Issue | Solution |
|-------|----------|
| Screen Recording permission not granted | Grant via System Preferences → Security & Privacy → Privacy → Screen Recording |
| Console session not enabled | Add `EnableConsoleSessionSharing=1` to server.cfg |
| No active user session | Ensure user is logged in (not just SSH) |
| WindowServer not running | Restart: `sudo killall -HUP WindowServer` (will log out user) |

## Full Documentation

For detailed troubleshooting, see:
- [NoMachine macOS UI Rendering Troubleshooting Guide](../guides/nomachine-macos-ui-rendering-troubleshooting.md)

## Next Steps if Issue Persists

1. Review diagnostic report from Step 1
2. Check NoMachine server logs: `sudo tail -100 /usr/NX/var/log/nxserver.log`
3. Verify Tailscale connectivity: `tailscale status`
4. Test from different client (wintermute vs armitage)
5. Escalate to Chief Architect if unresolved

---

**Last Updated:** 2025-11-27


