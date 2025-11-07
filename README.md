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

## Contributing

1. Create feature branches for new configurations
2. Test changes on non-production devices first
3. Document all changes in commit messages
4. Update device-specific documentation when making changes

## License

Private repository - All rights reserved