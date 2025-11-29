# Motoko: Ubuntu 24.04 → Fedora 43 Migration

**Date:** 2025-11-29  
**Purpose:** Migrate motoko from Ubuntu 24.04 LTS to Fedora 43 (GNOME X11)  
**Method:** GRUB loopback (no USB), minimal manual steps, Ansible-driven restoration  
**Status:** Ready for execution

---

## Migration Strategy

### What We Keep
- **GRUB loopback** → Boot Fedora ISO from disk (no USB required)
- **Data partitions** → `/space`, `/flux`, `/time` untouched
- **Selected /home data** → SSH keys, Obsidian, code, docs (NOT desktop configs)
- **Ansible-driven** → Use `miket-infra-devices` to re-hydrate all services

### What We Change
- **OS**: Ubuntu 24.04 → Fedora 43 Workstation
- **Desktop**: KDE Plasma → GNOME (on X11, not Wayland)
- **Config approach**: No `/etc` restoration, only Ansible-managed templates
- **Package manager**: `apt` → `dnf`

### What We DON'T Preserve
- Desktop environment configs (KDE/GNOME cache, state)
- Ubuntu-specific `/etc` configurations
- System packages (rebuild via Ansible)
- Desktop runtime state

---

## PHC Context Boilerplate

```yaml
# Use this context for all prompts during migration
repositories:
  - miket-infra: Terraform/Terragrunt for Entra, Cloudflare, storage, PHC services
  - miket-infra-devices: Ansible for motoko, wintermute, armitage, count-zero

invariants:
  storage:
    - /space = System of Record (SoR)
    - /flux = runtime surface (apps, DBs, models, caches)
    - /time = Time Machine target
    - motoko = fileserver (SMB: \\motoko\space, \\motoko\flux, \\motoko\time)
  
  identity:
    - Entra ID = only IdP for humans, devices, Cloudflare Access
    - Tailscale = private mesh + SSH
    - AKV = secrets SoR (not 1Password for automation)
  
  ai_fabric:
    - LiteLLM on motoko = single OpenAI-compatible gateway
    - Federates vLLM GPU nodes + cloud LLMs

current_state:
  hostname: motoko
  os: Ubuntu 24.04 LTS
  desktop: KDE Plasma on X11
  gpu: NVIDIA RTX 2080 (driver 535, CUDA 12.2)
  services:
    - Docker + NVIDIA runtime
    - vLLM reasoning (port 8001)
    - vLLM embeddings (port 8200)
    - LiteLLM proxy (port 8000)
    - Samba, Netatalk, NoMachine, fail2ban, postfix
```

---

## Migration Stages

| Stage | Location | Connection | Manual/Auto | Duration |
|-------|----------|------------|-------------|----------|
| **Stage 1** | motoko (Ubuntu) | SSH from count-zero | Automated | 30 min |
| **Stage 2** | motoko (Fedora installer) | Local console | Manual | 45 min |
| **Stage 3** | motoko (Fedora) | Local console | Manual | 15 min |
| **Stage 4** | motoko (Fedora) | SSH from count-zero | Automated | 60 min |

---

## STAGE 1: Pre-Migration Backup & ISO Preparation (Ubuntu, via SSH)

### Context
You are SSH'd into motoko from count-zero. Motoko is running Ubuntu 24.04. You will:
1. Back up critical data to `/space`
2. Download Fedora 43 ISO to `/flux`
3. Configure GRUB loopback entry
4. Reboot (SSH connection will be lost)

### Agent Prompt for Stage 1

```
You are working on motoko (Ubuntu 24.04) via SSH from count-zero.

TASK: Prepare motoko for migration to Fedora 43.

CONTEXT:
- Repository: ~/miket-infra-devices (git controlled)
- Storage: /space (20TB, SoR), /flux (runtime), /time (Time Machine)
- Services: Docker, vLLM, LiteLLM, Samba, NoMachine, Tailscale
- PHC invariants: /space = SoR, Ansible = config source of truth

STEPS:
1. Run backup script: ~/miket-infra-devices/scripts/motoko-pre-migration-backup.sh
2. Download Fedora 43 Workstation ISO to /flux/iso/
3. Verify ISO checksum
4. Configure GRUB loopback entry in /etc/grub.d/40_custom
5. Update GRUB config
6. Display next steps and reboot instructions

CRITICAL:
- Do NOT reboot automatically - let user confirm
- After reboot, SSH will be unavailable until Stage 3 complete
- Create Stage 2 prompt before finishing

DELIVERABLES:
- Backup at /space/motoko-backup/
- ISO at /flux/iso/Fedora-Workstation-Live-x86_64-43-*.iso
- GRUB entry configured
- Stage 2 prompt ready
```

