# miket-infra-devices

**Status:** ✅ **PRODUCTION-READY** - Comprehensive architectural review complete  
**Architecture Version:** v1.7.0 (Wave 1 completion: NoMachine standardization, RDP/VNC removal)  
**Last Updated:** November 23, 2025

---

## ✅ Current Status

**INFRASTRUCTURE VALIDATED AND OPERATIONAL**

This repository manages device-level configuration for MikeT LLC infrastructure devices. Comprehensive remediation completed:

- ✅ **Tailscale Network:** All devices operational, sub-4ms latency
- ✅ **Ansible Management:** WinRM working for Windows devices
- ✅ **vLLM (armitage):** Qwen2.5-7B-Instruct running on port 8000
- ✅ **vLLM (wintermute):** Container operational, Llama-3-8B-Instruct-AWQ
- ✅ **LiteLLM (motoko):** Proxy healthy and serving requests
- ✅ **Auto-Switcher Removed:** Energy-wasting code completely purged
- ✅ **Documentation:** Comprehensive status tracking and team structure

**See:** [EXECUTIVE_SUMMARY.md](EXECUTIVE_SUMMARY.md) for complete details  
**See:** [STATUS.md](docs/product/STATUS.md) for real-time status dashboard

### 🆕 Devices Infrastructure Ready for Deployment

Complete client-side infrastructure implemented for mounts, OS cloud sync, and devices view:
- **macOS:** System-level mounts at `/mkt/*` with user symlinks `~/flux`, `~/space`, `~/time`
- **Windows:** Network drives `X:` (FLUX), `S:` (SPACE), `T:` (TIME) with labels
- **OS Cloud Sync:** Automated nightly iCloud/OneDrive → `/space/devices/` synchronization
- **Loop Prevention:** Multi-layer guards against infinite sync loops

**Deploy:** `ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/deploy-devices-infrastructure.yml`  
**Guide:** [Deployment Runbook](docs/runbooks/devices-infrastructure-deployment.md)

---

## Overview

Device-level configuration management for MikeT LLC infrastructure, coordinating with miket-infra for network policy and ACL management.

## Device Inventory

### Linux Servers
- **motoko** - Ubuntu 24.04.2 LTS Server
  - NVIDIA GeForce RTX 2080 GPU
  - Docker host with NVIDIA runtime
  - Primary services: Docker containers, Samba, AFP, text-generation-webui
  - Location: `/mnt/lacie` backup storage, `/mnt/data/docker` Docker root

### Windows Workstations  
- **wintermute** - Windows Workstation
  - NVIDIA GeForce RTX 4070 Super GPU
  - Development and gaming workstation

- **armitage** - Windows Workstation (Alienware Laptop)
  - NVIDIA GeForce RTX 4070 GPU
  - Mobile development workstation

### MacOS Devices
- **count-zero** - MacBook Pro (Personal)
  - Development laptop with custom terminal configuration

- **Managed MacBook Pro** - IT-managed device
  - Corporate development environment

## Repository Structure

```
miket-infra-devices/
├── devices/           # Device-specific configurations and documentation
│   ├── motoko/
│   ├── wintermute/
│   ├── armitage/
│   └── count-zero/
├── configs/           # Shared configuration files
│   ├── ssh/
│   ├── docker/
│   └── network/
├── scripts/           # Management and automation scripts
│   ├── backup/
│   ├── monitoring/
│   └── deployment/
├── ansible/           # Ansible automation
│   ├── playbooks/
│   ├── inventory/
│   └── roles/
├── docker/            # Docker compose files and configurations
├── backup/            # Backup configurations and scripts
├── monitoring/        # Monitoring configurations
└── docs/              # Additional documentation
```

## Quick Start

### Setting Up Motoko as Ansible Control Node

**One-command setup:**
```bash
curl -fsSL https://raw.githubusercontent.com/miket-llc/miket-infra-devices/main/scripts/bootstrap-motoko.sh | bash
```

Or manually:
```bash
git clone https://github.com/miket-llc/miket-infra-devices.git ~/miket-infra-devices
cd ~/miket-infra-devices
./scripts/bootstrap-motoko.sh
```

See [Quick Start Guide](docs/QUICK_START_MOTOKO.md) for details.

