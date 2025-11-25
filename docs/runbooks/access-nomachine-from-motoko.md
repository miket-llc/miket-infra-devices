---
document_title: "Access NoMachine Servers from motoko"
author: "Codex-CA-001 (Chief Architect)"
last_updated: 2025-11-27
status: Active
---

# Access NoMachine Servers from motoko

**Current Status:**
- ✅ NoMachine server package installed on motoko (v9.2.18-3)
- ❌ NoMachine server not running (port 4000 connection refused)
- ❌ NoMachine client not installed/running
- ✅ Can access wintermute and count-zero NoMachine servers via Tailscale

## Option 1: Install NoMachine Client on motoko (Recommended)

```bash
# Install NoMachine client
sudo apt update
sudo apt install nomachine

# Launch client
nxplayer

# Or via GUI
# Applications → NoMachine → NoMachine
```

Then connect to:
- `wintermute.pangolin-vega.ts.net:4000`
- `armitage.pangolin-vega.ts.net:4000`
- `count-zero.pangolin-vega.ts.net:4000`

## Option 2: SSH Port Forwarding (Temporary Access)

Create an SSH tunnel to forward NoMachine port:

```bash
# Forward wintermute NoMachine to local port
ssh -L 4000:wintermute.pangolin-vega.ts.net:4000 mdt@wintermute.pangolin-vega.ts.net

# In another terminal, connect to localhost:4000
# (Requires NoMachine client installed locally)
```

Or forward to a different local port:

```bash
# Forward to local port 4001
ssh -L 4001:wintermute.pangolin-vega.ts.net:4000 mdt@wintermute.pangolin-vega.ts.net

# Connect to localhost:4001
```

## Option 3: Use Existing Access Points

**From wintermute:**
- Already has NoMachine client
- Can connect to all other servers
- Use this as your primary access point

**From count-zero:**
- Has NoMachine client
- Can connect to other servers
- Alternative access point

## Option 4: Start NoMachine Server on motoko

If you want to make motoko a NoMachine server:

```bash
# Start NoMachine server
sudo systemctl start nxserver
sudo systemctl enable nxserver

# Verify it's running
sudo systemctl status nxserver
sudo netstat -tulpn | grep 4000

# Should show: listening on port 4000
```

Then other devices can connect to `motoko.pangolin-vega.ts.net:4000`

## Option 5: Reverse SSH Tunnel (Advanced)

If you need to access motoko's NoMachine from outside:

```bash
# On motoko, create reverse tunnel to another device
ssh -R 4000:localhost:4000 mdt@wintermute.pangolin-vega.ts.net

# Then from wintermute, connect to localhost:4000
# (This forwards to motoko's NoMachine server)
```

## Current Server Status

| Server | Port 4000 | Status | Access Method |
|--------|-----------|--------|---------------|
| motoko | ❌ Refused | Server not running | Install client or start server |
| wintermute | ✅ Accessible | Running | Direct connection |
| armitage | ⏱️ Timeout | Offline/blocked | Check status |
| count-zero | ✅ Accessible | Running | Direct connection |

## Quick Test

```bash
# Test connectivity from motoko
for host in wintermute armitage count-zero; do
  echo "Testing $host..."
  nc -zv ${host}.pangolin-vega.ts.net 4000 2>&1 | head -1
done
```

## Recommended Approach

**For immediate access:**
1. Use wintermute's NoMachine client (already working)
2. Or install NoMachine client on motoko: `sudo apt install nomachine`

**For long-term:**
- Install NoMachine client on motoko for direct access
- Consider starting NoMachine server on motoko if you need remote access TO motoko

