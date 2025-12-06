# Akira Bootstrap Implementation Summary

**Date:** 2025-12-04  
**Status:** READY FOR EXECUTION  
**Phase:** 0 / v1.0 (Initial Linux-side bootstrap)

---

## What Was Created

This implementation provides a **complete, production-ready bootstrap** for akira, a new Linux AI/dev workstation joining the MikeT PHC. All work respects the global architecture constraints (IaC-first, secrets from AKV, Tailscale-first networking, Flux/Space/Time ontology).

### Documentation

| File | Purpose |
|------|---------|
| `docs/runbooks/AKIRA_BOOTSTRAP.md` | **Manual steps runbook** (BIOS, OS install, partitioning, first boot) |
| `docs/architecture/AKIRA_BOOTSTRAP_PLAN.md` | **Comprehensive bootstrap plan** (architecture, security, execution flow) |
| `AKIRA_BOOTSTRAP_SUMMARY.md` | **This file** (quick reference and file inventory) |

### Device Configuration

| File | Purpose |
|------|---------|
| `devices/akira/config.yml` | Device metadata (hardware, OS, roles, services) |

### Ansible Inventory & Automation

| File | Purpose |
|------|---------|
| `ansible/inventory/hosts.yml` | **Updated:** Added akira to appropriate groups |
| `ansible/host_vars/akira.yml` | Akira-specific host variables (Tailscale, filesystem, GPU, etc.) |
| `ansible/playbooks/bootstrap-akira.yml` | **New:** Main bootstrap playbook (calls all roles) |
| `ansible/secrets-map.yml` | **Updated:** Added akira Tailscale + SMB credentials mapping |

### Ansible Roles (8 New Roles Created)

| Role | Purpose | Key Tasks |
|------|---------|-----------|
| `standardize_users` | Create `mdt` (automation) + `miket` (interactive) | User creation, sudo config, SSH dirs |
| `firewall_ufw` | UFW firewall (SSH tailnet-only) | Install UFW, deny incoming, allow Tailscale SSH |
| `nvidia_gpu_ubuntu` | NVIDIA drivers + CUDA toolkit | Auto-detect GPU, install drivers, verify `nvidia-smi` |
| `filesystem_layout_workstation` | Flux/Space/Time setup | Create local `~/flux`, mount remote `~/space` from motoko |
| `python_ai_stack` | Python + conda + AI libraries | Install Python 3.11/3.12, Miniforge, PyTorch, Transformers |
| `jupyter_server` | Jupyter Notebook configuration | Config Jupyter, bind to tailnet, set notebook dir |
| `workstation_base_ubuntu` | GNOME desktop + utilities | Install GNOME tweaks, fonts, base dev tools |
| `ssh_hardening_ubuntu` | SSH security hardening | Key-only auth, no root login, no passwords |

**Existing Roles Reused:**
- `common` (base system config)
- `common_dev_tools` (Git, gh, jq, tmux, etc.)
- `tailscale_node` (Tailscale installation and join)
- `podman_base` (Podman container runtime)
- `nvidia-container-toolkit` (GPU in containers, CDI)
- `netdata` (Netdata monitoring agent)
- `docker_prevention` (block Docker, enforce Podman)
- `workstation_gui_tools` (VS Code, Cursor, browsers)

---

## Quick Start Guide

### Prerequisites

1. **Physical access to akira** (for BIOS config and OS install)
2. **Ubuntu 24.04 LTS ISO** (download from ubuntu.com)
3. **Bootable USB drive** (8GB+)
4. **Ansible control node** (motoko, with `az` CLI and Azure login active)
5. **1Password access** (for credential recovery if needed)

### Step-by-Step Execution

#### 1. Pre-Ansible Manual Steps (~2 hours)

Follow **`docs/runbooks/AKIRA_BOOTSTRAP.md`** sections 1-5:

```bash
# a. Configure BIOS (UEFI, Secure Boot off, VT-x on, WoL on)
# b. Create bootable USB (from motoko or another Linux host):
sudo dd if=ubuntu-24.04-desktop-amd64.iso of=/dev/sdX bs=4M status=progress && sync

# c. Boot akira from USB, install Ubuntu 24.04 LTS
#    - Hostname: akira
#    - User: miket
#    - Partition: Linux-only layout (see runbook § 2)

# d. Post-install first boot (on akira console/SSH):
sudo apt update && sudo apt upgrade -y
sudo adduser mdt
echo "mdt ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/mdt
sudo systemctl enable --now ssh

# e. Copy SSH key from motoko:
ssh-copy-id mdt@<akira-local-ip>  # Get IP via `ip addr` on akira
```

#### 2. Run Ansible Bootstrap (~30-60 minutes)

From **motoko** (Ansible control node):

```bash
cd ~/dev/miket-infra-devices/ansible

# Test connectivity (use temp IP first)
ansible akira -i inventory/hosts.yml -m ping

# Run bootstrap playbook
ansible-playbook -i inventory/hosts.yml playbooks/bootstrap-akira.yml

# Playbook will:
# - Install Tailscale, join tailnet
# - Configure firewall (UFW)
# - Install GPU drivers + CUDA
# - Set up Podman with GPU support
# - Create Flux/Space/Time filesystem
# - Install Python AI stack
# - Configure Jupyter, Netdata
```

#### 3. Post-Bootstrap Verification (~10 minutes)

```bash
# Update inventory to use Tailscale hostname (edit hosts.yml):
#   ansible_host: akira.pangolin-vega.ts.net

# Test Tailscale connectivity
ssh mdt@akira.pangolin-vega.ts.net

# Verify GPU
ssh akira.pangolin-vega.ts.net "nvidia-smi"

# Verify Podman GPU
ssh akira.pangolin-vega.ts.net \
  "podman run --rm --device nvidia.com/gpu=all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi"

# Verify mounts
ssh akira.pangolin-vega.ts.net "ls -la ~/flux ~/space ~/time"

# Check Netdata (visit https://app.netdata.cloud)

# Test Python AI
ssh miket@akira.pangolin-vega.ts.net
source ~/miniforge3/bin/activate
conda activate ai-base
python -c "import torch; print(torch.cuda.is_available())"  # Should print: True
```

#### 4. Reboot & Final Check (~5 minutes)

```bash
ssh akira.pangolin-vega.ts.net "sudo reboot"
# Wait 2-3 minutes
ssh mdt@akira.pangolin-vega.ts.net
sudo systemctl status tailscaled
nvidia-smi
df -h | grep -E 'space|time'
```

**If all checks pass: Bootstrap COMPLETE! 🎉**

---

## Architecture Decisions

### Key Choices Made

| Decision | Rationale |
|----------|-----------|
| **Ubuntu 24.04 LTS** | LTS stability, NVIDIA driver support, wide compatibility |
| **Linux-only system** | Simplified setup, full disk for Linux |
| **LUKS encryption** | Data protection for `/home` and `/` |
| **Podman (not Docker)** | Rootless, daemonless, better security, GPU-ready |
| **Miniforge (not Anaconda)** | Faster, community-driven, better defaults |
| **uv package manager** | Rust-based, 10-100x faster than pip for installs |
| **UFW (not firewalld)** | Ubuntu native, simpler for workstation use |
| **SMB/CIFS mounts** | Tailscale-compatible, cross-platform, motoko already exports SMB |
| **Netdata Cloud** | Centralized monitoring, no local Prometheus needed |

### What's Different from Motoko

| Aspect | Motoko (Fedora 43) | Akira (Ubuntu 24.04) |
|--------|---------------------|----------------------|
| **OS** | Fedora Workstation (headless mode) | Ubuntu Desktop (GNOME, Wayland) |
| **Role** | Server + AI node (SoR for `/space`) | Workstation + AI dev (mounts `/space`) |
| **Boot** | Linux-only (UEFI) | Linux-only (UEFI) |
| **Firewall** | firewalld | UFW |
| **Desktop** | GNOME (disabled for headless) | GNOME (active, daily use) |
| **Storage** | Local `/space` (20TB USB) | Remote `/space` from motoko |
| **Services** | LiteLLM, Nextcloud, backups | Jupyter, dev tools (no services yet) |