### Setting Up Armitage (Windows Workstation)

**One-command setup (from armitage as Administrator):**
```powershell
git clone https://github.com/miket-llc/miket-infra-devices.git C:\Users\$env:USERNAME\dev\miket-infra-devices
cd C:\Users\$env:USERNAME\dev\miket-infra-devices
.\scripts\bootstrap-armitage.ps1
```

This will:
- Configure WinRM for Ansible management
- Configure Tailscale with proper tags (`tag:workstation,tag:windows,tag:gaming`)
- Verify connectivity

See [Armitage Setup Runbook](docs/runbooks/armitage-setup.md) for detailed instructions.

### Setting Up macOS Devices (count-zero, etc.)

**One-command setup (from macOS device):**
```bash
curl -fsSL https://raw.githubusercontent.com/miket-llc/miket-infra-devices/main/scripts/bootstrap-macos.sh | bash
```

Or manually:
```bash
git clone https://github.com/miket-llc/miket-infra-devices.git ~/miket-infra-devices
cd ~/miket-infra-devices
./scripts/bootstrap-macos.sh
```

This will:
- Install Tailscale via Homebrew
- Configure MagicDNS with /etc/resolver (CRITICAL for Homebrew Tailscale)
- Enable Tailscale SSH
- Enable Remote Login
- Configure user permissions

**Post-Bootstrap: Run Ansible from motoko:**
```bash
cd /home/mdt/miket-infra-devices/ansible
ansible-playbook -i inventory/hosts.yml playbooks/setup-macos-tailscale.yml -l count-zero
```

**For RDP client:** Install Microsoft Remote Desktop from Mac App Store and enable Local Network Access in Privacy settings.

See [macOS Tailscale Setup Runbook](docs/runbooks/macos-tailscale-setup.md) for detailed instructions.

### Prerequisites
- Git
- PowerShell 5.1+ (Windows) or Bash (Linux/MacOS)
- SSH access to managed devices
- Ansible (installed automatically on motoko)

### Device Setup

1. **Motoko (Ansible Control Node):** Run `./scripts/bootstrap-motoko.sh`
2. **Armitage (Windows Workstation):** Run `.\scripts\bootstrap-armitage.ps1`
3. **Other devices:** Follow device-specific guides in `docs/runbooks/`
4. **Review configurations:** Check `devices/` for device-specific configs

## Model Validation

To validate that Armitage is running the correct model (Qwen2.5-7B-Instruct) and verify the full vLLM → LiteLLM → Ansible control flow:

```bash
# From Motoko
cd ~/miket-infra-devices
./scripts/Validate-Armitage-Model.sh
```

Or use the Ansible playbook:
```bash
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/armitage-vllm-validate.yml \
  --limit armitage \
  --ask-vault-pass
```

See [Armitage Model Validation Runbook](docs/runbooks/armitage-model-validation.md) for detailed instructions.

## 📚 Documentation & Management

**Core Management Documents:**
- **[STATUS.md](docs/product/STATUS.md)** - Current status dashboard with metrics and issues
- **[EXECUTION_TRACKER.md](docs/product/EXECUTION_TRACKER.md)** - Task tracking and agent deliverables
- **[TEAM_ROLES.md](docs/product/TEAM_ROLES.md)** - Agent responsibilities and coordination
- **[COMMUNICATION_LOG.md](docs/communications/COMMUNICATION_LOG.md)** - Chronological action log

**Key Runbooks:**
- **[TAILSCALE_DEVICE_SETUP.md](docs/runbooks/TAILSCALE_DEVICE_SETUP.md)** - Device enrollment and SSH configuration
- **[ENABLE_TAILSCALE_SSH.md](ENABLE_TAILSCALE_SSH.md)** - IMMEDIATE ACTIONS REQUIRED

---

## Repository Integration

### With miket-infra (Network Policy Authority)
This repository works in conjunction with `../miket-infra` for Tailscale network configuration:
- **miket-infra**: Defines Tailscale ACL policies, tags, network rules, and enrollment keys
- **miket-infra-devices**: Manages device-level configuration (SSH enablement, service deployment)
- **Separation of Concerns:** miket-infra controls POLICY, this repo controls DEVICE CONFIG