### Commands

```bash
# 1. Create backup
~/miket-infra-devices/scripts/motoko-pre-migration-backup.sh

# 2. Download Fedora 43 ISO
cd /tmp
wget https://download.fedoraproject.org/pub/fedora/linux/releases/43/Workstation/x86_64/iso/Fedora-Workstation-Live-x86_64-43-1.6.iso
wget https://download.fedoraproject.org/pub/fedora/linux/releases/43/Workstation/x86_64/iso/Fedora-Workstation-43-1.6-x86_64-CHECKSUM

# Verify checksum
sha256sum -c Fedora-Workstation-43-1.6-x86_64-CHECKSUM --ignore-missing

# Move to /flux
sudo mkdir -p /flux/iso
sudo mv Fedora-Workstation-Live-x86_64-43-1.6.iso /flux/iso/
sudo chmod 644 /flux/iso/Fedora-Workstation-Live-x86_64-43-1.6.iso

# 3. Find /flux partition
lsblk -f | grep flux
# Note the partition (e.g., sdb2)

# 4. Configure GRUB loopback
sudo cp /etc/grub.d/40_custom /etc/grub.d/40_custom.backup

sudo tee -a /etc/grub.d/40_custom << 'EOF'

menuentry "Fedora 43 Workstation Live (Install)" {
    set isofile="/flux/iso/Fedora-Workstation-Live-x86_64-43-1.6.iso"
    loopback loop (hd0,gpt2)$isofile
    linux (loop)/isolinux/vmlinuz root=live:CDLABEL=Fedora-WS-Live-43-1-6 rd.live.image quiet
    initrd (loop)/isolinux/initrd.img
}
EOF

# 5. Update GRUB
sudo update-grub

# 6. Verify backup
ls -lh /space/motoko-backup/migration-*/
df -h | grep -E '(space|flux|time)'

echo ""
echo "=============================================="
echo "STAGE 1 COMPLETE - READY FOR REBOOT"
echo "=============================================="
echo ""
echo "Next steps:"
echo "1. Reboot: sudo reboot"
echo "2. At GRUB menu, select: Fedora 43 Workstation Live (Install)"
echo "3. Proceed to STAGE 2 (manual installation)"
echo ""
echo "WARNING: SSH will be unavailable until Stage 3 complete"
echo ""
```

### Stage 1 Complete Checklist
- [ ] Backup created at `/space/motoko-backup/migration-*/`
- [ ] Fedora 43 ISO at `/flux/iso/`
- [ ] GRUB entry configured
- [ ] Partition layout documented (`lsblk` output saved)
- [ ] Ready to reboot

---

## STAGE 2: Fedora Installation (Local Console, Manual)

### Context
You are at the motoko physical console. The system has booted from Fedora 43 Live ISO via GRUB loopback.

### Agent Prompt for Stage 2

