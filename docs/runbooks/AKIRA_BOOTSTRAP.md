# Akira Bootstrap Runbook v1.0

> **Last Updated:** 2025-12-05  
> **Target OS:** Fedora 43 Workstation (Single-Boot)  
> **Hardware:** Strix Point APU (AMD Radeon 890M / gfx1150)

## Overview

This runbook covers the manual steps required to bootstrap akira as a Fedora 43 AI/Dev workstation. These steps cannot be reasonably automated and must be performed once during initial setup.

**Scope:**
- BIOS/firmware configuration
- Fedora 43 installation (single-boot, encrypted)
- Post-install verification before Ansible

**Out of Scope:**
- Dual-boot / Windows (explicitly not supported)
- Workload migration from motoko

---

## Pre-Installation Checklist

### Hardware Verification

- [ ] System powers on and POSTs successfully
- [ ] RAM recognized: 128GB DDR5
- [ ] NVMe SSD(s) detected
- [ ] Network connectivity available (Ethernet recommended for install)

### BIOS/Firmware Settings

Enter BIOS setup (usually F2/Del during POST):

```
1. Boot Configuration:
   [ ] UEFI mode enabled (not Legacy/CSM)
   [ ] Secure Boot: ENABLED (Fedora supports it)
   [ ] Boot order: USB first (for installation)

2. CPU/Memory:
   [ ] Virtualization (AMD-V/SVM): ENABLED
   [ ] IOMMU: ENABLED
   [ ] Memory XMP/DOCP profile: ENABLED (if available)

3. GPU/Graphics:
   [ ] Resizable BAR (ReBAR): ENABLED (if available)
   [ ] Primary Display: AUTO or iGPU
   [ ] UMA Frame Buffer Size: AUTO or Maximum

4. Power Management:
   [ ] ErP/EuP: Disabled (for Wake-on-LAN if needed)
   [ ] Power On after AC Loss: Last State

5. Security:
   [ ] TPM: ENABLED (for disk encryption)
   [ ] Admin password: SET (recommended)
```

Save and exit BIOS.

---

## Fedora 43 Installation

### Prepare Installation Media

On another system:

```bash
# Download Fedora 43 Workstation ISO
wget https://download.fedoraproject.org/pub/fedora/linux/releases/43/Workstation/x86_64/iso/Fedora-Workstation-Live-x86_64-43-*.iso

# Verify checksum
sha256sum -c Fedora-Workstation-Live-x86_64-43-*.iso.sha256

# Write to USB (replace /dev/sdX with your USB device)
sudo dd if=Fedora-Workstation-Live-x86_64-43-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

### Boot and Install

1. Boot from USB
2. Select "Install to Hard Drive" from the live session
3. Anaconda installer will launch

### Anaconda Configuration

#### Language & Keyboard
- Language: English (United States)
- Keyboard: US

#### Installation Destination

**CRITICAL: Single-boot Fedora with full-disk encryption**

1. Select the target NVMe SSD
2. Storage Configuration: **Custom**
3. Click "Done" to enter partitioning

#### Partitioning Scheme

Create the following layout:

| Mount Point | Size | Type | Encrypted |
|-------------|------|------|-----------|
| /boot/efi | 1 GiB | EFI System Partition | No |
| /boot | 2 GiB | ext4 | No |
| / | 100 GiB | Btrfs (LUKS) | Yes |
| /home | 200 GiB | Btrfs (LUKS) | Yes |
| /mnt/flux | 500+ GiB | Btrfs (LUKS) | Yes |
| swap | 32 GiB | swap (LUKS) | Yes |

**To create this layout:**

1. Click "+" to add mount point
2. For LUKS partitions:
   - Check "Encrypt"
   - Enter a strong passphrase (store in 1Password)
3. Use same LUKS passphrase for all encrypted partitions (simpler boot)
4. Enable LVM if you want flexibility (optional)

**Alternative: Let Fedora decide (simpler)**

If you prefer automatic partitioning:
1. Select "Automatic" partitioning
2. Check "Encrypt my data"
3. Enter LUKS passphrase
4. Fedora will create a sensible Btrfs layout

Note: You can create /mnt/flux manually post-install if using automatic.

#### Network & Hostname

- Hostname: `akira`
- Enable network (DHCP is fine for now)

#### User Creation

Create the primary interactive user:
- Full Name: Mike T
- Username: `miket`
- Password: (set a strong password, store in 1Password)
- Check: "Make this user administrator"

The automation user `mdt` will be created post-install by Ansible.

#### Begin Installation

1. Review all settings
2. Click "Begin Installation"
3. Wait for completion (~10-20 minutes)
4. Click "Finish Installation"
5. Reboot and remove USB

---

## First Boot Verification

### Enter LUKS Passphrase

On first boot, you'll be prompted for the LUKS encryption passphrase.

### Login and Verify

Login as `miket` and open a terminal:

```bash
# 1. Verify hostname
hostname
# Expected: akira