### With motoko-devops
Complements `~/motoko-devops` script repository with device-specific configurations and Ansible automation.

## Ansible with Tailscale

This repository is configured to work with Ansible over Tailscale/Tailnet for secure, agentless automation across all devices.

## Security Notes

- Never commit sensitive credentials or API keys
- Use environment variables or secure vaults for secrets
- Review `.gitignore` to ensure sensitive files are excluded
- SSH keys and certificates should be managed separately

## Non-Interactive Secrets (File-Based)

This repository is configured for fully non-interactive Ansible runs using local file-based secret management. All decryption and secret retrieval happens on the control node (Motoko) without requiring interactive password prompts or external dependencies.

### Overview

The automation setup ensures:
- **Vault decryption**: Automatic via `/etc/ansible/.vault-pass.txt` (root-only file)
- **SSH connections**: Passwordless via ssh-agent and SSH keys
- **Become/sudo**: Non-interactive via `/etc/ansible/.become-pass.txt` (root-only file)
- **No prompts**: All operations are fully automated
- **No dependencies**: No 1Password CLI or external services required

### Setup

#### 1. Ensure SSH Agent is Running

```bash
./scripts/ensure_ssh_agent.sh
```

This script:
- Starts ssh-agent if not running
- Adds your SSH key (`~/.ssh/id_ed25519` or `~/.ssh/id_rsa`) to the agent
- Verifies the key is loaded

**SSH Key Location**: The script looks for keys in standard locations:
- `~/.ssh/id_ed25519` (preferred)
- `~/.ssh/id_rsa` (fallback)
- `~/.ssh/id_ecdsa` (fallback)

#### 2. Configure Local Secret Files (Motoko Only)

Create two root-only files on the Motoko control node:

**Ansible Vault Password File:**
```bash
# Create the directory
sudo mkdir -p /etc/ansible

# Create the vault password file
echo 'YOUR_VAULT_PASSWORD_HERE' | sudo tee /etc/ansible/.vault-pass.txt

# Set secure permissions (root-only read)
sudo chmod 600 /etc/ansible/.vault-pass.txt
sudo chown root:root /etc/ansible/.vault-pass.txt
```

**Become/Sudo Password File:**
```bash
# Create the become password file
echo 'YOUR_SUDO_PASSWORD_HERE' | sudo tee /etc/ansible/.become-pass.txt

# Set secure permissions (root-only read)
sudo chmod 600 /etc/ansible/.become-pass.txt
sudo chown root:root /etc/ansible/.become-pass.txt
```

**Important Security Notes:**
- These files must NEVER be committed to git (already in .gitignore)
- Only store on Motoko control node (not on target machines)
- Backup only to encrypted storage
- Use strong passwords (20+ characters)
- Optional: Use `sudo chattr +i /etc/ansible/.vault-pass.txt` to make immutable

#### 3. Test Non-Interactive Setup

Run the diagnostic playbook to verify all components work without prompts:

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/diag_no_prompts.yml
```

**Expected Output:**
```
✅ Vault decryption: PASSED (no prompt required)
✅ SSH connection: PASSED (no passphrase prompt)
✅ Become/sudo: PASSED (no password prompt)
✅ ALL DIAGNOSTICS PASSED
```

### How It Works

#### Vault Password Retrieval

Ansible reads the vault password directly from `/etc/ansible/.vault-pass.txt`:

1. File is read once at Ansible startup
2. Password is used to decrypt all vaulted variables
3. No external commands or network calls required
4. Root-only permissions ensure security

Configured in `ansible/ansible.cfg`:
```ini
vault_identity_list = default@/etc/ansible/.vault-pass.txt
```

#### Become/Sudo Password

For all hosts, the become password is retrieved from `/etc/ansible/.become-pass.txt`:

1. File is read via Ansible's `lookup('file', ...)` function
2. Trimmed to remove any whitespace
3. Passed to sudo for privilege escalation
4. No prompts or external dependencies

Configured in `ansible/group_vars/all/auth.yml`:
```yaml
ansible_become: true
ansible_become_method: sudo
ansible_become_password: "{{ lookup('file', '/etc/ansible/.become-pass.txt') | trim }}"
```

#### SSH Key Management

The `scripts/ensure_ssh_agent.sh` script ensures:
- ssh-agent is running
- Your SSH private key is loaded
- No passphrase prompts during Ansible runs

**Note**: If your SSH key has a passphrase, ensure:
- 1Password SSH agent is configured, OR
- Key is unlocked in ssh-agent before running Ansible

### Systemd Service (Optional)

For automated 1Password session management on Motoko, use the provided systemd user service:

**Install:**
```bash
# Copy service files
mkdir -p ~/.config/systemd/user
cp systemd/op-session.service ~/.config/systemd/user/
cp systemd/op-session.timer ~/.config/systemd/user/

