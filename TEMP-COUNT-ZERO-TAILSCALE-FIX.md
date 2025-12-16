# Temporary: count-zero Tailscale SSH Fix

**Delete this file after completing the fix.**

## Problem

The App Store version of Tailscale cannot run as an SSH server (sandboxed).
Only the `tailscaled` (Homebrew) variant supports SSH server on macOS.

## Steps to Fix

### 1. Remove App Store Tailscale (if not already done)

```bash
# Quit Tailscale from menu bar first
sudo rm -rf /Applications/Tailscale.app
rm -rf ~/.Trash/*
# Reboot if you haven't already
```

### 2. Install Homebrew tailscaled

```bash
brew install tailscale
```

### 3. Find the binary location

```bash
which tailscale
# Should be /opt/homebrew/bin/tailscale on Apple Silicon
```

### 4. Start tailscaled daemon

```bash
# Try as user first (recommended by Homebrew)
brew services start tailscale

# Check if it's running
brew services list | grep tailscale

# If not running, check logs
cat ~/Library/Logs/Homebrew/tailscale.log 2>/dev/null || echo "No user log"
cat /Library/Logs/Homebrew/tailscale.log 2>/dev/null || echo "No system log"
```

### 5. Check tailscaled status

```bash
/opt/homebrew/bin/tailscale status
```

If you get "failed to connect to local tailscaled":

```bash
# Check if tailscaled process is running
ps aux | grep tailscaled

# Try starting manually to see errors
sudo /opt/homebrew/opt/tailscale/bin/tailscaled
```

### 6. Login and enable SSH

```bash
/opt/homebrew/bin/tailscale login
# (opens browser for auth)

/opt/homebrew/bin/tailscale up --ssh --advertise-tags=tag:workstation,tag:macos --accept-dns --accept-routes
```

### 7. Verify from another device

From motoko or another tailnet device:
```bash
tailscale ssh mdt@count-zero "echo success"
```

## After Success

1. Delete this file
2. Run the Ansible playbook to deploy persistence:
   ```bash
   ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/deploy-tailscale-and-codex.yml --limit count-zero
   ```

## Troubleshooting

### "no such file or directory" errors
Homebrew on Apple Silicon uses `/opt/homebrew`, not `/usr/local`. Always use full paths:
- Binary: `/opt/homebrew/bin/tailscale`
- Daemon: `/opt/homebrew/opt/tailscale/bin/tailscaled`

### tailscaled won't start
Check if old Tailscale processes are still running:
```bash
ps aux | grep -i tailscale
sudo killall tailscaled 2>/dev/null
sudo killall Tailscale 2>/dev/null
```

### Permission issues
The Homebrew version may need specific permissions. Check:
```bash
ls -la /opt/homebrew/var/run/tailscale/
```