# 2. Verify network
ip addr
ping -c 3 google.com

# 3. Verify SELinux is enforcing
getenforce
# Expected: Enforcing

# 4. Verify disk encryption
lsblk
# Should show 'crypt' type for encrypted partitions

# 5. Check kernel and OS version
uname -r
cat /etc/fedora-release
# Expected: Fedora release 43

# 6. Verify GPU is detected
lspci | grep -i vga
# Expected: AMD Radeon 890M or similar

# 7. Check ROCm basics
rocm-smi
# Should show GPU info
```

### System Update

```bash
# Update all packages
sudo dnf upgrade --refresh -y

# Reboot to apply kernel updates
sudo reboot
```

### Create Automation User

The `mdt` user is required for Ansible automation:

```bash
# Create mdt user
sudo useradd -m -s /bin/bash -G wheel,video,render mdt

# Set temporary password (will be key-only after Ansible)
sudo passwd mdt

# Configure NOPASSWD sudo
echo 'mdt ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/mdt
sudo chmod 440 /etc/sudoers.d/mdt
```

### SSH Key Setup

On your control node (motoko or count-zero):

```bash
# Copy SSH key to akira
ssh-copy-id mdt@akira.local  # or use IP address

# Verify key auth works
ssh mdt@akira.local 'hostname'
# Expected: akira
```

### Join Tailscale

```bash
# Install Tailscale
sudo dnf config-manager --add-repo https://pkgs.tailscale.com/stable/fedora/tailscale.repo
sudo dnf install -y tailscale

# Enable and start
sudo systemctl enable --now tailscaled

# Authenticate (use Entra/Azure AD)
sudo tailscale up --hostname=akira

# Follow the authentication URL in browser
# Select your Entra account

# Verify
tailscale status
# Should show akira connected to tailnet
```

### Verify Tailnet Connectivity

From another tailnet node (e.g., motoko):

```bash
# Ping akira via tailnet
ping akira.pangolin-vega.ts.net

# SSH via tailnet
ssh mdt@akira.pangolin-vega.ts.net 'hostname'
```

---

## Ready for Ansible

At this point, akira is ready for automated configuration via Ansible:

```bash
# From motoko (Ansible control node)
cd ~/miket-infra-devices/ansible

# Test connectivity
ansible akira -m ping

# Run bootstrap playbook
ansible-playbook -i inventory/hosts.yml playbooks/bootstrap-akira.yml
```

---

## Post-Bootstrap Verification

After running the Ansible playbook, verify:

```bash
# On akira

# 1. Tailscale status
tailscale status

# 2. Firewall configuration
sudo firewall-cmd --list-all-zones | grep -A 20 tailnet

# 3. ROCm functionality
rocm-smi
source ~/rocm-test/bin/activate
python -c "import torch; print(f'ROCm: {torch.cuda.is_available()}')"

# 4. Filesystem layout
ls -la ~/flux ~/space ~/time
df -h /mnt/flux /mnt/space

# 5. Test AI inference
python -c "
from llama_cpp import Llama
llm = Llama(model_path='/mnt/flux/ai/models/Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf', n_gpu_layers=-1, n_ctx=4096, verbose=False)
print('Model loaded successfully!')
"
```

---

## Troubleshooting

### LUKS Won't Unlock

- Verify passphrase is correct (check 1Password)
- Boot from USB and use `cryptsetup` to test unlock

### ROCm Not Detecting GPU

```bash
# Check kernel module
lsmod | grep amdgpu

# Check dmesg for errors
dmesg | grep -i amdgpu

# Verify GPU permissions
groups  # Should include 'video' and 'render'
ls -la /dev/dri/
```

### Tailscale Auth Fails

- Ensure you're using Entra account associated with tailnet
- Check if device limit reached in Tailscale admin
- Try: `sudo tailscale logout && sudo tailscale up`

### SSH via Tailnet Fails

```bash
# On akira, verify firewalld
sudo firewall-cmd --zone=tailnet --list-all

# Verify tailnet zone has SSH
# If not, add it:
sudo firewall-cmd --zone=tailnet --add-service=ssh --permanent
sudo firewall-cmd --reload
```

---

## Secrets Reference

| Secret | AKV Name | Purpose |
|--------|----------|---------|
| LUKS Passphrase | `akira-luks-passphrase` | Disk encryption |
| mdt Password | `akira-mdt-password` | Automation user (backup) |
| miket Password | `akira-miket-password` | Interactive user (backup) |
| Tailscale Auth Key | `akira-tailscale-authkey` | Tailscale enrollment |

All passwords should be stored in both Azure Key Vault (for automation) and 1Password (for human break-glass access).

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-12-05 | Initial bootstrap - Fedora 43 single-boot with ROCm |