# Edit service to set your 1Password account
# Replace %i in ExecStart with your account shorthand (e.g., miket)
sed -i 's/%i/your-account-shorthand/' ~/.config/systemd/user/op-session.service

# For Mode A (Service Account), create override:
systemctl --user edit op-session.service
# Add:
# [Service]
# Environment="OP_SERVICE_ACCOUNT_TOKEN=your-token-here"

# Enable and start
systemctl --user enable op-session.timer
systemctl --user start op-session.timer
```

**Modes:**

- **Mode A (Headless)**: Set `OP_SERVICE_ACCOUNT_TOKEN` in service override. Fully automated, no user interaction.
- **Mode B (Desktop)**: Uses `op signin` with your account. Requires periodic authentication but works with desktop app.

### Common Issues and Fixes

#### "Error: 1Password CLI (op) is not installed"
```bash
# Install 1Password CLI
# Linux:
curl -sSf https://downloads.1password.com/linux/keys/1password.asc | sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main' | sudo tee /etc/apt/sources.list.d/1password.list
sudo apt update && sudo apt install 1password-cli

# macOS:
brew install 1password-cli
```

#### "Error: Not signed in to 1Password account"
```bash
# Sign in
op signin

# Or set service account token
export OP_SERVICE_ACCOUNT_TOKEN="your-token"
```

#### "Error: Failed to retrieve vault password from 1Password"
- Verify the item exists: `op item get "ansible-vault" --vault Automation`
- Check you have access to the Automation vault
- Verify the field name is exactly `password`

#### "SSH key passphrase prompt"
```bash
# Ensure ssh-agent is running and key is loaded
./scripts/ensure_ssh_agent.sh

# If key has passphrase, unlock it:
ssh-add ~/.ssh/id_ed25519

# Or configure 1Password SSH agent to handle passphrases automatically
```

#### "Become password prompt"
- Set environment variable: `export ANSIBLE_BECOME_PASS="your-sudo-password"`
- Or ensure 1Password item exists: `op://Automation/wintermute/sudo`
- Or configure passwordless sudo on the target host (recommended for automation)

### Running Ansible Playbooks

With the non-interactive setup, simply run playbooks without any flags:

```bash
cd ansible
ansible-playbook playbooks/your-playbook.yml -l wintermute
```

No `--ask-vault-pass`, `--ask-become-pass`, or password prompts required!

### Security Best Practices

1. **File Permissions**: Secret files have 600 permissions (root:root only)
2. **No Secrets in Logs**: Use `no_log: true` for sensitive tasks in playbooks
3. **File Immutability**: Optional use of `chattr +i` to prevent accidental modification
4. **SSH Keys**: Use ed25519 keys with strong passphrases (handled by ssh-agent)
5. **Backup Security**: Only backup secret files to encrypted storage
6. **Full-Disk Encryption**: Recommended for control node to protect secrets at rest
7. **No Git Commits**: Secret files are explicitly excluded via .gitignore

### Verification

After setup, verify everything works:

```bash
# 1. Test secret file permissions
sudo ls -la /etc/ansible/.vault-pass.txt /etc/ansible/.become-pass.txt
# Should show: -rw------- 1 root root (600 permissions, root:root ownership)

# 2. Test SSH agent
./scripts/ensure_ssh_agent.sh
# Should show key loaded

# 3. Test full non-interactive run
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/diag_no_prompts.yml
# Should pass all checks with no prompts
```

## Local Secrets on Motoko

### Overview

Ansible secrets for this infrastructure are stored in two root-only files on the Motoko control node:

1. **`/etc/ansible/.vault-pass.txt`** - Ansible Vault password (for decrypting vaulted variables)
2. **`/etc/ansible/.become-pass.txt`** - Sudo/become password (for privilege escalation)

