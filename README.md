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

### Prerequisites
- Git
- PowerShell 5.1+ (Windows) or Bash (Linux/MacOS)
- SSH access to managed devices
- Ansible (optional, for automation)

### Setup

1. Clone this repository:
   ```bash
   git clone <repository-url>
   cd miket-infra-devices
   ```

2. Review device configurations in `devices/`

3. Copy and customize configuration templates from `configs/`

## Integration with motoko-devops

This repository complements the `~/motoko-devops` script repository. While motoko-devops contains reusable administrative scripts, this repository focuses on:
- Device-specific configurations
- Infrastructure documentation
- Cross-device orchestration
- Backup and monitoring configurations

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