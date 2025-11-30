# Copyright (c) 2025 MikeT LLC. All rights reserved.

# Motoko Playbooks

Ansible playbooks for configuring **motoko** - a Fedora Server headless GPU + storage + container host.

## Quick Start

### Full Site Deployment

Configure motoko from fresh Fedora Server (with Tailscale up) to fully operational node:

```bash
cd ~/miket-infra-devices/ansible
ansible-playbook -i inventory/hosts.yml playbooks/motoko/site.yml
```

### Targeted Deployment (Tags)

Run specific phases using tags:

```bash
# Headless configuration only (lid switch, suspend, boot target)
ansible-playbook -i inventory/hosts.yml playbooks/motoko/site.yml --tags headless

# GPU drivers only
ansible-playbook -i inventory/hosts.yml playbooks/motoko/site.yml --tags gpu

# Storage mounts only
ansible-playbook -i inventory/hosts.yml playbooks/motoko/site.yml --tags storage

# Container runtime only
ansible-playbook -i inventory/hosts.yml playbooks/motoko/site.yml --tags containers

# Services only (update container definitions)
ansible-playbook -i inventory/hosts.yml playbooks/motoko/site.yml --tags services

# Tailscale verification only
ansible-playbook -i inventory/hosts.yml playbooks/motoko/site.yml --tags tailscale
```

### Check Mode (Dry Run)

Preview changes without applying:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/motoko/site.yml --check
```

## Site Playbook Phases

The `site.yml` playbook applies roles in order:

| Phase | Role | Description |
|-------|------|-------------|
| 1 | `fedora_headless_base` | Lid switch, mask suspend targets, multi-user.target |
| 2 | `tailscale_node` | Verify tailscaled, expose tailnet facts |
| 3 | `nvidia_gpu_fedora` | RPM Fusion repos, akmod-nvidia, CUDA packages |
| 4 | `data_mounts_psbi` | Mount /space, /flux, /time from UUIDs |
| 5 | `podman_base` | Podman runtime, NVIDIA Container Toolkit |
| 6 | `motoko_services` | Container services from definitions |

## Available Tags

| Tag | Description |
|-----|-------------|
| `headless` | Lid switch, suspend, boot target configuration |
| `base` | Base system packages |
| `tailscale` | Tailscale verification and facts |
| `gpu`, `nvidia` | NVIDIA driver installation |
| `storage`, `mounts` | PHC data mounts |
| `containers`, `podman` | Container runtime setup |
| `services` | Container service orchestration |

## Prerequisites

1. **Fresh Fedora Server installation**
2. **Tailscale authenticated** - Run `sudo tailscale up --ssh` manually first
3. **SSH access via Tailscale** - Connection must work before running playbooks

## Configuration

Edit `host_vars/motoko.yml` to configure:

- **Storage UUIDs**: Set `psbi_mounts[].uuid` from `blkid` output
- **Container services**: Define `motoko_services[]` for services to run
- **Firewall ports**: Set `firewall_extra_ports[]` for additional ports

## Other Playbooks

| Playbook | Description |
|----------|-------------|
| `fedora-base.yml` | Legacy base configuration (use `site.yml` instead) |
| `configure-headless-boot.yml` | Headless + WoL configuration |
| `configure-usb-storage.yml` | USB drive partitioning (destructive!) |
| `deploy-litellm.yml` | LiteLLM proxy deployment |
| `deploy-nextcloud.yml` | Nextcloud container deployment |

## Idempotence

All playbooks are designed for safe re-runs:

- Minimal changes on configured systems
- No flapping of fstab, systemd, or Tailscale
- Check mode (`--check`) for previewing changes

## Inventory Groups

Motoko belongs to these inventory groups:

- `linux` - All Linux hosts
- `fedora_headless_gpu_nodes` - Fedora headless with GPU
- `psbi_core_nodes` - Primary PSBI infrastructure
- `storage_nodes` - Hosts with PHC storage mounts
- `container_hosts` - Container runtime hosts
- `gpu_8gb` - 8GB VRAM GPU nodes
- `wol_enabled` - Wake-on-LAN capable

## Troubleshooting

### NVIDIA drivers not working after install

```bash
# Drivers need kernel module build on first boot
sudo reboot

# After reboot, verify
nvidia-smi

# If module not built, force it
sudo akmods --force
sudo dracut --force
sudo reboot
```

### Storage mounts not appearing

```bash
# Get UUIDs for your drives
blkid

# Update host_vars/motoko.yml with UUIDs
# Then re-run storage phase
ansible-playbook -i inventory/hosts.yml playbooks/motoko/site.yml --tags storage
```

### Tailscale not connected

```bash
# Check status
tailscale status

# Re-authenticate if needed
sudo tailscale up --ssh
```

### Container services not starting

```bash
# Check user systemd services
systemctl --user status container-*.service

# Check logs
podman logs <container-name>

# Ensure linger is enabled
loginctl enable-linger mdt
```