```
You are performing a manual Fedora 43 installation on motoko.

TASK: Install Fedora 43 Workstation with correct partitioning.

CONTEXT (from Stage 1):
- Backup at /space/motoko-backup/
- Data partitions: /space, /flux, /time (DO NOT FORMAT)
- User: mdt (will be recreated)
- Desktop: GNOME on X11 (not Wayland)

INSTALLATION CHOICES:

1. Boot from GRUB entry "Fedora 43 Workstation Live (Install)"
2. Launch "Install to Hard Drive"

3. SOFTWARE SELECTION:
   - Fedora Workstation (GNOME)
   - Select "Install Third-Party Software" (for NVIDIA)

4. INSTALLATION DESTINATION (CRITICAL):
   - Select "Custom" partitioning
   
   FORMAT these partitions:
   - / (root) → ext4 or btrfs, ~50GB minimum
   - /boot → ext4, ~1GB
   - /boot/efi → EFI, ~512MB
   - swap → if separate partition
   
   DO NOT FORMAT (mount only):
   - /home → mount existing partition (if separate)
   - /space → mount existing partition
   - /flux → mount existing partition
   - /time → mount existing partition (read-only)

5. USER CREATION:
   - Username: mdt
   - Check "Make this user administrator"
   - Set password (remember it!)
   - Optional: Match UID/GID from backup (see /space/motoko-backup/etc/passwd)

6. NETWORK:
   - Enable network if available
   - Hostname: motoko

7. Begin installation
8. Reboot when complete

CRITICAL WARNINGS:
- Verify partition selections TWICE before clicking "Begin Installation"
- DO NOT format /space, /flux, /time
- If /home was a directory on root (not separate partition), you'll restore from backup in Stage 3

AFTER INSTALLATION:
- Remove GRUB entry (or leave for future use)
- Boot into Fedora
- Proceed to Stage 3
```

### Manual Steps Summary

1. **Boot**: Select "Fedora 43 Workstation Live (Install)" from GRUB
2. **Installer**: Launch Anaconda installer
3. **Partitions**: Custom layout (format root, keep data)
4. **User**: Create `mdt` as administrator
5. **Install**: Complete and reboot
6. **First boot**: Log in to GNOME

---

## STAGE 3: First Boot Cleanup (Local Console, Manual)

### Context
You've successfully installed Fedora 43 and are logged in as `mdt` on the local console (GNOME).

### Agent Prompt for Stage 3

```
You are logged into motoko (Fedora 43) as mdt on the local console.

TASK: Prepare system for remote Ansible bootstrap from count-zero.

CONTEXT:
- Fresh Fedora 43 Workstation (GNOME)
- /home/mdt may contain old Ubuntu/KDE configs (if partition was reused)
- Backup available at /space/motoko-backup/
- Need to enable SSH and clean old configs

STEPS:

1. Open terminal (GNOME Terminal)

2. Clean old desktop configs from /home/mdt:
   - Run cleanup script: ~/cleanup-ubuntu-config.sh (create if needed)
   - Removes KDE/GNOME cache, old desktop state
   - Preserves SSH keys, code, Obsidian data

3. Install SSH and essential tools:
   sudo dnf update -y
   sudo dnf install -y openssh-server git curl

4. Enable and start SSH:
   sudo systemctl enable --now sshd

5. Verify SSH is listening:
   sudo systemctl status sshd
   sudo ss -tlnp | grep :22

6. Get IP address for SSH from count-zero:
   ip addr show | grep "inet "
   # Or check Tailscale if already configured

7. Test SSH from count-zero:
   # From count-zero:
   ssh mdt@<motoko-ip>

DELIVERABLES:
- SSH server running
- Old configs cleaned from /home/mdt
- System ready for remote bootstrap
- IP address known

NEXT: Proceed to Stage 4 (remote bootstrap from count-zero)
```

### Commands

```bash
# 1. Create cleanup script
cat > ~/cleanup-ubuntu-config.sh << 'CLEANUP_SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

echo "Cleaning old Ubuntu/KDE configs from /home/mdt..."

cd "${HOME}"

# Remove desktop/runtime state
rm -rf .cache/*
rm -rf .config/kde* .config/plasma* .config/kwin* .config/sddm*
rm -rf .config/gnome* .config/dconf
rm -rf .local/share/gnome* .local/share/konsole*
rm -rf .local/state/*

# Preserve: Obsidian, SSH, code, docs
echo "Preserved: .ssh/, .config/obsidian/, .local/share/obsidian/, code/, docs/"

# Fix SSH permissions
if [ -d ".ssh" ]; then
  chmod 700 .ssh
  chmod 600 .ssh/id_* 2>/dev/null || true
  chmod 644 .ssh/*.pub 2>/dev/null || true
  echo "SSH permissions fixed"
fi

echo "Cleanup complete!"
CLEANUP_SCRIPT

chmod +x ~/cleanup-ubuntu-config.sh
~/cleanup-ubuntu-config.sh

# 2. Install SSH and tools
sudo dnf update -y
sudo dnf install -y openssh-server git curl vim

# 3. Enable SSH
sudo systemctl enable --now sshd

# 4. Verify SSH
sudo systemctl status sshd
sudo ss -tlnp | grep :22

# 5. Get IP for count-zero
ip addr show | grep "inet " | grep -v 127.0.0.1

echo ""
echo "=============================================="
echo "STAGE 3 COMPLETE - SSH READY"
echo "=============================================="
echo ""
echo "From count-zero, test SSH:"
echo "  ssh mdt@<motoko-ip>"
echo ""
echo "Then proceed to Stage 4 (remote bootstrap)"
echo ""
```

