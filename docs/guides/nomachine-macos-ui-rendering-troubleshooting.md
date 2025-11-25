---
document_title: "NoMachine macOS UI Rendering Troubleshooting Guide"
author: "Codex-CA-001 (Chief Architect) & Codex-MAC-012 (macOS Engineer)"
last_updated: 2025-11-27
status: Published
related_initiatives:
  - initiatives/device-onboarding
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md#2025-11-27-nomachine-count-zero-ui-issue
---

# NoMachine macOS UI Rendering Troubleshooting Guide

**Issue:** NoMachine connections to count-zero (macOS) from Windows hosts (armitage, wintermute) establish successfully but the UI never renders (blank/black screen).

**Severity:** P1 - High Impact (prevents remote access to macOS workstation)

**Affected Systems:**
- **Server:** count-zero (macOS)
- **Clients:** armitage (Windows), wintermute (Windows)
- **Protocol:** NoMachine NX over Tailscale
- **Port:** 4000

---

## Executive Summary

This guide provides a systematic approach to diagnosing and resolving UI rendering issues when connecting to macOS via NoMachine. The issue typically manifests as a successful connection authentication followed by a blank or black screen with no desktop rendering.

**Common Root Causes:**
1. macOS Screen Sharing permissions not granted to NoMachine
2. NoMachine server not configured to share console session
3. Display server configuration issues
4. macOS security/privacy settings blocking screen capture
5. Session type mismatch (new session vs. console session)

---

## Diagnostic Procedure

### Phase 1: Verify NoMachine Server Status

**1.1 Check NoMachine Server Service**

```bash
# On count-zero (macOS)
sudo /usr/NX/bin/nxserver --status

# Expected output should show:
# - Server is running
# - Active sessions (if any)
# - Listening on port 4000
```

**1.2 Verify NoMachine Server Process**

```bash
# On count-zero
ps aux | grep -i nomachine | grep -v grep

# Should show nxserver and related processes running
```

**1.3 Check NoMachine Server Logs**

```bash
# On count-zero
sudo tail -50 /usr/NX/var/log/nxserver.log

# Look for:
# - Connection attempts
# - Authentication successes/failures
# - Display/session errors
# - Permission denied errors
```

**1.4 Verify Port Listening**

```bash
# On count-zero
sudo lsof -i :4000 | grep LISTEN

# Should show nxserver listening on port 4000
# Check if bound to Tailscale IP (100.x.x.x) or all interfaces
```

---

### Phase 2: macOS Screen Sharing Permissions

**2.1 Check Screen Recording Permission**

NoMachine requires Screen Recording permission on macOS to capture the display.

```bash
# On count-zero
# Check via System Preferences or:
sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db "SELECT service, client, allowed FROM access WHERE service='kTCCServiceScreenRecording';"

# Look for NoMachine entries
# Expected: nxserver or NoMachine should have allowed=1
```

**2.2 Grant Screen Recording Permission (Manual)**

1. Open **System Preferences** → **Security & Privacy** → **Privacy** tab
2. Select **Screen Recording** from the left sidebar
3. Ensure **NoMachine** or **nxserver** is checked
4. If not present, click the **+** button and add `/usr/NX/bin/nxserver`
5. Restart NoMachine server: `sudo /usr/NX/bin/nxserver --restart`

**2.3 Grant Screen Recording Permission (Command Line)**

```bash
# On count-zero
# This requires user interaction, but can be scripted:
sudo tccutil reset ScreenRecording com.nomachine.nxserver

# Then manually grant via System Preferences
# Or use AppleScript automation (see below)
```

**2.4 Verify Accessibility Permissions**

```bash
# Check Accessibility permissions
sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db "SELECT service, client, allowed FROM access WHERE service='kTCCServiceAccessibility';"

# NoMachine may need this for keyboard/mouse input
```

---

### Phase 3: NoMachine Server Configuration

**3.1 Check Server Configuration File**

```bash
# On count-zero
sudo cat /Applications/NoMachine.app/Contents/Frameworks/etc/server.cfg | grep -i -E "(display|session|console|desktop)"

# Key settings to verify:
# - EnableNXDisplayOutput (should be 1)
# - EnableSessionSharing (should be 1 for macOS)
# - SessionType (should support console sessions)
```

**3.2 Verify Console Session Support**

```bash
# On count-zero
sudo cat /Applications/NoMachine.app/Contents/Frameworks/etc/server.cfg | grep -i console

# macOS NoMachine should support console session sharing
# If not configured, add:
# EnableConsoleSessionSharing=1
```

**3.3 Check Session Type Configuration**

```bash
# On count-zero
sudo cat /Applications/NoMachine.app/Contents/Frameworks/etc/server.cfg | grep -i sessiontype

# For macOS, should allow:
# - Console session (shares existing desktop)
# - New session (creates new desktop session)
```

