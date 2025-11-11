# Repository Separation and Integration Guide

## Overview

This document clarifies the separation of concerns between `miket-infra` and `miket-infra-devices` and how they work together.

## Repository Responsibilities

### miket-infra (Cloud Infrastructure Management)

**Purpose:** Manages cloud-based infrastructure and network policies

**Contains:**
- Tailscale ACL policies and tag definitions (Terraform)
- Cloudflare Access configurations
- Entra ID (Azure AD) configurations
- Azure resources and monitoring
- Network-level security policies

**Does NOT contain:**
- Device-specific configurations
- Ansible playbooks for device management
- Device setup scripts
- SSH user mappings

### miket-infra-devices (Device Management)

**Purpose:** Manages individual devices and their configurations

**Contains:**
- Ansible playbooks and inventory
- Device-specific setup scripts
- Tailscale device configuration scripts
- Device documentation and runbooks
- SSH configuration guides

**Does NOT contain:**
- Tailscale ACL policy definitions (only references them)
- Cloud infrastructure definitions

## Integration Points

### 1. Tailscale Configuration

**miket-infra** defines:
- ACL policies (`infra/tailscale/entra-prod/main.tf`)
- Tag ownership (`tagOwners`)
- Network access rules
- SSH access rules

**miket-infra-devices** applies:
- Tags to devices via scripts (`scripts/setup-tailscale.sh`, `scripts/Setup-Tailscale.ps1`)
- Device-specific Tailscale configurations

### 2. Ansible Management

**miket-infra-devices** contains:
- All Ansible playbooks (`ansible/playbooks/`)
- Inventory files (`ansible/inventory/`)
- Device management roles (`ansible/roles/`)

**miket-infra** does NOT contain:
- Any Ansible playbooks or configurations

## Current Status

### ✅ Completed Cleanup

1. **Moved Ansible playbook** from `miket-infra/infra/ansible/` to `miket-infra-devices/ansible/playbooks/`
2. **Moved device runbooks** from `miket-infra/docs/runbooks/` to `miket-infra-devices/docs/runbooks/`:
   - `ssh-user-mapping.md`
   - `tailscale-ssh-setup.md`
3. **Updated Ansible inventory** with correct tailnet domain (`pangolin-vega.ts.net`)
4. **Removed empty directories** from miket-infra
5. **Created motoko setup documentation** (`docs/runbooks/motoko-ansible-setup.md`)

### ⏳ Next Steps

1. **Set up motoko as Ansible control node:**
   ```bash
   # SSH to motoko
   ssh mdt@192.168.1.201 -p 2222
   
   # Clone miket-infra-devices if needed
   git clone https://github.com/miket-llc/miket-infra-devices.git
   cd miket-infra-devices
   
   # Run setup script
   ./scripts/setup-tailscale.sh motoko
   ```

2. **Verify Tailscale ACLs are deployed:**
   ```bash
   cd ~/miket-infra/infra/tailscale/entra-prod
   terraform plan
   terraform apply  # If changes needed
   ```

3. **Test Ansible connectivity from motoko:**
   ```bash
   cd ~/miket-infra-devices
   ansible all -i ansible/inventory/hosts.yml -m ping
   ```

4. **Set up armitage:**
   - Follow `docs/runbooks/armitage.md` in miket-infra-devices

## File Locations Reference

### Tailscale Configuration
- **ACL Policies:** `miket-infra/infra/tailscale/entra-prod/main.tf`
- **Tag Definitions:** `miket-infra/infra/tailscale/entra-prod/devices.tf`
- **Device Setup Scripts:** `miket-infra-devices/scripts/setup-tailscale.sh`, `miket-infra-devices/scripts/Setup-Tailscale.ps1`

### Ansible Configuration
- **Playbooks:** `miket-infra-devices/ansible/playbooks/`
- **Inventory:** `miket-infra-devices/ansible/inventory/hosts.yml`
- **Roles:** `miket-infra-devices/ansible/roles/`

### Documentation
- **Tailscale Integration:** `miket-infra-devices/docs/tailscale-integration.md`
- **Motoko Setup:** `miket-infra-devices/docs/runbooks/motoko-ansible-setup.md`
- **SSH Setup:** `miket-infra-devices/docs/runbooks/tailscale-ssh-setup.md`
- **SSH User Mapping:** `miket-infra-devices/docs/runbooks/ssh-user-mapping.md`

## Troubleshooting

### If you find device management code in miket-infra:
- **Ansible playbooks** → Move to `miket-infra-devices/ansible/playbooks/`
- **Device setup scripts** → Move to `miket-infra-devices/scripts/`
- **Device documentation** → Move to `miket-infra-devices/docs/`

### If you find cloud infrastructure code in miket-infra-devices:
- **Tailscale ACL definitions** → Move to `miket-infra/infra/tailscale/entra-prod/`
- **Cloud resource definitions** → Move to `miket-infra/infra/`

## Key Principle

**miket-infra** = **What** (policies, rules, cloud resources)  
**miket-infra-devices** = **How** (device configuration, automation, scripts)

