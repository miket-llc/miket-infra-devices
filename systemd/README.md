# Systemd 1Password Session Service

## Overview

The systemd user service (`op-session.service`) and timer (`op-session.timer`) provide automated 1Password CLI session management on Motoko. This ensures the 1Password CLI remains authenticated for non-interactive Ansible runs.

## Installation

```bash
# Create systemd user directory
mkdir -p ~/.config/systemd/user

# Copy service files
cp systemd/op-session.service ~/.config/systemd/user/
cp systemd/op-session.timer ~/.config/systemd/user/

# Edit service to set your 1Password account shorthand
# Replace 'your-account-shorthand' with your actual account (e.g., 'miket')
sed -i 's/%i/your-account-shorthand/' ~/.config/systemd/user/op-session.service

# Or manually edit:
# nano ~/.config/systemd/user/op-session.service
# Change: ExecStart=/usr/bin/op signin --account %i
# To:     ExecStart=/usr/bin/op signin --account miket
```

## Configuration Modes

### Mode A: Service Account (Headless/Automation)

Best for: Fully automated, CI/CD, no user interaction

```bash
# Create service override
systemctl --user edit op-session.service

# Add:
[Service]
Environment="OP_SERVICE_ACCOUNT_TOKEN=op://Automation/service-account-token"
```

**Benefits:**
- Fully automated, no user interaction
- Works in headless environments
- No session expiration issues

**Requirements:**
- 1Password Service Account created
- Service account token stored in 1Password

### Mode B: Desktop + CLI (Interactive)

Best for: Personal use, desktop environment

```bash
# No override needed - uses default op signin
# Service will prompt for authentication on first run
```

**Benefits:**
- Works with 1Password desktop app
- Uses existing desktop session
- Simpler setup

**Limitations:**
- Requires periodic authentication
- May prompt for biometric/desktop unlock

## Enable and Start

```bash
# Reload systemd user daemon
systemctl --user daemon-reload

# Enable timer (starts service automatically)
systemctl --user enable op-session.timer

# Start timer immediately
systemctl --user start op-session.timer

# Check status
systemctl --user status op-session.timer
systemctl --user status op-session.service

# View logs
journalctl --user -u op-session.service -f
```

## Timer Schedule

The timer is configured to:
- Start 5 minutes after boot (`OnBootSec=5min`)
- Refresh every 30 minutes (`OnUnitActiveSec=30min`)

This ensures:
- Service starts automatically after reboot
- Session stays fresh (1Password sessions typically last 30-60 minutes)

## Manual Operations

```bash
# Manually trigger service
systemctl --user start op-session.service

# Check if signed in
op account list

# View service logs
journalctl --user -u op-session.service --since "1 hour ago"

# Stop timer (service will still run on-demand)
systemctl --user stop op-session.timer

# Disable timer
systemctl --user disable op-session.timer
```

## Troubleshooting

### Service fails to start

```bash
# Check logs
journalctl --user -u op-session.service -n 50

# Common issues:
# - Account shorthand incorrect: Fix in service file
# - 1Password CLI not in PATH: Add to ExecStart path
# - Service account token invalid: Regenerate token
```

### Session expires

```bash
# Check timer is running
systemctl --user status op-session.timer

# Manually refresh
systemctl --user start op-session.service

# Verify
op account list
```

### Service account token not working

```bash
# Verify token format
echo $OP_SERVICE_ACCOUNT_TOKEN

# Test token manually
export OP_SERVICE_ACCOUNT_TOKEN="your-token"
op account list

# If fails, regenerate service account token in 1Password
```

## Security Notes

1. **Service Account Tokens**: Store in 1Password, never commit to git
2. **File Permissions**: Service files should be 600 (readable by user only)
3. **Logs**: Service logs may contain account info - review before sharing
4. **Access Control**: Limit Automation vault access to automation accounts only

## Integration with Ansible

The systemd service ensures `op account list` succeeds, which is required by `scripts/vault_pass.sh`. If the service fails, Ansible vault decryption will fail with a clear error message.

Test integration:
```bash
# Ensure service is running
systemctl --user status op-session.service

# Test vault password script
./scripts/vault_pass.sh

# Should output password without errors
```

