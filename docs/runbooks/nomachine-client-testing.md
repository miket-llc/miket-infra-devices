---
document_title: "NoMachine Client Testing Procedure"
author: "Codex-MAC-012 (macOS Engineer) & Codex-PM-011"
last_updated: 2025-11-23
status: Active
related_initiatives:
  - initiatives/device-onboarding
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md#2025-11-23-nomachine-client-testing
---

# NoMachine Client Testing Procedure

**Purpose:** End-to-end validation of NoMachine client connectivity from macOS devices to all NoMachine servers

**Target Devices:**
- **Client:** count-zero (macOS)
- **Servers:** motoko (Linux), wintermute (Windows), armitage (Windows)

**Server Baseline:** v9.2.18-3, Port 4000, Tailscale-bound (delivered by miket-infra 2025-11-22)

---

## Pre-Flight Checklist

### Server Status Verification (Via Tailscale SSH)

**1. Verify NoMachine Service Running on All Servers**

```bash
# SSH to motoko (Linux)
ssh mdt@motoko.pangolin-vega.ts.net
sudo systemctl status nxserver
# Expected: active (running)

# Check NoMachine version
/usr/NX/bin/nxserver --version
# Expected: v9.2.18-3

# Check listening port and binding
sudo netstat -tulpn | grep 4000
# Expected: 100.92.23.71:4000 (Tailscale IP, not 0.0.0.0)

# Check firewall rules
sudo ufw status | grep 4000
# Expected: Allow from 100.64.0.0/10 (Tailscale subnet)

exit
```

```powershell
# SSH to wintermute (Windows)
ssh mdt@wintermute.pangolin-vega.ts.net

# Check NoMachine service
Get-Service nxservice
# Expected: Running

# Check NoMachine version
& "C:\Program Files\NoMachine\bin\nxserver.exe" --version
# Expected: v9.2.18-3

# Check listening port
Get-NetTCPConnection -LocalPort 4000 | Select-Object LocalAddress, State
# Expected: Tailscale IP, Listen state

exit
```

```powershell
# SSH to armitage (Windows)
ssh mdt@armitage.pangolin-vega.ts.net

# Same checks as wintermute
Get-Service nxservice
& "C:\Program Files\NoMachine\bin\nxserver.exe" --version
Get-NetTCPConnection -LocalPort 4000 | Select-Object LocalAddress, State

exit
```

**2. Verify Tailscale Connectivity from count-zero**

```bash
# From count-zero (macOS)
ping -c 3 motoko.pangolin-vega.ts.net
ping -c 3 wintermute.pangolin-vega.ts.net
ping -c 3 armitage.pangolin-vega.ts.net

# Check Tailscale status
tailscale status

# Verify MagicDNS working (or use IPs if DNS broken)
# motoko: 100.92.23.71
# wintermute: [get from tailscale status]
# armitage: [get from tailscale status]
```

---

## NoMachine Client Installation (count-zero)

### Installation Steps

**1. Download NoMachine for macOS**

```bash
# Option A: Download from NoMachine website
# Visit: https://www.nomachine.com/download
# Download: NoMachine for Mac (v9.2.18 or later to match server version)

# Option B: Use curl (if direct link available)
cd ~/Downloads
# Update URL to match current version
curl -O https://download.nomachine.com/download/9.2/MacOSX/nomachine_9.2.18_3.dmg
```

**2. Install NoMachine**

```bash
# Open the DMG
open nomachine_9.2.18_3.dmg

# Drag NoMachine to Applications
# Or use installer if provided

# Verify installation
ls -la /Applications/NoMachine.app

# Check installed version
/Applications/NoMachine.app/Contents/Frameworks/bin/nxplayer --version
# Expected: v9.2.18 or compatible
```

**3. Initial NoMachine Setup**

```bash
# Launch NoMachine for first time
open /Applications/NoMachine.app

# Accept license agreement
# Configure initial preferences:
# - Enable "Use UDP communication when available"
# - Set quality: "Adaptive" (auto-adjusts based on network)
# - Enable "Use H.264 codec when available"
```

---

## Connection Testing Procedure

### Test 1: motoko (Linux Server)

**Connection Method:** NoMachine Protocol

**1. Create Connection Profile**

```
In NoMachine app:
1. Click "New" or "Add connection"
2. Connection details:
   - Protocol: NX
   - Host: motoko.pangolin-vega.ts.net
   - Port: 4000
   - Authentication: Password
   - Username: mdt
   
3. Save connection as "motoko-nx"
```

**2. Attempt Connection**

```
1. Double-click "motoko-nx" connection
2. Enter password for mdt@motoko
3. Expected: Connection successful, GNOME desktop appears
4. Monitor connection quality indicator
5. Test actions:
   - Open terminal
   - Open file browser
   - Resize window
   - Test clipboard copy/paste
   - Test file transfer (drag/drop)
```

**3. Record Results**

