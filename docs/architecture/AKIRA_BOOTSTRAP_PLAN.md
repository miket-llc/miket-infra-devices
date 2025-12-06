# Akira Bootstrap Plan (Linux Side) - Phase 0 / v1.0

**Status:** READY FOR IMPLEMENTATION • **Version:** 1.0  
**Target Device:** akira (Linux AI/dev node)  
**Date:** 2025-12-04

---

## Executive Summary

This document outlines the **Phase 0 / v1.0 bootstrap** strategy for akira, a new Linux host joining the MikeT PHC infrastructure. Akira will function as:

1. **Primary Linux workstation** for Mike (daily development, AI/ML experimentation)
2. **AI/dev node** on the tailnet (GPU-accelerated, future inference workloads)

**Key Architectural Constraints Respected:**
- ✅ IaC/CaC first (all config in Git via Ansible)
- ✅ Secrets from Azure Key Vault only (never in Git)
- ✅ Tailnet-first networking (Tailscale + MagicDNS)
- ✅ Flux/Space/Time filesystem ontology preserved
- ✅ Motoko remains SoR for `/space` (akira mounts remotely)
- ✅ No production workloads migrated (akira is greenfield in Phase 0)

---

## Goals & Non-Goals

### ✅ In Scope (Phase 0)

| Area | Deliverable |
|------|-------------|
| **OS Install** | Ubuntu 24.04 LTS (GNOME, Wayland), Linux-only system |
| **Users** | `mdt` (automation, passwordless sudo) + `miket` (interactive) |
| **Networking** | Tailscale node joined to `pangolin-vega.ts.net`, MagicDNS enabled |
| **Security** | UFW firewall (SSH tailnet-only), key-only SSH, no root login |
| **Filesystem** | Flux/Space/Time layout: local `~/flux`, remote `~/space` from motoko |
| **GPU** | NVIDIA drivers + CUDA 12.x, GPU verified and functional |
| **Containers** | Podman with NVIDIA CDI (GPU in containers), no Docker |
| **AI/Dev** | Python 3.11/3.12, uv, Miniforge, PyTorch, Transformers, Jupyter |
| **Monitoring** | Netdata agent claimed to Netdata Cloud (Homelab) |
| **Inventory** | Akira added to Ansible inventory, host_vars, device config |

### ❌ Out of Scope (Future Phases)

| Area | Rationale |
|------|-----------|
| **Workload Migration** | No services moved from motoko (Nextcloud, restic, etc.) |
| **SoR Promotion** | Motoko remains canonical `/space` SoR |
| **vLLM Deployment** | AI stack ready, but no production inference containers yet |
| **Service Replacement** | Akira does not replace motoko as anchor/primary node |

---

## Architecture Overview

### High-Level Topology

```plaintext
┌─────────────────────────────────────────────────────────────────┐
│ MikeT PHC Tailnet (pangolin-vega.ts.net)                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐         ┌──────────────┐                     │
│  │   motoko     │◄────────┤    akira     │                     │
│  │ (Fedora 43)  │  SMB    │ (Ubuntu 24.04)│                    │
│  │              │  /space │              │                     │
│  │ - SoR: /space│  /time  │ - Workstation│                     │
│  │ - LiteLLM    │         │ - AI/dev node│                     │
│  │ - Nextcloud  │         │ - GPU (TBD)  │                     │
│  │ - Backups    │         │ - Linux-only │                     │
│  └──────────────┘         └──────────────┘                     │
│                                                                 │
│  Other nodes: wintermute, armitage, atom, count-zero           │
└─────────────────────────────────────────────────────────────────┘
```

### Role Assignment

| Role | Description | Ansible Groups |
|------|-------------|----------------|
| `workstation` | Interactive Linux desktop (GNOME) | `linux_workstations`, `all_workstations` |
| `ai_node` | GPU-capable AI/ML development | `ai_nodes`, `gpu_nodes` |
| `gpu_node` | NVIDIA GPU available | `gpu_nodes` |
| `dev_node` | Development tooling (Python, Git, IDEs) | (implied via roles) |
| `container_host` | Runs Podman containers | `container_hosts` |
| `netdata_node` | Netdata monitoring agent | `netdata_nodes` |

