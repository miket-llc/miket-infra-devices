# Ubuntu 24.04 → Fedora Migration Guide for Motoko

**Date:** 2025-01-XX  
**Purpose:** Migrate motoko from Ubuntu 24.04 LTS to Fedora while preserving configuration and data  
**Method:** Network installation or GRUB loopback (no USB required)

---

## Overview

This guide covers migrating motoko from Ubuntu 24.04 LTS to Fedora without using a USB key. The migration preserves:
- User data (`/home/mdt`)
- Data partitions (`/space`, `/flux`, `/time`)
- Ansible configuration repository
- Service configurations (Docker, Samba, Netatalk, NoMachine, etc.)
- SSH keys and Tailscale configuration
- Application data

---

## Prerequisites

### 1. Current System State

**Motoko Configuration:**
- OS: Ubuntu 24.04 LTS (Noble)
- Desktop: KDE Plasma on X11
- Display Manager: SDDM
- Kernel: 6.x
- GPU: NVIDIA RTX 2080 (driver 535.230.02, CUDA 12.2)
- Memory: 32GB

**Critical Partitions:**
- `/` - Root filesystem (will be replaced)
- `/home/mdt` - User data (preserve)
- `/space` - 20TB USB drive, SoR storage (preserve)
- `/flux` - Runtime surface (preserve)
- `/time` - Time Machine backup target (preserve)

**Services Running:**
- Docker (with NVIDIA runtime)
- LiteLLM Proxy (port 8000)
- vLLM Reasoning (port 8001)
- vLLM Embeddings (port 8200)
- Samba (file sharing)
- Netatalk (AFP for macOS)
- NoMachine (port 4000)
- fail2ban
- postfix
- Tailscale

### 2. Backup Requirements

**Before starting, ensure:**
- [ ] Full backup of `/home/mdt` (user data, SSH keys, configs)
- [ ] Backup of `/etc` (system configurations)
- [ ] Backup of Docker volumes (if any)
- [ ] Backup of Ansible repository (`~/miket-infra-devices`)
- [ ] Export Tailscale auth key (for re-authentication)
- [ ] Document current partition layout (`lsblk`, `df -h`)
- [ ] Document current services (`systemctl list-units --type=service --state=running`)

---

## Migration Methods (No USB Required)

### Method 1: GRUB Loopback Installation (Recommended)

This method uses GRUB's loopback capability to boot a Fedora ISO directly from disk.

#### Step 1: Download Fedora ISO

```bash
# On motoko, download Fedora Workstation ISO
cd /tmp
wget https://download.fedoraproject.org/pub/fedora/linux/releases/41/Workstation/x86_64/iso/Fedora-Workstation-Live-x86_64-41-1.14.iso

# Verify checksum
wget https://download.fedoraproject.org/pub/fedora/linux/releases/41/Workstation/x86_64/iso/Fedora-Workstation-Live-x86_64-41-1.14.iso.checksum
sha256sum -c Fedora-Workstation-Live-x86_64-41-1.14.iso.checksum
```

#### Step 2: Create ISO Storage Location

```bash
# Create directory for ISO (use /flux or external storage)
sudo mkdir -p /flux/iso
sudo mv /tmp/Fedora-Workstation-Live-x86_64-41-1.14.iso /flux/iso/
sudo chmod 644 /flux/iso/Fedora-Workstation-Live-x86_64-41-1.14.iso
```

#### Step 3: Configure GRUB to Boot ISO

```bash
# Backup current GRUB config
sudo cp /etc/grub.d/40_custom /etc/grub.d/40_custom.backup

# Add Fedora ISO entry to GRUB
sudo nano /etc/grub.d/40_custom
```

Add this entry (adjust paths as needed):

```grub
menuentry "Fedora Workstation Live (Install)" {
    set isofile="/flux/iso/Fedora-Workstation-Live-x86_64-41-1.14.iso"
    loopback loop (hd0,gpt2)$isofile
    linux (loop)/isolinux/vmlinuz root=live:CDLABEL=Fedora-WS-Live-41-1-14 rd.live.image quiet
    initrd (loop)/isolinux/initrd.img
}
```