These files are **NEVER** committed to git and exist **ONLY** on Motoko.

### Setup Instructions

#### Creating the Secret Files

```bash
# Create the directory
sudo mkdir -p /etc/ansible

# Create vault password file
echo 'YOUR_VAULT_PASSWORD_HERE' | sudo tee /etc/ansible/.vault-pass.txt

# Create become password file
echo 'YOUR_SUDO_PASSWORD_HERE' | sudo tee /etc/ansible/.become-pass.txt

# Set secure permissions (600 = read/write for owner only)
sudo chmod 600 /etc/ansible/.vault-pass.txt /etc/ansible/.become-pass.txt

# Set ownership (root:root)
sudo chown root:root /etc/ansible/.vault-pass.txt /etc/ansible/.become-pass.txt

# Verify permissions
sudo ls -la /etc/ansible/
# Should show: -rw------- 1 root root <size> <date> .vault-pass.txt
#              -rw------- 1 root root <size> <date> .become-pass.txt
```

#### File Permissions Requirements

| File | Permissions | Ownership | Purpose |
|------|-------------|-----------|---------|
| `/etc/ansible/.vault-pass.txt` | `600` | `root:root` | Ansible Vault decryption |
| `/etc/ansible/.become-pass.txt` | `600` | `root:root` | Sudo/become privilege escalation |

**Why root:root 600?**
- Only root can read the files (no other users)
- Protects against accidental exposure
- Ansible typically runs as root or with sudo
- Follows principle of least privilege

### Backup and Recovery

#### Backup Guidance

**DO:**
- ✅ Store backup in encrypted password manager (e.g., 1Password, Bitwarden)
- ✅ Use encrypted external storage (LUKS, VeraCrypt)
- ✅ Document location in secure runbook
- ✅ Test recovery process periodically

**DON'T:**
- ❌ Commit to git repository
- ❌ Store in unencrypted cloud storage
- ❌ Email or message passwords in plain text
- ❌ Store on network shares without encryption

#### Recovery Process

If Motoko is rebuilt or secrets are lost:

```bash
# 1. Retrieve passwords from secure backup (e.g., 1Password)
VAULT_PASS=$(op read "op://Automation/ansible-vault/password")
BECOME_PASS=$(op read "op://Automation/motoko-sudo/password")

# 2. Recreate files on Motoko
sudo mkdir -p /etc/ansible
echo "$VAULT_PASS" | sudo tee /etc/ansible/.vault-pass.txt
echo "$BECOME_PASS" | sudo tee /etc/ansible/.become-pass.txt

# 3. Set permissions
sudo chmod 600 /etc/ansible/.vault-pass.txt /etc/ansible/.become-pass.txt
sudo chown root:root /etc/ansible/.vault-pass.txt /etc/ansible/.become-pass.txt

# 4. Verify
cd /path/to/miket-infra-devices/ansible
ansible-playbook -i inventory/hosts.yml playbooks/diag_no_prompts.yml
```

### Password Rotation

#### How to Rotate Passwords

**Important:** Password rotation does NOT require any git repository changes!

##### 1. Rotate Vault Password

```bash
# Generate new strong password
NEW_VAULT_PASS=$(openssl rand -base64 32)

# Re-key all vaulted files with new password
cd ansible
for vault_file in $(find . -name "*vault.yml" -o -name "*vault.yaml"); do
  ansible-vault rekey "$vault_file" --new-vault-password-file=<(echo "$NEW_VAULT_PASS")
done

# Update the file on Motoko
echo "$NEW_VAULT_PASS" | sudo tee /etc/ansible/.vault-pass.txt
sudo chmod 600 /etc/ansible/.vault-pass.txt
sudo chown root:root /etc/ansible/.vault-pass.txt

# Update backup in password manager
op item edit "ansible-vault" password="$NEW_VAULT_PASS"
```

##### 2. Rotate Become Password

```bash
# Update sudo password on target hosts first
# Then update file on Motoko
echo 'NEW_SUDO_PASSWORD' | sudo tee /etc/ansible/.become-pass.txt
sudo chmod 600 /etc/ansible/.become-pass.txt
sudo chown root:root /etc/ansible/.become-pass.txt

# Update backup in password manager
op item edit "motoko-sudo" password="NEW_SUDO_PASSWORD"
```