---

## Linux-Only Partitioning Strategy

### Recommended Disk Layout (1TB NVMe Example)

| Partition | Size | Type | Mount Point | Purpose |
|-----------|------|------|-------------|---------|
| `/dev/nvme0n1p1` | 512 MB | EFI (FAT32) | `/boot/efi` | EFI System Partition for GRUB |
| `/dev/nvme0n1p2` | 16 GB | swap | `swap` | Linux swap space |
| `/dev/nvme0n1p3` | 100 GB | ext4 (LUKS) | `/` | Linux root (encrypted) |
| `/dev/nvme0n1p4` | ~883 GB | ext4 (LUKS) | `/home` | Linux home (encrypted) |

**Key Points:**
- Simple 4-partition layout for Linux-only system
- LUKS encryption on root and home partitions for data protection
- Swap size: 16GB (adjust based on RAM; 16-32GB for hibernation support)
- Root size: 100GB (sufficient for OS + packages)
- Home: Remaining space for user data, projects, flux workspace

---

## Security & Identity

### Account Architecture

| User | Purpose | Sudo | Auth Method | Shell |
|------|---------|------|-------------|-------|
| `mdt` | Automation (Ansible, systemd services) | `NOPASSWD:ALL` | SSH keys (from motoko) | `/bin/bash` |
| `miket` | Interactive daily use (Mike) | Password required | Local password + SSH keys | `/bin/bash` |

**Rationale:**
- `mdt` is the automation surface; all Ansible playbooks connect as `mdt`
- `miket` is for daily interactive work; not used by automation
- Passwords stored in AKV (`akira-ansible-password` for mdt)

### Tailscale Integration

- **Node Name:** `akira.pangolin-vega.ts.net`
- **Auth Method:** Entra ID (via Tailscale OAuth)
- **Auth Key:** Retrieved from AKV (`akira-tailscale-auth-key`) for initial join
- **Tags:** `tag:workstation`, `tag:linux`, `tag:ai_node`, `tag:gpu_node`, `tag:ansible`
- **MagicDNS:** Enabled (hostname resolution for `motoko.pangolin-vega.ts.net`)

### Firewall (UFW)

| Service | Port | Source | Policy |
|---------|------|--------|--------|
| SSH | 22/tcp | `100.64.0.0/10` (Tailscale) | ALLOW |
| Jupyter | 8888/tcp | `100.64.0.0/10` | ALLOW |
| Netdata | 19999/tcp | `100.64.0.0/10` | ALLOW |
| **Default** | All other | Any | DENY (incoming) |

**Security Model:**
- Two-layer security: Tailscale ACLs + host firewall
- Public internet traffic blocked by default (UFW deny incoming)
- Admin access (SSH, Jupyter, Netdata) only via Tailscale IPs
- Outbound traffic allowed (for updates, package downloads, etc.)

---

## Filesystem Topology on Akira

### Flux / Space / Time Layout

```plaintext
akira:~$ tree -L 2 -d ~/
/home/miket/
├── flux/                  # LOCAL (ext4, on /home partition)
│   ├── projects/          # Active code projects
│   ├── notebooks/         # Jupyter notebooks
│   ├── models/            # AI model cache (HuggingFace, Torch Hub)
│   │   ├── huggingface/
│   │   └── torch/
│   ├── runtime/           # Runtime state, logs
│   └── tmp/               # Temp workspace
│
├── space/                 # REMOTE MOUNT (CIFS from motoko)
│   └── [motoko:/space via SMB]
│       ├── devices/       # Device-specific data
│       ├── archives/      # Long-term archives
│       ├── media/         # Media library
│       └── ...            # (SoR on motoko)
│
├── time/                  # REMOTE MOUNT (CIFS from motoko)
│   └── [motoko:/time via SMB]
│       ├── backups/       # Restic snapshots
│       └── ...            # Time Machine-style backups
│
└── .mkt/                  # Implementation paths (hidden)
    ├── mounts/
    │   ├── space/         # Actual CIFS mount point
    │   └── time/          # Actual CIFS mount point
    └── smb-credentials    # SMB creds from AKV (mode 0600)
```

