# Ubuntu → Fedora Migration Quick Reference

**Quick checklist and command reference for motoko migration**

---

## Pre-Migration Checklist

```bash
# 1. Run backup script
~/miket-infra-devices/scripts/motoko-pre-migration-backup.sh

# 2. Document current state
lsblk > ~/current-partitions.txt
df -h > ~/current-mounts.txt
systemctl list-units --type=service > ~/current-services.txt

# 3. Export Tailscale auth key (if needed)
# Get from Tailscale admin console

# 4. Verify backups
ls -lh /flux/backups/migration-*/
```

---

## Installation Method: GRUB Loopback

### Download Fedora ISO

```bash
cd /tmp
wget https://download.fedoraproject.org/pub/fedora/linux/releases/41/Workstation/x86_64/iso/Fedora-Workstation-Live-x86_64-41-1.14.iso
sudo mkdir -p /flux/iso
sudo mv Fedora-Workstation-Live-x86_64-41-1.14.iso /flux/iso/
```

### Configure GRUB

```bash
# Find partition for /flux
lsblk
# Note the partition (e.g., /dev/sdb2)

# Edit GRUB custom
sudo nano /etc/grub.d/40_custom
```

Add entry (adjust partition):
```grub
menuentry "Fedora Workstation Live (Install)" {
    set isofile="/flux/iso/Fedora-Workstation-Live-x86_64-41-1.14.iso"
    loopback loop (hd0,gpt2)$isofile
    linux (loop)/isolinux/vmlinuz root=live:CDLABEL=Fedora-WS-Live-41-1-14 rd.live.image quiet
    initrd (loop)/isolinux/initrd.img
}
```

```bash
sudo update-grub
sudo reboot
```

---

## Post-Installation: Essential Setup

### 1. System Update

```bash
sudo dnf update -y
```

### 2. Enable RPM Fusion

```bash
sudo dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
sudo dnf install -y https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
```

### 3. Install NVIDIA Drivers

```bash
sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda
sudo reboot
# After reboot, verify:
nvidia-smi
```

### 4. Install Docker + NVIDIA Runtime

```bash
sudo dnf install -y docker docker-compose

# NVIDIA Container Toolkit
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.repo | \
  sudo tee /etc/yum.repos.d/nvidia-container-toolkit.repo

sudo dnf install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl enable --now docker
sudo systemctl restart docker

# Test
docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu24.04 nvidia-smi
```

### 5. Restore Storage Mounts

```bash
# Find UUIDs
sudo blkid

# Edit fstab
sudo nano /etc/fstab
```

Add (adjust UUIDs):
```fstab
UUID=<space-uuid> /space ext4 defaults,noatime 0 2
UUID=<flux-uuid> /flux ext4 defaults,noatime 0 2
UUID=<time-uuid> /time apfs ro,noatime 0 2
```

```bash
# Test mounts
sudo mount -a
df -h | grep -E '(space|flux|time)'
```

### 6. Restore Tailscale

```bash
sudo dnf install -y tailscale
sudo tailscale up --authkey=<your-auth-key>
tailscale status
```

### 7. Restore Services

```bash
# Samba
sudo dnf install -y samba samba-client
sudo cp /flux/backups/migration-*/services/samba/* /etc/samba/
sudo smbpasswd -a mdt
sudo systemctl enable --now smb nmb

# NoMachine
cd /tmp
wget https://download.nomachine.com/download/9.2/Linux/nomachine_9.2.18_1.x86_64.rpm
sudo dnf install -y nomachine_9.2.18_1.x86_64.rpm
sudo cp /flux/backups/migration-*/services/nomachine/* /usr/NX/etc/
sudo systemctl enable --now nxserver

# fail2ban
sudo dnf install -y fail2ban
sudo cp -r /flux/backups/migration-*/services/fail2ban/* /etc/fail2ban/
sudo systemctl enable --now fail2ban
```

### 8. Restore Ansible & Deploy Services

```bash
# Restore repository
cd ~
tar -xzf /flux/backups/migration-*/ansible/miket-infra-devices.tar.gz

# Update config for Fedora
cd ~/miket-infra-devices
# Edit devices/motoko/config.yml (change OS to Fedora)

# Deploy services
cd ansible
ansible-playbook -i inventory/hosts.yml \
  playbooks/motoko/deploy-vllm.yml \
  --limit motoko \
  --connection=local

ansible-playbook -i inventory/hosts.yml \
  playbooks/motoko/deploy-litellm.yml \
  --limit motoko \
  --connection=local
```

---

## Package Manager Equivalents

| Ubuntu (apt) | Fedora (dnf) |
|--------------|--------------|
| `apt update` | `dnf check-update` |
| `apt upgrade` | `dnf upgrade` |
| `apt install <pkg>` | `dnf install <pkg>` |
| `apt remove <pkg>` | `dnf remove <pkg>` |
| `apt search <pkg>` | `dnf search <pkg>` |
| `apt list --installed` | `dnf list installed` |

---

## Service Verification

```bash
# Check all services
systemctl status docker
systemctl status smb nmb
systemctl status nxserver
systemctl status fail2ban

# Check Docker containers
docker ps -a

# Check vLLM
curl http://localhost:8001/health
curl http://localhost:8200/health

# Check LiteLLM
curl http://localhost:8000/health

# Check mounts
df -h | grep -E '(space|flux|time)'

# Check Tailscale
tailscale status
```

---

## Common Issues

### NVIDIA drivers not working
```bash
sudo akmods --force
sudo reboot
```

### Docker NVIDIA runtime not working
```bash
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### Mounts not working
```bash
sudo mount -a
sudo blkid  # Verify UUIDs
```

### SELinux blocking services
```bash
# Check SELinux context
ls -Z /path/to/file

# Set context if needed
sudo chcon -t <context> /path/to/file
```

---

## Full Documentation

See: [ubuntu-to-fedora-migration.md](./ubuntu-to-fedora-migration.md)