```yaml
test_id: NX-MOTOKO-001
date: 2025-11-23
client: count-zero (macOS)
server: motoko (Linux, Ubuntu 24.04.2)
transport: Tailscale (100.64.0.0/10)
connection_time: [seconds to establish]
quality: [Excellent/Good/Fair/Poor]
latency: [ms]
bandwidth: [Mbps]
issues: [list any issues]
status: [PASS/FAIL]
```

### Test 2: wintermute (Windows Server)

**Connection Method:** NoMachine Protocol

**1. Create Connection Profile**

```
In NoMachine app:
1. Click "New" or "Add connection"
2. Connection details:
   - Protocol: NX
   - Host: wintermute.pangolin-vega.ts.net
   - Port: 4000
   - Authentication: Password
   - Username: mdt
   
3. Save connection as "wintermute-nx"
```

**2. Attempt Connection**

```
1. Double-click "wintermute-nx" connection
2. Enter password for mdt@wintermute
3. Expected: Connection successful, Windows desktop appears
4. Test actions:
   - Open File Explorer
   - Verify network drives visible (X:, S:, T:)
   - Test Start menu
   - Test clipboard
   - Test file transfer
```

**3. Record Results**

```yaml
test_id: NX-WINTERMUTE-001
date: 2025-11-23
client: count-zero (macOS)
server: wintermute (Windows)
transport: Tailscale
connection_time: [seconds]
quality: [rating]
latency: [ms]
bandwidth: [Mbps]
issues: [list]
status: [PASS/FAIL]
```

### Test 3: armitage (Windows Server)

**Repeat same procedure as wintermute:**

```yaml
test_id: NX-ARMITAGE-001
date: 2025-11-23
client: count-zero (macOS)
server: armitage (Windows)
transport: Tailscale
connection_time: [seconds]
quality: [rating]
latency: [ms]
bandwidth: [Mbps]
issues: [list]
status: [PASS/FAIL]
```

---

## Fallback Testing (If MagicDNS Fails)

### Use Direct Tailscale IPs

**1. Get Tailscale IPs**

```bash
# From count-zero
tailscale status | grep -E "(motoko|wintermute|armitage)"

# Example output:
# motoko        mdt@         linux   -       100.92.23.71
# wintermute    mdt@         windows -       100.x.x.x
# armitage      mdt@         windows -       100.x.x.x
```

**2. Create IP-Based Connection Profiles**

```
Connection details:
- Host: 100.92.23.71 (instead of motoko.pangolin-vega.ts.net)
- Port: 4000
- Save as "motoko-ip"
```

**3. Test IP-Based Connections**

```
If MagicDNS fails:
1. Test using IP addresses directly
2. Record which method works (DNS vs IP)
3. Document MagicDNS failure in test results
4. Escalate to miket-infra if DNS consistently fails
```

---

## Performance Benchmarking

### Connection Quality Metrics

**1. Latency Test**

```bash
# From count-zero, measure RTT to each server
ping -c 10 motoko.pangolin-vega.ts.net | tail -1
ping -c 10 wintermute.pangolin-vega.ts.net | tail -1
ping -c 10 armitage.pangolin-vega.ts.net | tail -1

# Expected: <10ms (same LAN), <50ms (via Tailscale relay)
```

**2. Bandwidth Test**

```bash
# Use iperf3 if available on servers
# Or measure file transfer speeds via NoMachine

# Transfer 100MB test file from count-zero to motoko:/tmp/
# Record transfer time and calculate throughput
```

**3. Session Quality Assessment**

```
During active NoMachine session:
1. Check connection quality indicator (top-right corner)
2. Monitor frame rate (should be 30+ fps for smooth UX)
3. Test responsiveness (mouse/keyboard lag)
4. Test multimedia playback (if applicable)
5. Test full-screen mode
```

---

## Troubleshooting Guide

### Issue: Connection Refused

**Symptoms:** "Connection refused" or "Unable to connect to server"

**Diagnosis:**
```bash
# Check if server port 4000 is reachable
nc -zv motoko.pangolin-vega.ts.net 4000
# Expected: Connection to motoko.pangolin-vega.ts.net port 4000 [tcp/*] succeeded!

# If fails, check Tailscale connectivity
ping motoko.pangolin-vega.ts.net

# Check firewall on server (via SSH)
ssh mdt@motoko.pangolin-vega.ts.net
sudo ufw status | grep 4000
# Expected: 4000/tcp ALLOW 100.64.0.0/10
```

**Resolution:**
1. Verify NoMachine service running on server
2. Verify firewall allows Tailscale subnet
3. Verify client Tailscale connection active

### Issue: Authentication Failed

**Symptoms:** "Authentication failed" or "Invalid credentials"

**Diagnosis:**
```bash
# Test SSH login first (uses same credentials)
ssh mdt@motoko.pangolin-vega.ts.net
# If SSH works, NoMachine should too
```

**Resolution:**
1. Verify username is `mdt` (not `mike` or other)
2. Verify password matches SSH password
3. Check server auth logs: `sudo journalctl -u nxserver | tail -20`

### Issue: Slow/Laggy Connection

**Symptoms:** High latency, poor frame rate, choppy display

