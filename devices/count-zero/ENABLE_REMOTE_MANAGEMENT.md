# Enable Remote Management on Count-Zero (macOS)

## Current Issues
- SSH is disabled/not accessible
- Cannot manage remotely via Ansible
- Tailscale SSH is not enabled

## Setup Steps

### 1. Enable macOS Remote Login (SSH)

Run these commands locally on count-zero:

```bash
# Enable Remote Login (SSH)
sudo systemsetup -setremotelogin on

# Verify it's enabled
sudo systemsetup -getremotelogin
# Should output: "Remote Login: On"

# Ensure SSH is running
sudo launchctl list | grep ssh
```

### 2. Enable Tailscale SSH

This allows SSH access through Tailscale without opening regular SSH:

```bash
# Enable Tailscale SSH and fix MagicDNS at the same time
tailscale up --accept-dns --advertise-tags=tag:workstation,tag:macos --ssh
```

### 3. Configure SSH Access for mdt User

```bash
# Ensure mdt user exists and has proper shell
dscl . -read /Users/mdt UserShell

# Add mdt to admin group if not already
sudo dseditgroup -o edit -a mdt -t user admin

# Set up SSH key authentication (if needed)
mkdir -p ~/.ssh
chmod 700 ~/.ssh
# Copy public key from motoko to count-zero
```

### 4. Test SSH Access

From motoko, test both methods:

```bash
# Test Tailscale SSH
tailscale ssh mdt@count-zero hostname

# Test regular SSH
ssh mdt@count-zero.pangolin-vega.ts.net hostname
```

### 5. Configure Ansible Variables

The inventory already has count-zero configured. Verify these settings work:

```yaml
# ansible/inventory/hosts.yml (already configured)
count-zero:
  ansible_host: count-zero.pangolin-vega.ts.net
  ansible_user: mdt
  ansible_become: yes
  ansible_python_interpreter: /usr/bin/python3
```

### 6. Test Ansible Connectivity

From motoko:

```bash
cd /home/mdt/miket-infra-devices
ansible -i ansible/inventory/hosts.yml count-zero -m ping
ansible -i ansible/inventory/hosts.yml count-zero -m shell -a "uname -a"
```

## Additional Management Tools

### Enable Screen Sharing (VNC)

If you want VNC access:

```bash
# Enable Screen Sharing
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate -configure -access -on -restart -agent -privs -all

# Set VNC password (will prompt)
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -configure -clientopts -setvnclegacy -vnclegacy yes -setvncpw -vncpw YOUR_PASSWORD
```

### Install Homebrew (if not present)

```bash
# Install Homebrew for package management
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install useful tools
brew install jq wget curl
```

## Security Considerations

- SSH is restricted to Tailscale network (100.64.0.0/10)
- Tailscale SSH uses your Tailscale identity for authentication
- Regular SSH should use key-based authentication, not passwords
- Screen Sharing (VNC) should only be accessible via Tailscale

## Verification Checklist

- [ ] Remote Login enabled: `sudo systemsetup -getremotelogin`
- [ ] Tailscale SSH enabled: `tailscale status --json | jq '.Self.HostName'`
- [ ] MagicDNS working: `ping motoko`
- [ ] SSH accessible from motoko: `ssh mdt@count-zero.pangolin-vega.ts.net hostname`
- [ ] Ansible connectivity: `ansible count-zero -m ping`

## Troubleshooting

### SSH Connection Refused
```bash
# Check if SSH is running
sudo launchctl list | grep ssh
# Should see: com.openssh.sshd

# Restart SSH if needed
sudo launchctl stop com.openssh.sshd
sudo launchctl start com.openssh.sshd
```

### Tailscale SSH Not Working
```bash
# Check Tailscale status
tailscale status

# Re-run with SSH flag
tailscale up --accept-dns --advertise-tags=tag:workstation,tag:macos --ssh
```

### Permission Denied
```bash
# Ensure mdt user is in admin group
groups mdt

# Add to admin if missing
sudo dseditgroup -o edit -a mdt -t user admin
```