### Implementation Details

| Path | Type | Backing | Owner | Persistent |
|------|------|---------|-------|------------|
| `~/flux` | Directory | Local ext4 (`/home/miket/flux`) | `miket:miket` | ✅ Yes |
| `~/space` | Symlink | `~/.mkt/mounts/space` → `//motoko/space` (CIFS) | `miket:miket` | ✅ Yes (via `/etc/fstab`) |
| `~/time` | Symlink | `~/.mkt/mounts/time` → `//motoko/time` (CIFS) | `miket:miket` | ✅ Yes (via `/etc/fstab`) |

**`/etc/fstab` Entries:**
```fstab
# Space mount (SoR on motoko)
//motoko.pangolin-vega.ts.net/space /home/miket/.mkt/mounts/space cifs credentials=/home/miket/.mkt/smb-credentials,uid=miket,gid=miket,iocharset=utf8,vers=3.0,nofail 0 0

# Time mount (backups on motoko, read-only)
//motoko.pangolin-vega.ts.net/time /home/miket/.mkt/mounts/time cifs credentials=/home/miket/.mkt/smb-credentials,uid=miket,gid=miket,iocharset=utf8,vers=3.0,nofail,ro 0 0
```

**Credentials File (`~/.mkt/smb-credentials`):**
- Format: `username=<from AKV>\npassword=<from AKV>\ndomain=WORKGROUP`
- Permissions: `0600` (owner-read-only)
- Source: AKV secrets `motoko-smb-username`, `motoko-smb-password`

### SoR Invariant

**Critical:** Akira does **NOT** become the System of Record for `/space`. Motoko remains the canonical SoR. Akira mounts `/space` read-write for convenience, but:

- No backups run **from** akira to B2
- No data ingestion **to** akira's `/space` (ingestion still targets motoko)
- If akira is unavailable, Mike accesses `/space` via motoko or other nodes

This preserves the PHC architecture and prevents split-brain scenarios.

---

## AI / Dev Environment Setup

### GPU Stack

| Component | Version / Details |
|-----------|-------------------|
| **GPU** | NVIDIA (model TBD after hardware inspection) |
| **Driver** | Latest NVIDIA proprietary (via `nvidia-driver-latest` meta-package) |
| **CUDA** | CUDA Toolkit 12.6 (latest stable CUDA 12.x) |
| **Verification** | `nvidia-smi`, `nvcc --version` |
| **Container GPU** | NVIDIA Container Toolkit + CDI (Container Device Interface) |

**Installation Flow:**
1. Auto-detect NVIDIA GPU via `lspci`
2. Add graphics-drivers PPA (Ubuntu)
3. Blacklist `nouveau` driver
4. Install `nvidia-driver-latest`, `nvidia-cuda-toolkit`
5. Update initramfs, reboot to load drivers
6. Install `nvidia-container-toolkit`, generate CDI config
7. Verify GPU in Podman: `podman run --device nvidia.com/gpu=all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi`

### Container Runtime (Podman)

| Aspect | Configuration |
|--------|---------------|
| **Runtime** | Podman (rootless, user `miket`) |
| **Storage** | `~/.local/share/containers/storage` (graphroot) |
| **GPU Support** | NVIDIA CDI enabled, `--device nvidia.com/gpu=all` flag |
| **Compose** | Podman Compose (if needed for multi-container dev environments) |
| **Registry** | Docker Hub, ghcr.io, quay.io (no private registry needed yet) |
| **Linger** | Enabled for `miket` (user services persist after logout) |