##### 3. Restart Systemd Jobs (if applicable)

```bash
# If using systemd timers for Ansible automation
sudo systemctl restart ansible-automation.service
sudo systemctl status ansible-automation.service
```

### Optional Hardening

#### Make Files Immutable

Prevent accidental modification or deletion:

```bash
# Make files immutable (cannot be modified, even by root)
sudo chattr +i /etc/ansible/.vault-pass.txt
sudo chattr +i /etc/ansible/.become-pass.txt

# Check immutable attribute
lsattr /etc/ansible/.vault-pass.txt
# Should show: ----i------------ /etc/ansible/.vault-pass.txt

# To modify later, remove immutable flag first:
sudo chattr -i /etc/ansible/.vault-pass.txt
# Make changes, then re-apply:
sudo chattr +i /etc/ansible/.vault-pass.txt
```

#### Full-Disk Encryption

For maximum security, enable full-disk encryption on Motoko:

- **LUKS** (Linux Unified Key Setup) for root filesystem
- **TPM 2.0** for automatic unlock on trusted boot
- **Encrypted swap** to prevent password leakage

#### Restrict Physical Access

- Keep Motoko in secure location
- Enable BIOS/UEFI password
- Disable boot from USB/network without password
- Enable secure boot

### Troubleshooting

#### Vault Decryption Fails

**Symptom:** `ERROR! Decryption failed`

**Solutions:**
```bash
# 1. Check file exists
sudo ls -la /etc/ansible/.vault-pass.txt

# 2. Check permissions
sudo stat /etc/ansible/.vault-pass.txt
# Should show: Access: (0600/-rw-------) Uid: (0/root) Gid: (0/root)

# 3. Check file contents (not empty)
sudo wc -l /etc/ansible/.vault-pass.txt
# Should show: 1 /etc/ansible/.vault-pass.txt

# 4. Check for whitespace issues
sudo cat -A /etc/ansible/.vault-pass.txt
# Should show password with $ at end (no extra newlines)

# 5. Verify ansible.cfg points to correct file
grep vault_identity_list ansible/ansible.cfg
# Should show: vault_identity_list = default@/etc/ansible/.vault-pass.txt
```

#### Become/Sudo Fails

**Symptom:** `FAILED! => {"msg": "Missing sudo password"}`

**Solutions:**
```bash
# 1. Check file exists
sudo ls -la /etc/ansible/.become-pass.txt

# 2. Check permissions (same as vault file)
sudo stat /etc/ansible/.become-pass.txt

# 3. Test manual sudo
sudo -k  # Clear cached credentials
cat /etc/ansible/.become-pass.txt | sudo -S id
# Should authenticate and show: uid=0(root)

# 4. Verify group_vars configuration
grep -A 2 ansible_become_password ansible/group_vars/all/auth.yml
# Should show: ansible_become_password: "{{ lookup('file', '/etc/ansible/.become-pass.txt') | trim }}"
```

## Tailnet Remote Desktop

This repository includes comprehensive Ansible automation for standardizing remote desktop access across the Tailscale tailnet using **NoMachine** as the sole remote desktop solution. All connections are restricted to the Tailscale network (100.64.0.0/10) and use MagicDNS for hostname resolution.

**Architecture:** RDP and VNC have been architecturally retired (2025-11-22). NoMachine is the only remote desktop protocol in use.

### Overview

- **All Platforms**: NoMachine (port 4000) - unified protocol across Linux, Windows, and macOS
- **Session Sharing**: NoMachine supports session sharing on all platforms
- **Security**: All firewall rules restrict access to Tailscale subnet only (100.64.0.0/10)
- **Zero Public Exposure**: No ports exposed to the internet
- **Standardized Configuration**: Port 4000, Tailscale MagicDNS hostnames, NX protocol

### Quick Start

#### 1. Deploy NoMachine Servers

Install and configure NoMachine servers on all hosts:

```bash
cd ansible
# Deploy to all servers
ansible-playbook -i inventory/hosts.yml playbooks/remote_server.yml --tags remote:server

# Or use Makefile
make deploy-nomachine-servers
```