### Stage 3 Complete Checklist
- [ ] Logged into Fedora 43 as mdt
- [ ] Old configs cleaned from /home/mdt
- [ ] SSH server installed and running
- [ ] Can SSH from count-zero
- [ ] Ready for Ansible bootstrap

---

## STAGE 4: Remote Bootstrap & Ansible Setup (SSH from count-zero)

### Context
You are SSH'd into motoko (Fedora 43) from count-zero. System is ready for Ansible-driven configuration.

### Agent Prompt for Stage 4

```
You are SSH'd into motoko (Fedora 43) from count-zero.

TASK: Bootstrap motoko with Ansible and restore all PHC services.

CONTEXT:
- Fresh Fedora 43 with SSH enabled
- Backup at /space/motoko-backup/
- Repository: ~/miket-infra-devices (may need clone)
- Services to restore: Docker, NVIDIA, vLLM, LiteLLM, Samba, NoMachine, Tailscale

BOOTSTRAP PROCESS:

Phase 1: Install RPM Fusion and Ansible
Phase 2: Clone/update miket-infra-devices
Phase 3: Run Ansible playbook: fedora-base.yml
Phase 4: Verify services

Use the bootstrap script at:
  ~/miket-infra-devices/ansible/scripts/bootstrap-motoko-fedora.sh

Or run manually if script doesn't exist yet.

DELIVERABLES:
- RPM Fusion enabled
- Ansible installed
- miket-infra-devices repository current
- All services configured via Ansible
- Device config updated for Fedora 43
- Services verified and running

PHC COMPLIANCE:
- All secrets from AKV (not hardcoded)
- All config via Ansible (no manual /etc edits)
- /space, /flux, /time mounted and verified
- Update docs/communications/COMMUNICATION_LOG.md
- Update devices/motoko/config.yml
```

### Commands

```bash
# Can be run from count-zero or on motoko

# 1. Run bootstrap script (if exists)
ssh mdt@motoko 'bash -s' < ~/miket-infra-devices/ansible/scripts/bootstrap-motoko-fedora.sh

# OR run manually:

# 2. Manual bootstrap steps
ssh mdt@motoko << 'REMOTE_BOOTSTRAP'

# Install RPM Fusion
sudo dnf install -y \
  https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# Install Ansible and Python
sudo dnf install -y python3 python3-pip ansible-core

# Clone/update repository
if [ ! -d "${HOME}/miket-infra-devices" ]; then
  git clone git@github.com:miket-llc/miket-infra-devices.git "${HOME}/miket-infra-devices"
else
  cd "${HOME}/miket-infra-devices"
  git pull
fi

# Run Ansible playbook
cd "${HOME}/miket-infra-devices/ansible"
ansible-playbook -i inventory/hosts.yml \
  playbooks/motoko/fedora-base.yml \
  --limit motoko \
  --connection=local

REMOTE_BOOTSTRAP

# 3. Verify services
ssh mdt@motoko << 'VERIFY'
# Check storage mounts
df -h | grep -E '(space|flux|time)'

# Check Docker + NVIDIA
docker --version
docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu24.04 nvidia-smi

# Check services
systemctl status docker tailscaled smb nmb nxserver

# Check containers
docker ps -a

# Check API endpoints
curl -s http://localhost:8001/health  # vLLM reasoning
curl -s http://localhost:8200/health  # vLLM embeddings
curl -s http://localhost:8000/health  # LiteLLM

VERIFY
```