**3.4 Verify Display Server Binding**

```bash
# On count-zero
# Check if NoMachine is bound to the correct display
echo $DISPLAY
# Should show :0 or similar

# Check active displays
system_profiler SPDisplaysDataType | grep -i "resolution\|display"
```

---

### Phase 4: Network & Connectivity Verification

**4.1 Test Port Connectivity from Client**

```powershell
# From armitage or wintermute (Windows PowerShell)
Test-NetConnection -ComputerName count-zero.pangolin-vega.ts.net -Port 4000

# Expected: TcpTestSucceeded = True
```

**4.2 Verify Tailscale Connectivity**

```bash
# From count-zero
tailscale status | grep -E "(armitage|wintermute)"

# Should show direct connection (not via DERP relay)
```

**4.3 Test Authentication**

```bash
# From armitage or wintermute, attempt connection
# If authentication fails, check:
# - Username (should be miket for count-zero)
# - Password
# - NoMachine user permissions
```

---

### Phase 5: macOS-Specific Display Issues

**5.1 Check for Active User Session**

```bash
# On count-zero
who

# Should show active user session
# NoMachine console session requires an active login session
```

**5.2 Verify Screen Lock Status**

```bash
# On count-zero
# If screen is locked, NoMachine may not render
# Check lock status (requires user interaction or automation)
```

**5.3 Check Display Sleep Settings**

```bash
# On count-zero
pmset -g | grep displaysleep

# If display sleeps, it may cause rendering issues
# Consider disabling display sleep for troubleshooting:
# sudo pmset -a displaysleep 0
```

**5.4 Verify Multiple Display Configuration**

```bash
# On count-zero
system_profiler SPDisplaysDataType

# If multiple displays, NoMachine may need specific display selection
# Check NoMachine config for display selection settings
```

---

## Common Root Causes & Solutions

### Issue 1: Screen Recording Permission Not Granted

**Symptoms:** Connection succeeds, authentication works, but screen is blank/black

**Diagnosis:**
```bash
# Check TCC database
sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db "SELECT * FROM access WHERE service='kTCCServiceScreenRecording' AND client LIKE '%nomachine%';"
```

**Solution:**
1. Open System Preferences → Security & Privacy → Privacy → Screen Recording
2. Add NoMachine (`/usr/NX/bin/nxserver`) if not present
3. Check the box to grant permission
4. Restart NoMachine: `sudo /usr/NX/bin/nxserver --restart`
5. Reconnect from client

### Issue 2: Console Session Not Enabled

**Symptoms:** Connection succeeds but shows "No display available" or blank screen

**Diagnosis:**
```bash
# Check server config
sudo grep -i "EnableConsoleSessionSharing\|EnableSessionSharing" /Applications/NoMachine.app/Contents/Frameworks/etc/server.cfg
```

**Solution:**
```bash
# Edit server config
sudo nano /Applications/NoMachine.app/Contents/Frameworks/etc/server.cfg

# Add or modify:
EnableConsoleSessionSharing=1
EnableSessionSharing=1
EnableNXDisplayOutput=1

# Restart server
sudo /usr/NX/bin/nxserver --restart
```

### Issue 3: No Active User Session

**Symptoms:** Connection succeeds but no desktop appears

**Diagnosis:**
```bash
# Check for active sessions
who
# Should show logged-in user
```

**Solution:**
1. Ensure user is logged in to macOS (not just SSH access)
2. If using headless mode, ensure console session is available
3. Consider using "New Session" instead of "Console Session" in NoMachine client

### Issue 4: Display Server Not Running

**Symptoms:** Connection succeeds but screen is black

**Diagnosis:**
```bash
# Check display server
ps aux | grep -i "WindowServer\|QuartzComposer"

# Should show WindowServer process running
```

**Solution:**
1. Ensure macOS is not in headless mode
2. Verify display is connected and active
3. Restart WindowServer (will log out user): `sudo killall -HUP WindowServer`

### Issue 5: NoMachine Version Mismatch

**Symptoms:** Connection succeeds but rendering fails

**Diagnosis:**
```bash
# On count-zero (server)
/usr/NX/bin/nxserver --version

# On client (armitage/wintermute)
# Check NoMachine client version
# Should match or be compatible
```

**Solution:**
1. Ensure server and client versions are compatible (v9.2.18-3 recommended)
2. Update both to latest version if mismatch exists
3. Test with matching versions

### Issue 6: macOS Security Settings

**Symptoms:** Connection succeeds but screen capture fails

**Diagnosis:**
```bash
# Check all relevant TCC permissions
sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db "SELECT service, client, allowed FROM access WHERE client LIKE '%nomachine%';"
```