**Why Podman, not Docker:**
- Rootless by design (better security)
- Compatible with Docker CLI/Compose (drop-in replacement)
- No daemon (each container is a systemd service)
- Enforced via `docker_prevention` role (blocks accidental Docker install)

### Python Toolchain

| Tool | Purpose | Installation |
|------|---------|--------------|
| **Python 3.11** | Default Python for Ubuntu 24.04 | System package (`python3.11`) |
| **Python 3.12** | Latest stable Python | System package (`python3.12`) |
| **uv** | Fast Rust-based package installer | `curl https://astral.sh/uv/install.sh` |
| **pipx** | Isolated CLI tool installation | System package (`pipx`) |
| **Miniforge** | Community conda distribution | Shell installer → `~/miniforge3` |

**Conda Base Environment (`ai-base`):**
- Python 3.11
- PyTorch (with CUDA 12.1 support)
- Transformers (HuggingFace)
- Datasets, Accelerate, PEFT
- Jupyter Notebook/Lab + IPython kernel
- Pandas, NumPy, Scikit-learn, Matplotlib, Seaborn, Plotly

**Environment Variables (added to `~/.bashrc`):**
```bash
export HF_HOME=~/flux/models/huggingface
export TORCH_HOME=~/flux/models/torch
export TRANSFORMERS_CACHE=~/flux/models/huggingface/transformers
export PATH="$HOME/.cargo/bin:$PATH"  # For uv
```

### Jupyter Configuration

| Setting | Value |
|---------|-------|
| **Port** | 8888 |
| **Bind Address** | `0.0.0.0` (UFW restricts to Tailscale) |
| **Notebook Dir** | `~/flux/notebooks` |
| **Auth** | Token-based (password optional) |
| **Access URL** | `http://akira.pangolin-vega.ts.net:8888` |

**Starting Jupyter (manual):**
```bash
ssh miket@akira.pangolin-vega.ts.net
source ~/miniforge3/bin/activate
conda activate ai-base
jupyter notebook
# Copy token from output, access via Tailscale URL
```

---

## Ansible Integration

### Repository Changes

All changes are in `miket-infra-devices` repository:

```plaintext
miket-infra-devices/
├── ansible/
│   ├── inventory/
│   │   └── hosts.yml                  # ✅ Added akira to groups
│   ├── host_vars/
│   │   └── akira.yml                  # ✅ New: akira host vars
│   ├── playbooks/
│   │   └── bootstrap-akira.yml        # ✅ New: Phase 0 bootstrap playbook
│   ├── roles/
│   │   ├── standardize_users/         # ✅ New: mdt + miket account creation
│   │   ├── firewall_ufw/              # ✅ New: UFW tailnet-only firewall
│   │   ├── nvidia_gpu_ubuntu/         # ✅ New: NVIDIA drivers + CUDA
│   │   ├── filesystem_layout_workstation/ # ✅ New: Flux/Space/Time setup
│   │   ├── python_ai_stack/           # ✅ New: Python + conda + AI libs
│   │   ├── jupyter_server/            # ✅ New: Jupyter configuration
│   │   ├── workstation_base_ubuntu/   # ✅ New: GNOME + utilities
│   │   └── ssh_hardening_ubuntu/      # ✅ New: SSH key-only, no root
│   └── secrets-map.yml                # ✅ Updated: akira Tailscale + SMB creds
├── devices/
│   └── akira/
│       └── config.yml                 # ✅ New: akira device metadata
└── docs/
    ├── runbooks/
    │   └── AKIRA_BOOTSTRAP.md         # ✅ New: Manual steps runbook
    └── architecture/
        └── AKIRA_BOOTSTRAP_PLAN.md    # ✅ New: This document
```

### Inventory Groups

Akira is a member of these groups:

| Group | Purpose |
|-------|---------|
| `linux` | All Linux hosts |
| `linux_workstations` | Linux hosts with GUI |
| `all_workstations` | All workstations (cross-OS) |
| `gpu_nodes` | Hosts with capable GPUs |
| `ai_nodes` | Hosts for AI workloads |
| `container_hosts` | Hosts running containers |
| `netdata_nodes` | Hosts with Netdata monitoring |
| `tailnet_all` | All hosts on the Tailscale tailnet |

### Secrets Architecture

| Secret | AKV Name | Target Path | Owner | Usage |
|--------|----------|-------------|-------|-------|
| Ansible Password (mdt) | `akira-ansible-password` | (runtime only) | - | Ansible connection auth |
| Tailscale Auth Key | `akira-tailscale-auth-key` | `/etc/tailscale/auth.env` | `root:root` | Tailscale join (one-time) |
| SMB Username | `motoko-smb-username` | `~/.mkt/smb-credentials` | `miket:miket` | Mount `/space`, `/time` |
| SMB Password | `motoko-smb-password` | `~/.mkt/smb-credentials` | `miket:miket` | Mount `/space`, `/time` |
| Netdata Claim Token | `netdata-cloud-claim-token` | `/flux/runtime/secrets/netdata.env` | `root:root` | Netdata Cloud claim |
| Netdata Rooms ID | `netdata-cloud-rooms` | `/flux/runtime/secrets/netdata.env` | `root:root` | Netdata Cloud room |

**Secret Flow:**
1. Secrets stored in Azure Key Vault (`kv-miket-ops`)
2. Ansible playbooks retrieve via `az keyvault secret show` (requires `az login` on control node)
3. Secrets written to local `.env` or credential files (mode `0600`)
4. Services read from local files (never from AKV directly)
5. Secrets **never** committed to Git

---

## Bootstrap Execution Plan

### Phase 0: Manual Steps (Pre-Ansible)

**Duration:** ~2 hours

1. **BIOS Configuration** (see `AKIRA_BOOTSTRAP.md` § 1)
   - UEFI mode, Secure Boot disabled, Wake-on-LAN enabled, VT-x/VT-d enabled

2. **Ubuntu 24.04 LTS Installation** (see `AKIRA_BOOTSTRAP.md` § 2-3)
   - Download ISO, create bootable USB
   - Boot from USB, select "Install Ubuntu"
   - Partition disk (Linux-only layout from plan above)
   - Create initial user (`miket`), set hostname (`akira`)
   - Install GRUB to ESP, complete installation, reboot

3. **Post-Install First Boot** (see `AKIRA_BOOTSTRAP.md` § 4)
   - Update packages: `sudo apt update && sudo apt upgrade -y`
   - Create `mdt` user: `sudo adduser mdt && sudo usermod -aG sudo mdt`
   - Configure passwordless sudo: `echo "mdt ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/mdt`
   - Enable SSH: `sudo systemctl enable --now ssh`
   - Copy SSH key from motoko: `ssh-copy-id mdt@<akira-temp-ip>`

4. **Add Akira to Inventory (Temporary)**
   - Edit `ansible/inventory/hosts.yml` on motoko
   - Add temp entry: `ansible_host: <akira-local-ip>`
   - Test: `ansible akira -i inventory/hosts.yml -m ping`

### Phase 1: Ansible Bootstrap (Automated)

**Duration:** ~30-60 minutes (depends on downloads)

```bash
# From motoko (Ansible control node)
cd ~/dev/miket-infra-devices/ansible

# Run Phase 0 bootstrap playbook
ansible-playbook -i inventory/hosts.yml playbooks/bootstrap-akira.yml
```

**Playbook Execution Flow:**

