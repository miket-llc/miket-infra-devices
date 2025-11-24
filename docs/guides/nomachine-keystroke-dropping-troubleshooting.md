---
document_title: "NoMachine Keystroke Dropping Troubleshooting Guide"
author: "Codex-CA-001 (Chief Architect) & Codex-SRE-005 (SRE & Observability Engineer)"
last_updated: 2025-11-24
status: Published
related_initiatives:
  - initiatives/device-onboarding
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md#2025-11-24-nomachine-keystroke-investigation
---

# NoMachine Keystroke Dropping Troubleshooting Guide

**Issue:** Keystrokes dropping when using NoMachine from count-zero (macOS) to motoko (Linux)

**Severity:** P1 - High Impact (affects user productivity)

**Affected Systems:**
- **Client:** count-zero (macOS)
- **Server:** motoko (Linux, Pop!_OS)
- **Protocol:** NoMachine NX over Tailscale
- **Connection:** Direct Tailscale connection (192.168.1.185:62169)

---

## Executive Summary

This guide provides a systematic approach to diagnosing and resolving keystroke dropping issues in NoMachine sessions. The investigation follows a multi-layered approach covering network, client configuration, server configuration, and application-level issues.

**Current Baseline (2025-11-24):**
- Network connectivity: ✅ Excellent (0% packet loss, ~4ms latency)
- Tailscale connection: ✅ Direct (not via DERP relay)
- NoMachine service: ✅ Running (active since 2025-11-23 17:40:35 EST)
- Server version: v9.2.18-3

---

## Diagnostic Procedure

### Phase 1: Network & Connectivity Verification

**1.1 Verify Network Quality**

```bash
# From motoko, test connectivity to count-zero
ping -c 20 count-zero.pangolin-vega.ts.net

# Expected: <1% packet loss, <10ms latency
# Current: 0% packet loss, ~4ms average latency ✅
```

**1.2 Check Tailscale Connection Quality**

```bash
# From motoko
tailscale status | grep count-zero

# Verify direct connection (not via DERP relay)
# Current: direct 192.168.1.185:62169 ✅
```

**1.3 Test NoMachine Port Connectivity**

```bash
# From count-zero (macOS)
nc -zv motoko.pangolin-vega.ts.net 4000

# Expected: Connection succeeded
```

**1.4 Monitor Network During Active Session**

```bash
# On motoko, monitor network traffic during typing
sudo tcpdump -i tailscale0 -n 'port 4000' -c 100

# Look for:
# - Packet retransmissions
# - Out-of-order packets
# - High latency spikes
```

---

### Phase 2: Client-Side (count-zero) Diagnostics

**2.1 Check NoMachine Client Version**

```bash
# On count-zero
/Applications/NoMachine.app/Contents/Frameworks/bin/nxplayer --version

# Expected: v9.2.18 or compatible with server
```

**2.2 Verify Connection Profile Settings**

```bash
# Check connection profile on count-zero
cat ~/Documents/NoMachine/motoko.nxs

# Verify these settings:
# - Link quality: 9 (highest)
# - "Grab the keyboard input": true
# - "Grab the mouse input": true
```

**2.3 Check macOS Keyboard Settings**

```bash
# On count-zero, check for keyboard accessibility settings
defaults read -g AppleKeyboardUIMode

# Check for input method conflicts
defaults read com.apple.HIToolbox AppleEnabledInputSources
```

**2.4 Test for Stuck Modifier Keys**

**During active NoMachine session:**
1. Press and release all modifier keys: `Ctrl`, `Alt`, `Shift`, `Cmd`
2. Try typing in a text editor
3. Check if keystrokes resume

**2.5 Toggle Keyboard Grabbing**

**During active NoMachine session:**
1. Press `Ctrl+Alt+0` to open NoMachine menu
2. Navigate to **Input** tab
3. Toggle **"Grab the keyboard input"** off and on
4. Test typing

---

### Phase 3: Server-Side (motoko) Diagnostics

**3.1 Check NoMachine Server Logs**

```bash
# On motoko
sudo journalctl -u nxserver --since "1 hour ago" --no-pager | grep -i -E "(keyboard|input|error|warning|timeout)"

# Look for:
# - Keyboard input errors
# - Session timeouts
# - Buffer overflows
```

**3.2 Check Active NoMachine Sessions**

```bash
# On motoko
sudo /usr/NX/bin/nxserver --status

# Check for:
# - Active session count
# - Session IDs
# - Connection quality metrics
```

**3.3 Verify Server Configuration**

```bash
# On motoko
sudo cat /usr/NX/etc/server.cfg | grep -i -E "(keyboard|input|buffer|timeout)"

# Check for custom settings that might affect input handling
```

**3.4 Check for Application Keyboard Grabs**