**Note:** You may need to:
- Find correct partition: `lsblk` to identify where `/flux` is mounted
- Adjust `(hd0,gpt2)` to match your partition
- Use `blkid` to find UUID if needed

#### Step 4: Update GRUB and Reboot

```bash
# Update GRUB
sudo update-grub

# Reboot and select Fedora entry
sudo reboot
```

#### Step 5: Install Fedora

1. Boot into Fedora Live environment
2. Launch Fedora installer (Anaconda)
3. **Critical:** During installation:
   - **DO NOT** format `/home/mdt` partition
   - **DO NOT** format `/space`, `/flux`, `/time` partitions
   - **DO** format root (`/`) partition
   - **DO** format `/boot` and `/boot/efi` if separate
   - Select "Custom" partitioning
   - Mount existing `/home/mdt` as `/home/mdt` (do not format)
   - Mount existing `/space`, `/flux`, `/time` (do not format)

### Method 2: Network Installation (PXE Boot)

If GRUB loopback doesn't work, use network installation:

#### Step 1: Set Up Network Boot Server

You'll need another machine on the network to serve as PXE boot server, or use a service like:
- Fedora's network install image
- Local mirror setup

#### Step 2: Configure BIOS/UEFI

1. Enable network boot in BIOS
2. Boot from network
3. Follow Fedora installation

**Note:** This method is more complex and requires network infrastructure setup.

---

## Installation Steps

### 1. Partition Layout

**Preserve these partitions (DO NOT FORMAT):**
- `/home/mdt` - User home directory
- `/space` - 20TB USB drive (SoR)
- `/flux` - Runtime surface
- `/time` - Time Machine backup

**Format these partitions:**
- `/` - Root filesystem
- `/boot` - Boot partition (if separate)
- `/boot/efi` - EFI partition (if separate)
- Swap (if separate partition)

### 2. Installation Options