**Diagnosis:**
```bash
# Check Tailscale routing mode
tailscale status

# Check if using DERP relay vs direct connection
# Direct connection preferred (lower latency)
```

**Resolution:**
1. Try connection quality settings: Adaptive → Low quality
2. Disable H.264 codec if compatibility issues
3. Check network congestion (other downloads/streams)
4. Verify LAN connection vs Tailscale relay

### Issue: MagicDNS Not Resolving

**Symptoms:** "Could not resolve hostname"

**Diagnosis:**
```bash
# Test DNS resolution
nslookup motoko.pangolin-vega.ts.net
# Should resolve to 100.x.x.x

# Check Tailscale DNS settings
tailscale status | grep DNS
```

**Resolution:**
1. Use IP addresses instead of hostnames (workaround)
2. Restart Tailscale on count-zero: `sudo tailscale down && sudo tailscale up`
3. Escalate to miket-infra for MagicDNS fix

---

## Test Results Documentation

### Results Template

```markdown
# NoMachine Client Testing Results - count-zero

**Test Date:** 2025-11-23
**Tester:** Codex-MAC-012 (macOS Engineer)
**Client:** count-zero (macOS [version])
**NoMachine Client Version:** [version]

## Server: motoko (Linux)
- Connection Method: [DNS/IP]
- Connection Time: [seconds]
- Quality: [Excellent/Good/Fair/Poor]
- Latency: [ms]
- Bandwidth: [Mbps]
- Issues: [list or "None"]
- Status: **[PASS/FAIL]**
- Notes: [additional observations]

## Server: wintermute (Windows)
- Connection Method: [DNS/IP]
- Connection Time: [seconds]
- Quality: [rating]
- Latency: [ms]
- Bandwidth: [Mbps]
- Issues: [list or "None"]
- Status: **[PASS/FAIL]**
- Notes: [additional observations]

## Server: armitage (Windows)
- Connection Method: [DNS/IP]
- Connection Time: [seconds]
- Quality: [rating]
- Latency: [ms]
- Bandwidth: [Mbps]
- Issues: [list or "None"]
- Status: **[PASS/FAIL]**
- Notes: [additional observations]

## Overall Assessment
- **Total Tests:** 3
- **Passed:** [count]
- **Failed:** [count]
- **Blocker Issues:** [Yes/No - list if yes]
- **Recommendation:** [Proceed with Wave 2 / Fix issues first]

## Next Steps
1. [Action item 1]
2. [Action item 2]
3. [Action item 3]
```

### Results Storage

**Save results to:**
```
/space/devices/count-zero/mdt/testing/nomachine-client-test-YYYY-MM-DD.md
```

**Also log in:**
```
docs/communications/COMMUNICATION_LOG.md#2025-11-23-nomachine-client-testing
```

---

## Success Criteria

**Wave 2 Unblock Requirements:**

| Criterion | Target | Critical? |
|-----------|--------|-----------|
| Connection Success Rate | ≥ 95% (all 3 servers) | ✅ Yes |
| Connection Time | < 10 seconds | ⚠️ Medium |
| Session Quality | Good or Excellent | ✅ Yes |
| Latency | < 50ms | ⚠️ Medium |
| No Blocker Issues | Zero critical bugs | ✅ Yes |

**PASS Criteria:** All critical criteria met, medium criteria <80% acceptable

**FAIL Criteria:** Any critical criterion fails OR >2 medium criteria fail

---

## Post-Test Actions

### If Tests PASS

1. ✅ Update DAY0_BACKLOG: DEV-011 → Complete
2. ✅ Update EXECUTION_TRACKER: NoMachine client testing complete
3. ✅ Log results in COMMUNICATION_LOG
4. ✅ Proceed with DEV-005 execution (client standardization)
5. ✅ Document NoMachine as production-ready for macOS

### If Tests FAIL

1. ⚠️ Document all failure details and error messages
2. ⚠️ Escalate to miket-infra if server-side issues
3. ⚠️ Create fix tasks in DAY0_BACKLOG
4. ⚠️ Block Wave 2 client standardization until resolved
5. ⚠️ Coordinate with miket-infra Chief Architect for troubleshooting

---

## Coordination with miket-infra

### Information Sharing

**Share with miket-infra team:**
1. Test results summary (PASS/FAIL per server)
2. Connection quality metrics (latency, bandwidth)
3. Any server-side issues discovered
4. MagicDNS status (working vs. IP fallback required)

**Request from miket-infra team:**
1. MagicDNS fix timeline (if DNS failures observed)
2. Server-side NoMachine logs (if connection issues)
3. Tailscale routing optimization recommendations
4. Wave 2 coordination for full client rollout

---

## Related Documentation

- [NoMachine Server Deployment](../../miket-infra/docs/communications/COMMUNICATION_LOG.md#2025-11-22-nomachine-second-pass) (miket-infra)
- [Tailscale Device Setup](./TAILSCALE_DEVICE_SETUP.md)
- [Device Onboarding Runbook](./onboarding.md)
- [Weekly Alignment Report](../communications/WEEKLY_ALIGNMENT_2025_11_23.md)

---

**End of Testing Procedure**