| Phase | Role | Tasks | Duration |
|-------|------|-------|----------|
| 1 | `common` | Base system config | ~2 min |
| 1 | `standardize_users` | Create `mdt`, `miket`, configure sudo | ~1 min |
| 1 | `tailscale_node` | Install Tailscale, join tailnet | ~3 min |
| 1 | `firewall_ufw` | Configure UFW (SSH tailnet-only) | ~1 min |
| 2 | `workstation_base_ubuntu` | Install GNOME tools, fonts, utilities | ~5 min |
| 2 | `workstation_gui_tools` | VS Code, Cursor, browsers | ~10 min |
| 2 | `common_dev_tools` | Git, gh, jq, tmux, etc. | ~3 min |
| 3 | `nvidia_gpu_ubuntu` | NVIDIA drivers + CUDA | ~15 min |
| 3 | `nvidia-container-toolkit` | GPU in containers (CDI) | ~3 min |
| 3 | `podman_base` | Install Podman, configure storage | ~5 min |
| 4 | `filesystem_layout_workstation` | Create Flux/Space/Time, mount SMB | ~5 min |
| 5 | `python_ai_stack` | Python, conda, PyTorch, Jupyter | ~20 min |
| 5 | `jupyter_server` | Jupyter config | ~1 min |
| 6 | `netdata` | Install Netdata, claim to Cloud | ~5 min |
| 7 | `docker_prevention` | Block Docker installation | ~1 min |
| 7 | `ssh_hardening_ubuntu` | SSH key-only, no root login | ~1 min |

**Total Estimated Time:** 30-60 minutes (network-dependent)

### Phase 2: Post-Ansible Verification

**Duration:** ~10 minutes

```bash
# Update inventory to use Tailscale hostname (remove temp IP)
# Edit ansible/inventory/hosts.yml:
#   ansible_host: akira.pangolin-vega.ts.net

# Test Tailscale connectivity
ssh mdt@akira.pangolin-vega.ts.net

# Verify GPU
ssh akira.pangolin-vega.ts.net "nvidia-smi"

# Verify Podman GPU
ssh akira.pangolin-vega.ts.net "podman run --rm --device nvidia.com/gpu=all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi"

# Verify mounts
ssh akira.pangolin-vega.ts.net "ls -la ~/flux ~/space ~/time && df -h | grep -E 'flux|space|time'"

# Check Netdata (should appear in Netdata Cloud within ~5 min)
# Visit https://app.netdata.cloud -> PHC space -> Nodes

# Test Python AI stack
ssh miket@akira.pangolin-vega.ts.net
source ~/miniforge3/bin/activate
conda activate ai-base
python -c "import torch; print(f'PyTorch: {torch.__version__}, CUDA: {torch.cuda.is_available()}')"
```

**Expected Results:**
- ✅ SSH via Tailscale works
- ✅ `nvidia-smi` shows GPU and driver version
- ✅ Podman can access GPU (nvidia-smi in container succeeds)
- ✅ `~/flux` exists (local), `~/space` and `~/time` mounted from motoko
- ✅ Netdata visible in Netdata Cloud
- ✅ PyTorch reports CUDA available

### Phase 3: Reboot & Final Check

**Duration:** ~5 minutes

```bash
# Reboot to ensure:
# - NVIDIA drivers load automatically
# - Tailscale starts on boot
# - SMB mounts reconnect (via /etc/fstab)
# - UFW is active

ssh akira.pangolin-vega.ts.net "sudo reboot"

# Wait 2-3 minutes, then reconnect
ssh mdt@akira.pangolin-vega.ts.net

# Final checks
sudo systemctl status tailscaled
sudo ufw status verbose
nvidia-smi
df -h | grep -E 'space|time'
```

**If all checks pass: Phase 0 bootstrap is COMPLETE. 🎉**

---

## Next Steps (Post-Phase 0)

### Immediate (User Personalization)

1. **Install Personal Applications (as `miket`)**
   - Firefox, Chrome, Slack, Discord, etc.
   - VS Code extensions, Cursor IDE config
   - GNOME desktop settings (themes, extensions, keybindings)

2. **Set Up Dotfiles**
   - Clone personal dotfiles repo to `~/flux/dotfiles`
   - Symlink `.bashrc`, `.vimrc`, `.gitconfig`, etc.

3. **Configure GNOME**
   - Wallpaper, display scaling (if HiDPI)
   - Keyboard shortcuts, workspaces
   - Install GNOME extensions (Dash to Dock, etc.)