**During active NoMachine session, from SSH:**

```bash
# On motoko, check for applications grabbing keyboard
xdotool key XF86LogGrabInfo

# Check session logs for grab information
# If an application has grabbed the keyboard, release it:
xdotool key XF86ClearGrab
```

**3.5 Check X11 Input Configuration**

```bash
# On motoko
xset q

# Check for:
# - Keyboard repeat rate
# - Input device status
```

**3.6 Monitor System Resources**

```bash
# On motoko, during active typing session
htop

# Check for:
# - High CPU usage (should be <20% for idle session)
# - Memory pressure
# - I/O wait
```

---

### Phase 4: NoMachine Configuration Optimization

**4.1 Client-Side Configuration (count-zero)**

**Edit connection profile:** `~/Documents/NoMachine/motoko.nxs`

```xml
<!DOCTYPE NXClientSettings>
<NXClientSettings application="nxclient" version="2.0">
  <group name="General" >
    <option key="Server host" value="motoko.pangolin-vega.ts.net" />
    <option key="Server port" value="4000" />
    <option key="Session" value="unix" />
    <option key="Resolution" value="fit" />
    <option key="Link quality" value="9" />
    <!-- Try reducing to 8 or 7 if keystrokes still drop -->
  </group>
  <group name="Advanced" >
    <option key="Grab the keyboard input" value="true" />
    <option key="Grab the mouse input" value="true" />
    <!-- Add these if not present -->
    <option key="Use UDP communication when available" value="true" />
    <option key="Use H.264 codec when available" value="true" />
  </group>
  <group name="Keyboard" >
    <!-- Add keyboard-specific settings -->
    <option key="Keyboard layout" value="auto" />
    <option key="Send special keys" value="true" />
  </group>
</NXClientSettings>
```

**4.2 Server-Side Configuration (motoko)**

**Edit server configuration:** `/usr/NX/etc/server.cfg`

```bash
# Backup current config
sudo cp /usr/NX/etc/server.cfg /usr/NX/etc/server.cfg.backup.$(date +%Y%m%d)

# Add or modify these settings (if not present):
sudo nano /usr/NX/etc/server.cfg
```

**Recommended settings to check/add:**

```ini
# Increase input buffer size (if available in your version)
# InputBufferSize 65536

# Reduce input latency
# InputLatency 0

# Enable keyboard event optimization
# KeyboardOptimization 1

# Set session timeout (prevent premature disconnects)
# SessionTimeout 3600
```

**After modifying server.cfg:**
```bash
sudo systemctl restart nxserver
```

---

### Phase 5: Application-Level Diagnostics

**5.1 Test in Different Applications**

Test typing in:
- Terminal (gnome-terminal)
- Text editor (gedit, nano, vim)
- Browser (Firefox, Chrome)
- IDE (VS Code, if installed)

**Document which applications show keystroke dropping.**

**5.2 Check for Conflicting Input Methods**

```bash
# On motoko
ibus list-engine

# Check for multiple input method frameworks running
# Disable unused input methods if causing conflicts
```

**5.3 Test Keyboard Layout Matching**

```bash
# On motoko
setxkbmap -print

# On count-zero (macOS)
defaults read -g AppleKeyboardUIMode

# Ensure layouts are compatible
```

---

## Common Root Causes & Solutions

### Issue 1: Stuck Modifier Keys

**Symptoms:** Some keys work, others don't; modifier combinations fail

**Solution:**
1. Press and release all modifier keys during session
2. Toggle keyboard grab: `Ctrl+Alt+0` → Input → Toggle "Grab keyboard"
3. If persistent, disconnect and reconnect session

### Issue 2: Application Keyboard Grab

**Symptoms:** Keystrokes work in some apps, not others

**Solution:**
```bash
# On motoko, during session
xdotool key XF86ClearGrab

# Or identify and close the grabbing application
xdotool search --name "Application Name" windowkill
```

### Issue 3: Network Buffer Overflow

**Symptoms:** Keystrokes drop during high network activity

**Solution:**
1. Reduce NoMachine link quality from 9 to 7 or 8
2. Disable H.264 codec (may reduce bandwidth)
3. Check for other network-intensive processes

### Issue 4: macOS Input Method Conflicts

**Symptoms:** Specific key combinations fail (especially Cmd key)

**Solution:**
1. On count-zero, check System Preferences → Keyboard → Modifier Keys
2. Ensure Command key is mapped correctly
3. Disable conflicting keyboard shortcuts

### Issue 5: X11 Input Device Issues

**Symptoms:** Intermittent keystroke drops, especially after system sleep

**Solution:**
```bash
# On motoko
sudo systemctl restart gdm  # Will log out all users

# Or restart X11 input subsystem
sudo udevadm trigger --subsystem-match=input
```