**Solution:**
1. Grant all required permissions:
   - Screen Recording
   - Accessibility (for input)
   - Full Disk Access (if needed for file transfer)
2. Restart NoMachine server after granting permissions
3. Reconnect from client

---

## Systematic Testing Procedure

### Test 1: Basic Connection Test

1. From armitage/wintermute, connect to count-zero via NoMachine
2. Enter credentials (username: miket)
3. Observe connection process:
   - Does authentication succeed? ✅/❌
   - Does session start? ✅/❌
   - Does screen render? ✅/❌

### Test 2: Session Type Test

1. In NoMachine client, try different session types:
   - **Console Session** (shares existing desktop)
   - **New Session** (creates new desktop)
2. Document which session type works (if any)

### Test 3: Permission Verification Test

1. On count-zero, verify all permissions:
   ```bash
   # Screen Recording
   sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db "SELECT * FROM access WHERE service='kTCCServiceScreenRecording';"
   
   # Accessibility
   sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db "SELECT * FROM access WHERE service='kTCCServiceAccessibility';"
   ```
2. Grant any missing permissions
3. Retest connection

### Test 4: Server Configuration Test

1. On count-zero, verify server config:
   ```bash
   sudo cat /Applications/NoMachine.app/Contents/Frameworks/etc/server.cfg | grep -i -E "(console|session|display)"
   ```
2. Update configuration if needed
3. Restart server: `sudo /usr/NX/bin/nxserver --restart`
4. Retest connection

---

## Resolution Workflow

### Step 1: Quick Fixes (5 minutes)

1. ✅ Grant Screen Recording permission via System Preferences
2. ✅ Restart NoMachine server: `sudo /usr/NX/bin/nxserver --restart`
3. ✅ Try "New Session" instead of "Console Session" in client
4. ✅ Ensure user is logged in to macOS (not just SSH)

### Step 2: Configuration Check (10 minutes)

1. ✅ Verify NoMachine server config (console session enabled)
2. ✅ Check server logs for errors
3. ✅ Verify port 4000 is listening and accessible
4. ✅ Check Tailscale connectivity

### Step 3: Permission Verification (15 minutes)

1. ✅ Verify all macOS permissions (Screen Recording, Accessibility)
2. ✅ Check TCC database for NoMachine entries
3. ✅ Grant missing permissions
4. ✅ Restart NoMachine server

### Step 4: Advanced Troubleshooting (30+ minutes)

1. ✅ Check display server status
2. ✅ Verify active user session
3. ✅ Test with different session types
4. ✅ Check for version mismatches
5. ✅ Review NoMachine server logs in detail

---

## Diagnostic Script

Run the diagnostic script on count-zero:

```bash
# From wintermute (via SSH to count-zero)
ssh miket@count-zero.pangolin-vega.ts.net
cd ~/miket-infra-devices
./scripts/diagnose-nomachine-macos-ui.sh
```

This script will:
1. Check NoMachine server status
2. Verify permissions
3. Check server configuration
4. Test connectivity
5. Generate diagnostic report

---

## Monitoring & Validation

### Success Criteria

**UI Renders Successfully:**
- Connection establishes within 10 seconds
- Desktop appears within 5 seconds after authentication
- Mouse/keyboard input works
- Screen updates in real-time

**Ongoing Monitoring:**
- Monitor NoMachine server logs for errors
- Track connection success rate
- Document any recurring issues

---

## Escalation Path

**If issue persists after all troubleshooting steps:**

1. **Collect Diagnostics:**
   ```bash
   # On count-zero
   sudo /usr/NX/bin/nxserver --status > /tmp/nomachine-status.txt
   sudo tail -100 /usr/NX/var/log/nxserver.log > /tmp/nomachine-logs.txt
   sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db "SELECT * FROM access WHERE client LIKE '%nomachine%';" > /tmp/tcc-permissions.txt
   ```

2. **Document Findings:**
   - Connection success/failure rate
   - Error messages from logs
   - Permission status
   - Configuration changes attempted

3. **Escalate to:**
   - miket-infra-devices Chief Architect (Codex-CA-001)
   - NoMachine support (if macOS-specific bug suspected)

---

## Related Documentation

- [NoMachine Client Testing Procedure](../runbooks/nomachine-client-testing.md)
- [NoMachine Client Installation](../runbooks/nomachine-client-installation.md)
- [Tailscale Device Setup](../runbooks/TAILSCALE_DEVICE_SETUP.md)
- [Device Onboarding Initiative](../initiatives/device-onboarding/)

---

## Change Log

**2025-11-27:** Initial troubleshooting guide created
- macOS-specific UI rendering issues documented
- Screen Recording permission requirements identified
- Console session configuration procedures established
- Diagnostic script created

---

**End of Troubleshooting Guide**