This will:
- Install NoMachine server on Linux (motoko)
- Install NoMachine server on Windows (wintermute, armitage)
- Disable deprecated RDP/VNC services (architectural compliance)
- Configure firewall rules for Tailscale-only access (port 4000)

#### 2. Deploy NoMachine Clients

Install NoMachine clients on all workstations:

```bash
# Deploy to all clients
ansible-playbook -i inventory/hosts.yml playbooks/remote_clients_nomachine.yml --tags remote:client

# Or use Makefile
make deploy-nomachine-clients
```

This will:
- Install NoMachine client on macOS (count-zero)
- Install NoMachine client on Windows (wintermute, armitage)
- Install NoMachine client on Linux (motoko)
- Create standardized connection profiles for all servers

#### 3. Validate Deployment

Verify NoMachine deployment:

```bash
# Run validation playbook
ansible-playbook -i inventory/hosts.yml playbooks/validate_nomachine_deployment.yml

# Or run smoke tests
make test-nomachine

# Or use Makefile
make validate-nomachine
```

### Connection Methods

#### All Platforms (NoMachine)

**GUI**:
- **macOS**: Launch `/Applications/NoMachine.app`
- **Windows**: Start Menu > NoMachine
- **Linux**: Applications menu > NoMachine or run `nxplayer`

**CLI Helper Script**:
```bash
# All platforms support the same helper script
nomachine motoko      # Connect to motoko (Linux)
nomachine wintermute   # Connect to wintermute (Windows)
nomachine armitage    # Connect to armitage (Windows)
```

**Direct Connection**:
```bash
# macOS
open "nx://motoko.pangolin-vega.ts.net:4000"

# Windows PowerShell
& "C:\Program Files\NoMachine\bin\nxplayer.exe" --session motoko.pangolin-vega.ts.net:4000

# Linux
/usr/NX/bin/nxplayer --session motoko.pangolin-vega.ts.net:4000
```

**Pre-configured Profiles**:
Connection profiles are automatically created in:
- **macOS/Linux**: `~/Documents/NoMachine/*.nxs`
- **Windows**: `%USERPROFILE%\Documents\NoMachine\*.nxs`

Profiles include: `motoko.nxs`, `wintermute.nxs`, `armitage.nxs`

### Protocols and Ports

| Host | Protocol | Port | MagicDNS Hostname | OS | Notes |
|------|----------|------|-------------------|----|-------|
| motoko | NoMachine | 4000 | `motoko.pangolin-vega.ts.net:4000` | Linux (Pop!_OS) | Session sharing supported |
| wintermute | NoMachine | 4000 | `wintermute.pangolin-vega.ts.net:4000` | Windows | Session sharing supported |
| armitage | NoMachine | 4000 | `armitage.pangolin-vega.ts.net:4000` | Windows | Session sharing supported |

**Deprecated Ports (Architectural Compliance)**:
- **RDP (3389)**: Disabled and firewalled on all Windows hosts
- **VNC (5900)**: Removed from all Linux hosts

### Why NoMachine (Unified Solution)

NoMachine is used across all platforms because:

1. **Unified Protocol**: Single protocol (NX) for all platforms - simplifies management
2. **Session Sharing**: Supports session sharing on Linux, Windows, and macOS
3. **Performance**: Better performance than VNC/RDP, especially over Tailscale
4. **Cross-Platform**: Native clients for all platforms with consistent UX
5. **Security**: Encrypted connections by default, Tailscale-only access
6. **Architectural Alignment**: Aligns with miket-infra architecture decision (RDP/VNC retired 2025-11-22)

### Troubleshooting

#### Connection Issues

**Verify Tailscale connectivity**:
```bash
ping motoko.pangolin-vega.ts.net
tailscale status
```

**Test NoMachine port connectivity**:
```bash
# Test port 4000
nc -zv motoko.pangolin-vega.ts.net 4000
# Expected: Connection to motoko.pangolin-vega.ts.net port 4000 [tcp/*] succeeded!
```

**Check firewall rules**:
```bash
# Linux (ufw)
sudo ufw status | grep 4000
# Expected: 4000/tcp ALLOW 100.64.0.0/10

# Windows PowerShell
Get-NetFirewallRule -Name "*NoMachine*" | Select-Object DisplayName, Enabled, Direction
```