---

## Secrets Reference

All secrets are in **Azure Key Vault** (`kv-miket-ops`). **Never** commit these to Git.

| Secret Name (AKV) | Purpose | Target File on Akira |
|-------------------|---------|----------------------|
| `akira-ansible-password` | Ansible connection (mdt user) | (runtime only, not written to disk) |
| `akira-tailscale-auth-key` | Tailscale node join (one-time) | `/etc/tailscale/auth.env` |
| `motoko-smb-username` | Mount `/space` and `/time` | `~/.mkt/smb-credentials` |
| `motoko-smb-password` | Mount `/space` and `/time` | `~/.mkt/smb-credentials` |
| `netdata-cloud-claim-token` | Netdata Cloud claim | `/flux/runtime/secrets/netdata.env` |
| `netdata-cloud-rooms` | Netdata Cloud room ID | `/flux/runtime/secrets/netdata.env` |

**Retrieve secrets (from motoko):**
```bash
az keyvault secret show --vault-name kv-miket-ops --name <secret-name> --query value -o tsv
```

---

## Filesystem Layout Quick Reference

```plaintext
/home/miket/
├── flux/                     # LOCAL (active work)
│   ├── projects/
│   ├── notebooks/
│   ├── models/
│   │   ├── huggingface/
│   │   └── torch/
│   └── runtime/
├── space/                    # REMOTE (motoko SoR, mounted via SMB)
│   └── [symlink to ~/.mkt/mounts/space]
├── time/                     # REMOTE (motoko backups, mounted via SMB)
│   └── [symlink to ~/.mkt/mounts/time]
└── .mkt/
    ├── mounts/
    │   ├── space/
    │   └── time/
    └── smb-credentials       # Mode 0600, from AKV
```

**SoR Invariant:** Akira is **NOT** the System of Record for `/space`. Motoko is. Akira mounts `/space` for convenience only.

---

## Ansible Inventory Groups (Akira Membership)

| Group | Purpose |
|-------|---------|
| `linux` | All Linux hosts |
| `linux_workstations` | Linux hosts with GUI (atom, **akira**) |
| `all_workstations` | All workstations (cross-OS) |
| `gpu_nodes` | Hosts with capable GPUs |
| `ai_nodes` | Hosts for AI workloads (motoko, wintermute, armitage, **akira**) |
| `container_hosts` | Hosts running containers (Podman/Docker) |
| `netdata_nodes` | Hosts with Netdata monitoring |
| `tailnet_all` | All hosts on the Tailscale tailnet |

---

## Troubleshooting

### Common Issues

| Problem | Solution |
|---------|----------|
| **NVIDIA drivers not loading** | Blacklist nouveau: `echo "blacklist nouveau" \| sudo tee /etc/modprobe.d/blacklist-nouveau.conf && sudo update-initramfs -u && sudo reboot` |
| **Tailscale won't connect** | Check auth key in AKV, run `sudo tailscale up --operator=mdt` |
| **Mounts not working** | Check SMB creds in `~/.mkt/smb-credentials`, test: `sudo mount -a` |
| **Podman can't access GPU** | Regenerate CDI: `sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml && sudo systemctl restart podman` |
| **Jupyter won't start** | Activate conda env: `source ~/miniforge3/bin/activate && conda activate ai-base` |

### Break-Glass Procedures

1. **Local login (if SSH broken):** Physical access, log in as `miket`
2. **1Password recovery:** All passwords in 1Password vault
3. **Live USB recovery:** Boot from Ubuntu USB to access/repair system

---

## Next Steps (After Phase 0)

