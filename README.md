# miket-infra-devices

## Overview

Centralized infrastructure device management repository for managing configurations, scripts, and documentation for all infrastructure devices.

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

## Repository Integration

### With motoko-devops
This repository complements the `~/motoko-devops` script repository. While motoko-devops contains reusable administrative scripts, this repository focuses on:
- Device-specific configurations
- Infrastructure documentation
- Cross-device orchestration
- Backup and monitoring configurations

### With miket-infra
This repository works in conjunction with `../miket-infra` for Tailscale network configuration:
- **miket-infra**: Defines Tailscale ACL policies, tags, and network rules via Terraform
- **miket-infra-devices**: Applies those tags to devices and manages their configurations
- See `docs/tailscale-integration.md` for full integration details

## Ansible with Tailscale

This repository is configured to work with Ansible over Tailscale/Tailnet for secure, agentless automation across all devices.

## Security Notes

- Never commit sensitive credentials or API keys
- Use environment variables or secure vaults for secrets
- Review `.gitignore` to ensure sensitive files are excluded
- SSH keys and certificates should be managed separately

## Non-Interactive Secrets (1Password)

This repository is configured for fully non-interactive Ansible runs using 1Password CLI for secret management. All decryption and secret retrieval happens on the control node (Motoko) without requiring interactive password prompts.

### Overview

The automation setup ensures:
- **Vault decryption**: Automatic via `scripts/vault_pass.sh` using 1Password CLI
- **SSH connections**: Passwordless via ssh-agent and SSH keys
- **Become/sudo**: Non-interactive via 1Password lookup or environment variables
- **No prompts**: All operations are fully automated

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

#### 2. Configure 1Password Secrets

Store secrets in 1Password using these exact paths:

**Ansible Vault Password:**
```
Vault: Automation
Item: ansible-vault
Field: password
Path: op://Automation/ansible-vault/password
```

**Wintermute Sudo Password (if Linux):**
```
Vault: Automation
Item: wintermute
Field: sudo
Path: op://Automation/wintermute/sudo
```

**Alternative Pattern** (if using item names instead of paths):
```bash
op item get "Ansible Vault" --field password
op item get "wintermute" --field sudo
```

#### 3. Sign In to 1Password CLI

**Mode A: Service Account (Headless/Automation)**
```bash
export OP_SERVICE_ACCOUNT_TOKEN="your-service-account-token"
op account list  # Verify
```

**Mode B: Desktop + CLI (Interactive)**
```bash
op signin
# Follow prompts to authenticate
op account list  # Verify
```

#### 4. Test Non-Interactive Setup

Run the diagnostic playbook to verify all components work without prompts:

```bash
cd ansible
ansible-playbook playbooks/diag_no_prompts.yml -l wintermute
```

**Expected Output:**
```
✅ Vault decryption: PASSED (no prompt required)
✅ SSH connection: PASSED (no passphrase prompt)
✅ Become/sudo: PASSED (no password prompt)
✅ ALL NON-INTERACTIVE CHECKS PASSED
```

### How It Works

#### Vault Password Retrieval

The `scripts/vault_pass.sh` script:
1. Checks if 1Password CLI (`op`) is installed
2. Verifies you're signed in (`op account list`)
3. Retrieves password from `op://Automation/ansible-vault/password`
4. Outputs only the password (no stderr, no newlines)

Configured in `ansible/ansible.cfg`:
```ini
vault_identity_list = default@../scripts/vault_pass.sh
```

#### Become/Sudo Password

For Linux hosts (like Wintermute if configured as Linux), the become password is retrieved via:

1. **Environment variable** (`ANSIBLE_BECOME_PASS`) - highest priority
2. **1Password lookup plugin** - `op://Automation/wintermute/sudo`
3. **Fallback** - Empty string (assumes passwordless sudo)

Configured in `ansible/host_vars/wintermute.yml`:
```yaml
ansible_become: true
ansible_become_method: sudo
ansible_become_password: "{{ lookup('env', 'ANSIBLE_BECOME_PASS') | default(lookup('community.general.onepassword', 'op://Automation/wintermute/sudo', errors='ignore'), true) }}"
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

1. **File Permissions**: Scripts have 700 permissions (`chmod 700 scripts/vault_pass.sh`)
2. **No Secrets in Logs**: Use `no_log: true` for sensitive tasks in playbooks
3. **1Password Access**: Limit Automation vault access to automation accounts only
4. **SSH Keys**: Use ed25519 keys with strong passphrases (handled by ssh-agent)
5. **Service Account**: Use 1Password Service Accounts for CI/CD, not personal accounts

### Verification

After setup, verify everything works:

```bash
# 1. Test vault password script
./scripts/vault_pass.sh
# Should output password (no errors)

# 2. Test SSH agent
./scripts/ensure_ssh_agent.sh
# Should show key loaded

# 3. Test full non-interactive run
cd ansible
ansible-playbook playbooks/diag_no_prompts.yml -l wintermute
# Should pass all checks with no prompts
```

## Contributing

1. Create feature branches for new configurations
2. Test changes on non-production devices first
3. Document all changes in commit messages
4. Update device-specific documentation when making changes

## License

Private repository - All rights reserved