---

## Ansible Playbook Structure

### playbooks/motoko/fedora-base.yml

This playbook should be created to handle all Fedora-specific setup:

**Responsibilities:**
1. System configuration (X11 session, SDDM/GDM config)
2. NVIDIA driver installation (RPM Fusion)
3. Docker + NVIDIA container toolkit
4. Tailscale installation and configuration
5. Storage mounts (/space, /flux, /time in fstab)
6. Services: Samba, Netatalk, NoMachine, fail2ban, postfix
7. Docker Compose deployments: vLLM, LiteLLM
8. Firewall configuration (firewalld, not ufw)

**Variables:**
- `ansible_os_family: RedHat`
- `ansible_distribution: Fedora`
- Use distro-specific task files or conditionals

---

## What Ansible Should Handle

### Package Installation (dnf)
```yaml
- name: Install NVIDIA drivers
  dnf:
    name:
      - akmod-nvidia
      - xorg-x11-drv-nvidia-cuda
    state: present
```

### Storage Mounts (/etc/fstab)
```yaml
- name: Configure /etc/fstab for PHC storage
  ansible.posix.mount:
    path: "{{ item.path }}"
    src: "UUID={{ item.uuid }}"
    fstype: "{{ item.fstype }}"
    opts: "{{ item.opts }}"
    state: mounted
  loop:
    - { path: '/space', uuid: '...', fstype: 'ext4', opts: 'defaults,noatime' }
    - { path: '/flux', uuid: '...', fstype: 'ext4', opts: 'defaults,noatime' }
    - { path: '/time', uuid: '...', fstype: 'apfs', opts: 'ro,noatime' }
```

### Docker + NVIDIA Runtime
```yaml
- name: Install Docker
  dnf:
    name:
      - docker
      - docker-compose
    state: present

- name: Install NVIDIA Container Toolkit
  block:
    - name: Add NVIDIA container repo
      get_url:
        url: "https://nvidia.github.io/libnvidia-container/{{ ansible_distribution | lower }}{{ ansible_distribution_major_version }}/libnvidia-container.repo"
        dest: /etc/yum.repos.d/nvidia-container-toolkit.repo

    - name: Install toolkit
      dnf:
        name: nvidia-container-toolkit
        state: present

    - name: Configure Docker runtime
      command: nvidia-ctk runtime configure --runtime=docker

    - name: Restart Docker
      systemd:
        name: docker
        state: restarted
```

### Firewall (firewalld, not ufw)
```yaml
- name: Configure firewalld
  ansible.posix.firewalld:
    service: "{{ item }}"
    permanent: true
    state: enabled
  loop:
    - ssh
    - samba
    - nomachine  # May need custom service file
  notify: reload firewalld
```

---

## Migration Verification Checklist

### System
- [ ] Fedora 43 Workstation installed
- [ ] GNOME on X11 (not Wayland)
- [ ] User mdt exists with correct permissions
- [ ] SSH access working via Tailscale

### Storage
- [ ] `/space` mounted (20TB, SoR)
- [ ] `/flux` mounted (runtime)
- [ ] `/time` mounted (read-only, Time Machine)
- [ ] All mounts in `/etc/fstab`
- [ ] Permissions correct (mdt can read/write)

### GPU & Docker
- [ ] NVIDIA driver installed (check `nvidia-smi`)
- [ ] Docker installed and running
- [ ] NVIDIA container toolkit configured
- [ ] Test: `docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu24.04 nvidia-smi`

### Services
- [ ] Tailscale connected to pangolin-vega
- [ ] Samba shares accessible (`\\motoko\space`)
- [ ] NoMachine running (port 4000)
- [ ] fail2ban active
- [ ] Docker containers: vllm-reasoning, vllm-embeddings, litellm

### API Endpoints
- [ ] vLLM reasoning: `http://localhost:8001/health`
- [ ] vLLM embeddings: `http://localhost:8200/health`
- [ ] LiteLLM proxy: `http://localhost:8000/health`