**Verify NoMachine service is running**:
```bash
# Linux
systemctl status nxserver
# Expected: active (running)

# Windows PowerShell
Get-Service nxservice
# Expected: Running
```

#### NoMachine Service Issues

**Linux**:
```bash
# Check NoMachine logs
sudo journalctl -u nxserver -n 50

# Restart NoMachine service
sudo systemctl restart nxserver
```

**Windows**:
```powershell
# Check Event Viewer
Get-EventLog -LogName Application -Source NoMachine -Newest 10

# Restart NoMachine service
Restart-Service nxservice
```

#### MagicDNS Not Resolving

If MagicDNS fails, use Tailscale IPs directly:

```bash
# Get IPs
tailscale status | grep -E "(motoko|wintermute|armitage)"

# Create IP-based connection profile
# Host: 100.x.x.x (instead of hostname.pangolin-vega.ts.net)
# Port: 4000
```

#### Firewall Checks

**Linux**:
```bash
# Verify NoMachine port is open for Tailscale subnet
sudo ufw status | grep 4000
# Expected: 4000/tcp ALLOW 100.64.0.0/10

# Verify deprecated ports are blocked
sudo ufw status | grep -E "(3389|5900)"
# Expected: No output (ports not open)
```

**Windows**:
```powershell
# Check NoMachine firewall rule
Get-NetFirewallRule -Name "NoMachine-Tailscale" | Format-List

# Verify Tailscale subnet restriction
Get-NetFirewallRule -Name "NoMachine-Tailscale" | Get-NetFirewallAddressFilter
# Expected: RemoteAddress: 100.64.0.0/10
```

### Playbook Tags

All NoMachine playbooks support these tags for targeted execution:

- `remote` - All remote desktop tasks
- `remote:server` - Server configuration only
- `remote:client` - Client installation only
- `remote:firewall` - Firewall configuration only
- `nomachine:client` - NoMachine client installation only
- `validate` - Validation tasks only

Example:
```bash
# Only configure servers
ansible-playbook -i inventory/hosts.yml playbooks/remote_server.yml --tags remote:server

# Only install clients
ansible-playbook -i inventory/hosts.yml playbooks/remote_clients_nomachine.yml --tags remote:client

# Run validation
ansible-playbook -i inventory/hosts.yml playbooks/validate_nomachine_deployment.yml --tags validate
```

### Inventory Groups

Inventory groups for NoMachine management:

- `workstations` - All workstations (clients)
- `linux_servers` - Linux hosts serving NoMachine (motoko)
- `windows_servers` - Windows hosts serving NoMachine (wintermute, armitage)
- `macos` - macOS hosts (count-zero)

### Host Variables

Each host can override defaults in `host_vars/HOSTNAME.yml`:

```yaml
# NoMachine configuration
nomachine_port: 4000  # Default port
nomachine_version: "9.2.18-3"  # Server version
```

### Security Notes

- **No Public Exposure**: All firewall rules restrict access to Tailscale subnet (100.64.0.0/10)
- **MagicDNS**: Use `.pangolin-vega.ts.net` hostnames for automatic resolution
- **Encrypted Connections**: NoMachine uses encrypted connections by default
- **Architectural Compliance**: RDP (3389) and VNC (5900) ports are disabled and firewalled

### Smoke Tests

Run NoMachine connectivity smoke tests:

```bash
# Run smoke tests
make test-nomachine

# Or directly
python3 tests/nomachine_smoke.py
```

Tests validate:
- NoMachine servers are reachable on port 4000
- RDP/VNC ports are NOT listening (architectural compliance)
- Connection latency and responsiveness

### Additional Resources

- **Client Installation**: `docs/runbooks/nomachine-client-installation.md`
- **Client Testing**: `docs/runbooks/nomachine-client-testing.md`
- **Ansible Roles**: `ansible/roles/remote_*_nomachine/`
- **Playbooks**: `ansible/playbooks/remote_*_nomachine.yml`

## Contributing

1. Create feature branches for new configurations
2. Test changes on non-production devices first
3. Document all changes in commit messages
4. Update device-specific documentation when making changes

## License

Private repository - All rights reserved
