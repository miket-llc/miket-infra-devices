# Enable Tailscale SSH on Count-Zero (macOS)

## Problem
The Tailscale GUI app on macOS is sandboxed and can't run the SSH server.

## Solution
Install Tailscale CLI via Homebrew alongside the GUI (or replace it).

## Steps (Run on Count-Zero)

### Option 1: Install CLI via Homebrew (Recommended)

```bash
# Install Tailscale CLI
brew install tailscale

# Stop GUI if running
# (Keep it running if you want the GUI, CLI and GUI can coexist)

# Start Tailscale daemon
sudo brew services start tailscale

# Connect with SSH enabled
sudo tailscale up --accept-dns --advertise-tags=tag:workstation,tag:macos --ssh --accept-routes

# Verify SSH is enabled
tailscale status --json | jq '.Self.SSHEnabled'
# Should show: true (not null)
```

### Option 2: Use System Extension (Alternative)

```bash
# Install system extension version (not sandboxed)
# Download from: https://pkgs.tailscale.com/stable/#macos

# Or via command line:
curl -o ~/Downloads/Tailscale.zip https://pkgs.tailscale.com/stable/Tailscale-1.56.1-macos.zip
unzip ~/Downloads/Tailscale.zip -d ~/Downloads/
# Install the .pkg file
```

## Verify It Works

From motoko:
```bash
# This should work without passwords/keys
tailscale ssh mdt@count-zero hostname

# Or connect interactively
tailscale ssh mdt@count-zero
```

## Benefits
- ✅ No SSH key management
- ✅ Uses Tailscale identity (Entra ID)
- ✅ Automatic host key verification
- ✅ Works from any device on tailnet
- ✅ ACL-controlled access

## Check Current Setup

On count-zero, check what's installed:
```bash
# Check if GUI is running
ps aux | grep -i tailscale

# Check if CLI is available
which tailscale
tailscale version

# Check if it's the Homebrew version
brew list | grep tailscale
```