### Short-Term (AI/Dev Workflows)

4. **Test AI/ML Workflows**
   - Run sample Jupyter notebook (MNIST, transformer demo)
   - Download a small HuggingFace model, verify caching
   - Test GPU utilization: `watch -n 1 nvidia-smi`

5. **Explore Container-Based Dev Environments**
   - Create dev containers for projects (Python, Node, etc.)
   - Use Podman Compose for multi-container stacks

6. **Integrate with Existing Workflows**
   - Clone repos from GitHub to `~/flux/projects`
   - Set up SSH agent forwarding (for Git push from akira)

### Medium-Term (AI Fabric Integration)

7. **Optional: Deploy vLLM (if GPU suitable)**
   - Choose a lightweight model (e.g., `mistralai/Mistral-7B-AWQ`)
   - Run vLLM container, expose on port 8001 (tailnet-only)
   - Register with LiteLLM proxy on motoko (add to `litellm.config.yaml`)

8. **Optional: Join as AI Fabric Node**
   - Assign AI role in inventory (e.g., `ai_node_roles: [dev-experimentation]`)
   - Coordinate with motoko for LLM routing
   - Monitor GPU utilization via Netdata

### Long-Term (System Optimization)

9. **Workstation Refinement**
   - Fine-tune GNOME desktop performance and UX
   - Configure automated backups of `/home` to motoko
   - Set up power management and suspend/hibernation
   - Desktop application optimization

---

## Rollback & Recovery

### If Bootstrap Fails

| Failure Point | Rollback Action |
|---------------|-----------------|
| **OS install corrupted** | Re-install Ubuntu (partitions preserved if possible) |
| **Ansible playbook fails** | Fix error, re-run playbook (idempotent) |
| **GPU drivers broken** | Boot into recovery mode, purge nvidia packages, re-run role |
| **Mounts not working** | Check SMB credentials, test manual mount, fix `/etc/fstab` |
| **Tailscale won't join** | Revoke old key in Tailscale admin, generate new auth key |

### Break-Glass Procedures

1. **Local Login (if SSH broken)**
   - Physical access to akira
   - Log in as `miket` (local password)
   - Debug networking: `ip addr`, `ping`, `tailscale status`

2. **1Password Recovery**
   - All critical passwords in 1Password vault
   - `akira` / `miket` password (LUKS + login)
   - AKV access via personal Microsoft account

---

## Success Criteria

Phase 0 bootstrap is considered **successful** when:

- [ ] Akira joins Tailscale tailnet at `akira.pangolin-vega.ts.net`
- [ ] SSH accessible via Tailscale only (UFW blocks non-Tailscale)
- [ ] `mdt` and `miket` users configured correctly
- [ ] NVIDIA GPU detected and `nvidia-smi` works
- [ ] Podman can run GPU-accelerated containers
- [ ] `~/flux` is local, `~/space` and `~/time` mount from motoko
- [ ] Python AI stack functional (PyTorch CUDA available)
- [ ] Jupyter accessible via `http://akira.pangolin-vega.ts.net:8888`
- [ ] Netdata agent appears in Netdata Cloud (PHC space)
- [ ] Akira reboots cleanly (drivers, mounts, Tailscale all auto-start)

**When all criteria met:** Akira is ready for daily use as Mike's primary Linux workstation and AI dev node. 🚀

---

## Document Metadata

| Field | Value |
|-------|-------|
| **Status** | READY FOR IMPLEMENTATION |
| **Version** | 1.0 |
| **Author** | PHC Infrastructure Team |
| **Date** | 2025-12-04 |
| **Repository** | `miket-infra-devices` |
| **Playbook** | `ansible/playbooks/bootstrap-akira.yml` |
| **Runbook** | `docs/runbooks/AKIRA_BOOTSTRAP.md` |
| **Next Review** | After Phase 0 completion |

---

**End of Document**