### Issue 6: NoMachine Version Mismatch

**Symptoms:** Various input issues, especially with special keys

**Solution:**
1. Ensure client and server versions match (v9.2.18-3)
2. Update both to latest version if mismatch exists
3. Test with matching versions

---

## Systematic Testing Procedure

**Test 1: Basic Typing Test**

1. Connect to motoko via NoMachine from count-zero
2. Open terminal: `gnome-terminal`
3. Type: `echo "The quick brown fox jumps over the lazy dog"`
4. Count missing characters
5. Document which characters drop

**Test 2: Rapid Typing Test**

1. Open text editor: `gedit`
2. Type rapidly for 30 seconds
3. Count dropped keystrokes
4. Calculate drop rate: `(dropped / total) * 100`

**Test 3: Modifier Key Test**

1. Test each modifier combination:
   - `Ctrl+C`, `Ctrl+V`, `Ctrl+Z`
   - `Alt+Tab`, `Alt+F4`
   - `Shift+Arrow` (text selection)
2. Document which combinations fail

**Test 4: Application-Specific Test**

1. Test typing in:
   - Terminal
   - Text editor
   - Browser address bar
   - IDE
2. Document which applications show issues

---

## Resolution Workflow

### Step 1: Quick Fixes (5 minutes)

1. ✅ Toggle keyboard grab: `Ctrl+Alt+0` → Input → Toggle
2. ✅ Press/release all modifier keys
3. ✅ Disconnect and reconnect session

### Step 2: Configuration Check (10 minutes)

1. ✅ Verify client connection profile settings
2. ✅ Check server logs for errors
3. ✅ Verify network connectivity quality

### Step 3: System Diagnostics (15 minutes)

1. ✅ Check for application keyboard grabs
2. ✅ Monitor system resources
3. ✅ Test in multiple applications

### Step 4: Configuration Optimization (20 minutes)

1. ✅ Adjust NoMachine link quality
2. ✅ Modify server configuration if needed
3. ✅ Update client connection profile

### Step 5: Advanced Troubleshooting (30+ minutes)

1. ✅ Check X11 input configuration
2. ✅ Verify keyboard layout matching
3. ✅ Test with different NoMachine versions
4. ✅ Escalate to NoMachine support if unresolved

---

## Monitoring & Validation

### Success Criteria

**Keystroke drop rate < 0.1%:**
- Test: Type 1000 characters, count drops
- Target: ≤ 1 dropped keystroke per 1000

**All modifier combinations work:**
- Test: All `Ctrl+`, `Alt+`, `Shift+` combinations
- Target: 100% success rate

**Consistent across applications:**
- Test: Terminal, editor, browser, IDE
- Target: No application-specific issues

### Ongoing Monitoring

```bash
# Create monitoring script on motoko
cat > ~/monitor-nomachine-input.sh << 'EOF'
#!/bin/bash
# Monitor NoMachine input quality
SESSION_ID=$(/usr/NX/bin/nxserver --status | grep -oP 'Session \K[0-9]+' | head -1)
if [ -n "$SESSION_ID" ]; then
    echo "Active session: $SESSION_ID"
    # Check session quality metrics
    /usr/NX/bin/nxserver --status | grep -A 5 "Session $SESSION_ID"
fi
EOF

chmod +x ~/monitor-nomachine-input.sh
```

---

## Escalation Path

**If issue persists after all troubleshooting steps:**

1. **Collect Diagnostics:**
   ```bash
   # On motoko
   sudo journalctl -u nxserver --since "24 hours ago" > /tmp/nomachine-logs.txt
   /usr/NX/bin/nxserver --status > /tmp/nomachine-status.txt
   
   # On count-zero
   /Applications/NoMachine.app/Contents/Frameworks/bin/nxplayer --version > /tmp/nomachine-client-version.txt
   ```

2. **Document Findings:**
   - Keystroke drop rate
   - Affected applications
   - Network quality metrics
   - Configuration changes attempted

3. **Escalate to:**
   - miket-infra-devices Chief Architect (Codex-CA-001)
   - NoMachine support (if version-specific bug suspected)

---

## Related Documentation

- [NoMachine Client Testing Procedure](../runbooks/nomachine-client-testing.md)
- [NoMachine Client Installation](../runbooks/nomachine-client-installation.md)
- [Tailscale Device Setup](../runbooks/TAILSCALE_DEVICE_SETUP.md)
- [Device Onboarding Initiative](../initiatives/device-onboarding/)

---

## Change Log

**2025-11-24:** Initial troubleshooting guide created
- Network baseline verified (0% packet loss, ~4ms latency)
- Systematic diagnostic procedure established
- Common root causes documented

---

**End of Troubleshooting Guide**