**During Fedora installation:**
- Select "KDE Plasma" desktop (to match current setup)
- Enable SSH server
- Create user `mdt` (but don't overwrite `/home/mdt`)
- Install development tools
- Enable RPM Fusion repositories (for NVIDIA drivers)

### 3. Post-Installation Initial Setup

After first boot:

```bash
# Update system
sudo dnf update -y

# Install essential tools
sudo dnf install -y git vim curl wget

# Enable RPM Fusion (for NVIDIA drivers, codecs, etc.)
sudo dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
sudo dnf install -y https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# Install NVIDIA drivers
sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda
```

---

## Post-Migration Restoration

### Phase 1: Restore User Environment

#### 1.1 Restore Home Directory Permissions

```bash
# Ensure mdt user owns home directory
sudo chown -R mdt:mdt /home/mdt

# Restore SSH keys permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_*
chmod 644 ~/.ssh/*.pub
```

#### 1.2 Restore Ansible Repository

```bash
# If backed up, restore
cd ~
git clone <backup-location>/miket-infra-devices.git
# OR restore from backup
cd ~/miket-infra-devices
git pull  # if using git backup
```

#### 1.3 Restore Tailscale

```bash
# Install Tailscale
sudo dnf install -y tailscale

# Authenticate (use saved auth key or re-authenticate)
sudo tailscale up --authkey=<your-auth-key>

# Verify
tailscale status
```

### Phase 2: Restore Storage Mounts

#### 2.1 Identify Partitions

```bash
# List block devices
lsblk

# Find UUIDs
sudo blkid
```

#### 2.2 Update /etc/fstab

```bash
# Backup
sudo cp /etc/fstab /etc/fstab.backup

# Edit fstab to add mounts
sudo nano /etc/fstab
```

Add entries (adjust UUIDs to match your system):

```fstab
# /space - 20TB USB drive (SoR)
UUID=<space-uuid> /space ext4 defaults,noatime 0 2

# /flux - Runtime surface
UUID=<flux-uuid> /flux ext4 defaults,noatime 0 2

# /time - Time Machine backup
UUID=<time-uuid> /time apfs ro,noatime 0 2
```

#### 2.3 Mount and Verify

```bash
# Test fstab
sudo mount -a

# Verify mounts
df -h | grep -E '(space|flux|time)'
```

### Phase 3: Install and Configure Services

#### 3.1 Install Docker

```bash
# Install Docker
sudo dnf install -y docker docker-compose

# Install NVIDIA Container Toolkit
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.repo | \
  sudo tee /etc/yum.repos.d/nvidia-container-toolkit.repo

sudo dnf install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# Verify NVIDIA runtime
docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu24.04 nvidia-smi
```

#### 3.2 Install Samba

```bash
sudo dnf install -y samba samba-client

# Restore Samba config from backup
sudo cp /backup/samba/smb.conf /etc/samba/smb.conf

# Or configure manually
sudo nano /etc/samba/smb.conf

# Set Samba password
sudo smbpasswd -a mdt

# Enable and start
sudo systemctl enable smb nmb
sudo systemctl start smb nmb
```

#### 3.3 Install Netatalk (AFP)

```bash
# Netatalk may need to be built from source on Fedora
# Check if available in RPM Fusion or EPEL
sudo dnf install -y epel-release
sudo dnf search netatalk

# If not available, build from source
# See: https://netatalk.sourceforge.net/
```

#### 3.4 Install NoMachine

```bash
# Download NoMachine
cd /tmp
wget https://download.nomachine.com/download/9.2/Linux/nomachine_9.2.18_1.x86_64.rpm

# Install
sudo dnf install -y nomachine_9.2.18_1.x86_64.rpm

# Configure (restore from backup if available)
sudo cp /backup/nomachine/server.cfg /usr/NX/etc/server.cfg
sudo cp /backup/nomachine/node.cfg /usr/NX/etc/node.cfg

# Enable and start
sudo systemctl enable nxserver
sudo systemctl start nxserver
```

#### 3.5 Install Other Services

```bash
# fail2ban
sudo dnf install -y fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# postfix
sudo dnf install -y postfix
# Configure as needed
sudo systemctl enable postfix
sudo systemctl start postfix
```

### Phase 4: Restore Docker Services

#### 4.1 Restore Docker Compose Files

```bash
# If using Ansible, restore from repository
cd ~/miket-infra-devices/ansible
ansible-playbook -i inventory/hosts.yml \
  playbooks/motoko/deploy-vllm.yml \
  --limit motoko \
  --connection=local

ansible-playbook -i inventory/hosts.yml \
  playbooks/motoko/deploy-litellm.yml \
  --limit motoko \
  --connection=local
```

#### 4.2 Verify Docker Services

```bash
# Check containers
docker ps -a

# Check vLLM services
curl http://localhost:8001/health
curl http://localhost:8200/health

# Check LiteLLM
curl http://localhost:8000/health
```

### Phase 5: Restore Ansible Configuration

#### 5.1 Update Device Config

Update `devices/motoko/config.yml`:

```yaml
operating_system:
  os: "Fedora"
  version: "41"  # or current version
  codename: ""  # Fedora doesn't use codenames
  kernel: "6.x"
  desktop_environment: "KDE Plasma"
  display_server: "X11"
  display_manager: "SDDM"
```

#### 5.2 Update Ansible Playbooks

Review and update Ansible playbooks for Fedora compatibility:

**Package Manager Changes:**
- `apt` → `dnf`
- `apt-get` → `dnf`
- `apt-key` → `rpm --import` or `dnf config-manager`

**Service Management:**
- `systemctl` commands remain the same
- Service names may differ slightly

**File Locations:**
- Most config files remain in same locations
- Package-specific configs may differ

#### 5.3 Test Ansible Playbooks

```bash
cd ~/miket-infra-devices/ansible

# Test with --check first
ansible-playbook -i inventory/hosts.yml \
  playbooks/motoko/verify-phc-services.yml \
  --limit motoko \
  --connection=local \
  --check

# Run actual playbook
ansible-playbook -i inventory/hosts.yml \
  playbooks/motoko/verify-phc-services.yml \
  --limit motoko \
  --connection=local
```

---

## Verification Checklist

After migration, verify:

### System
- [ ] System boots successfully
- [ ] User `mdt` can log in
- [ ] KDE Plasma desktop loads
- [ ] Network connectivity works
- [ ] Tailscale connected

### Storage
- [ ] `/space` mounted and accessible
- [ ] `/flux` mounted and accessible
- [ ] `/time` mounted and accessible (read-only for APFS)
- [ ] Permissions correct on all mounts

### Services
- [ ] Docker running with NVIDIA runtime
- [ ] vLLM reasoning service (port 8001)
- [ ] vLLM embeddings service (port 8200)
- [ ] LiteLLM proxy (port 8000)
- [ ] Samba shares accessible
- [ ] Netatalk (AFP) working
- [ ] NoMachine accessible (port 4000)
- [ ] fail2ban running
- [ ] postfix running (if needed)

### Remote Access
- [ ] SSH accessible via Tailscale
- [ ] NoMachine accessible via Tailscale
- [ ] Can connect from count-zero (macOS)

### Ansible
- [ ] Ansible repository accessible
- [ ] Can run playbooks locally
- [ ] Can manage remote devices

---

## Troubleshooting

### Issue: GRUB Loopback Not Working

**Solution:**
- Verify ISO path is correct
- Check partition numbers match (`lsblk`)
- Try alternative: Use network installation
- Or: Create bootable USB on another machine

### Issue: NVIDIA Drivers Not Working

**Solution:**
```bash
# Rebuild kernel modules
sudo akmods --force

# Reboot
sudo reboot

# Verify
nvidia-smi
```

### Issue: Docker NVIDIA Runtime Not Working

**Solution:**
```bash
# Reconfigure NVIDIA runtime
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# Test
docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu24.04 nvidia-smi
```

### Issue: Services Not Starting

**Solution:**
- Check service status: `systemctl status <service>`
- Check logs: `journalctl -u <service> -n 50`
- Verify config files restored correctly
- Check file permissions

### Issue: Mounts Not Working

**Solution:**
```bash
# Check fstab syntax
sudo mount -a

# Verify UUIDs
sudo blkid

# Check filesystem types
lsblk -f
```

---

## Rollback Plan

If migration fails:

1. **Boot from Ubuntu Live USB** (create before migration)
2. **Mount root partition**
3. **Restore from backup** if needed
4. **Or reinstall Ubuntu** and restore from backups

**Prevention:** Always have a backup and recovery plan before starting.

---

## Post-Migration Tasks

### 1. Update Documentation

- [ ] Update `devices/motoko/config.yml`
- [ ] Update any OS-specific documentation
- [ ] Document any Fedora-specific configurations

### 2. Update Ansible Roles

- [ ] Create Fedora-specific tasks where needed
- [ ] Update package manager references
- [ ] Test all playbooks

### 3. Performance Tuning

- [ ] Verify GPU performance
- [ ] Check Docker performance
- [ ] Monitor system resources

---

## Notes

- **Fedora uses SELinux by default** - may need to configure contexts for some services
- **Firewall is firewalld** (not ufw) - update firewall rules accordingly
- **Package names may differ** - use `dnf search` to find equivalents
- **Service names may differ** - check with `systemctl list-units`

---

## References

- [Fedora Installation Guide](https://docs.fedoraproject.org/en-US/quick-docs/installing-fedora/)
- [GRUB Loopback Installation](https://wiki.archlinux.org/title/GRUB#Loopback_device)
- [NVIDIA Drivers on Fedora](https://rpmfusion.org/Howto/NVIDIA)
- [Docker on Fedora](https://docs.docker.com/engine/install/fedora/)

---

**Last Updated:** 2025-01-XX  
**Status:** Draft - Review before execution