### Repository
- [ ] `~/miket-infra-devices` current
- [ ] Device config updated: `devices/motoko/config.yml`
- [ ] Can run Ansible playbooks locally
- [ ] Can manage remote devices (armitage, wintermute)

---

## Package Manager Reference

| Task | Ubuntu (apt) | Fedora (dnf) |
|------|--------------|--------------|
| Update cache | `apt update` | `dnf check-update` |
| Upgrade packages | `apt upgrade` | `dnf upgrade` |
| Install package | `apt install <pkg>` | `dnf install <pkg>` |
| Remove package | `apt remove <pkg>` | `dnf remove <pkg>` |
| Search package | `apt search <pkg>` | `dnf search <pkg>` |
| List installed | `apt list --installed` | `dnf list installed` |
| Clean cache | `apt clean` | `dnf clean all` |

---

## Troubleshooting

### GRUB loopback doesn't boot
- Verify ISO path in GRUB config
- Check partition number matches `/flux` location (`lsblk`)
- Try adjusting ISO label in GRUB entry
- Fallback: Create USB on another machine

### NVIDIA drivers not working
```bash
# Rebuild kernel modules
sudo akmods --force
sudo reboot

# Verify
nvidia-smi
```

### Docker NVIDIA runtime fails
```bash
# Reconfigure runtime
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# Test
docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu24.04 nvidia-smi
```

### Mounts not working
```bash
# Check UUIDs
sudo blkid

# Test fstab
sudo mount -a

# Check filesystem types
lsblk -f
```

### SELinux blocking services
```bash
# Check audit log
sudo ausearch -m avc -ts recent

# Set context (example for Samba)
sudo setsebool -P samba_export_all_rw on

# Or set file context
sudo semanage fcontext -a -t samba_share_t "/space(/.*)?"
sudo restorecon -R /space
```

### Firewalld vs ufw
```bash
# Ubuntu used ufw, Fedora uses firewalld

# Check status
sudo firewall-cmd --state

# List rules
sudo firewall-cmd --list-all

# Add service
sudo firewall-cmd --permanent --add-service=samba
sudo firewall-cmd --reload
```

---

## Rollback Plan

If migration fails at any stage:

1. **Before Stage 2 (still on Ubuntu)**:
   - Just reboot normally (skip Fedora GRUB entry)
   - Remove GRUB entry if desired

2. **After Stage 2 (Fedora installed)**:
   - Boot from Ubuntu Live USB (create beforehand)
   - Mount root partition
   - Restore from `/space/motoko-backup/`
   - Or reinstall Ubuntu 24.04

3. **Prevention**:
   - Always verify backups before starting
   - Test backup restoration on another machine
   - Keep Ubuntu Live USB as recovery option

---

## Post-Migration Tasks

### Documentation Updates
- [ ] Update `devices/motoko/config.yml` (OS, desktop, kernel)
- [ ] Update `docs/communications/COMMUNICATION_LOG.md`
- [ ] Update any OS-specific runbooks
- [ ] Document Fedora-specific configurations

### Ansible Updates
- [ ] Create/verify `playbooks/motoko/fedora-base.yml`
- [ ] Update roles with Fedora conditionals
- [ ] Test all motoko playbooks
- [ ] Update documentation for dnf vs apt

### Service Validation
- [ ] Run full PHC service verification
- [ ] Test NoMachine from count-zero
- [ ] Verify LLM inference pipeline
- [ ] Test Samba shares from all clients

### Performance Tuning
- [ ] Verify GPU performance matches Ubuntu
- [ ] Check Docker container performance
- [ ] Monitor system resources
- [ ] Tune firewalld if needed

---

## References

- [Fedora 43 Installation Guide](https://docs.fedoraproject.org/en-US/fedora/latest/install-guide/)
- [GRUB Loopback Method](https://wiki.archlinux.org/title/GRUB#Loopback_device)
- [NVIDIA on Fedora (RPM Fusion)](https://rpmfusion.org/Howto/NVIDIA)
- [Docker on Fedora](https://docs.docker.com/engine/install/fedora/)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)

---

**Last Updated:** 2025-11-29  
**Status:** Ready for Stage 1 execution