### Immediate
- [ ] Install personal apps (Slack, Discord, etc.)
- [ ] Configure GNOME desktop (themes, extensions)
- [ ] Clone personal dotfiles to `~/flux/dotfiles`

### Short-Term
- [ ] Test AI/ML workflows (Jupyter, HuggingFace models)
- [ ] Create container-based dev environments
- [ ] Integrate with GitHub (SSH agent forwarding)

### Medium-Term
- [ ] Optional: Deploy vLLM (if GPU suitable)
- [ ] Optional: Join AI Fabric (register with LiteLLM proxy)

### Long-Term
- [ ] Optimize GNOME desktop performance
- [ ] Configure automated /home backups

---

## Success Criteria

✅ **Phase 0 is complete when:**

- [ ] SSH via Tailscale works (`akira.pangolin-vega.ts.net`)
- [ ] GPU functional (`nvidia-smi` shows GPU)
- [ ] Podman GPU works (container can run `nvidia-smi`)
- [ ] Mounts active (`~/flux` local, `~/space` and `~/time` from motoko)
- [ ] Python AI stack works (PyTorch CUDA available)
- [ ] Jupyter accessible (port 8888, tailnet-only)
- [ ] Netdata visible in Netdata Cloud
- [ ] System reboots cleanly (all services auto-start)

---

## Repository Commit Checklist

Before committing these changes to `miket-infra-devices`:

- [ ] Verify no secrets in Git (run `git grep -i "password\|secret\|key" | grep -v "\.md"`)
- [ ] Test bootstrap playbook in dry-run mode (`--check`)
- [ ] Lint YAML files (`yamllint ansible/`)
- [ ] Update `devices/inventory.yaml` if needed
- [ ] Tag commit: `git tag -a akira-phase0-v1.0 -m "Akira Phase 0 bootstrap implementation"`

**Commit Message:**
```
feat(akira): Add Phase 0 Linux bootstrap for AI/dev node

- Add akira to inventory (linux_workstations, ai_nodes, gpu_nodes)
- Create host_vars/akira.yml (Tailscale, filesystem, GPU config)
- Create bootstrap-akira.yml playbook
- Add 8 new roles: standardize_users, firewall_ufw, nvidia_gpu_ubuntu,
  filesystem_layout_workstation, python_ai_stack, jupyter_server,
  workstation_base_ubuntu, ssh_hardening_ubuntu
- Update secrets-map.yml for akira Tailscale + SMB credentials
- Add comprehensive docs: AKIRA_BOOTSTRAP.md (runbook),
  AKIRA_BOOTSTRAP_PLAN.md (architecture), AKIRA_BOOTSTRAP_SUMMARY.md
- Add devices/akira/config.yml (device metadata)

Akira is a Linux-only Ubuntu 24.04 workstation + AI dev node.
Phase 0 scope: base Linux setup, GPU drivers, Python AI stack,
Flux/Space/Time filesystem, Tailscale join, no workloads migrated yet.

Motoko remains SoR for /space. Akira mounts /space remotely via SMB.

Closes: #<issue-number> (if tracked)
```

---

## Contact & Support

| Resource | Location |
|----------|----------|
| **Main Runbook** | `docs/runbooks/AKIRA_BOOTSTRAP.md` |
| **Architecture Doc** | `docs/architecture/AKIRA_BOOTSTRAP_PLAN.md` |
| **Bootstrap Playbook** | `ansible/playbooks/bootstrap-akira.yml` |
| **Device Config** | `devices/akira/config.yml` |
| **Host Vars** | `ansible/host_vars/akira.yml` |
| **Secrets Map** | `ansible/secrets-map.yml` |

**Questions?** Refer to the architecture docs or runbook. All design decisions are documented with rationale.

---

**Status:** READY FOR EXECUTION  
**Estimated Total Time:** 3-4 hours (includes manual steps + Ansible + verification)  
**Last Updated:** 2025-12-04

---

**Go forth and bootstrap! 🚀**

