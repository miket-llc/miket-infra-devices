# Akira: GNOME to KDE Plasma Conversion

**Last Updated:** 2025-12-06  
**Scope:** Complete, idempotent conversion of akira from GNOME to KDE Plasma

## Overview

This runbook documents the GNOME → KDE Plasma conversion for akira, following the pattern established by armitage per ADR-004 (KDE Plasma as the standard Linux UI baseline).

### Architecture References

- **ADR-004:** KDE Plasma is the standard desktop for all Linux UI nodes
- **ADR-005:** akira uses vLLM server pattern for AI workloads
- **FILESYSTEM_ARCHITECTURE.md:** Flux/Space/Time storage layout preserved

### What This Conversion Does

1. **Archives GNOME configuration** to `~/.mkt/archives/gnome-config-{timestamp}/`
2. **Installs KDE Plasma** desktop environment with SDDM display manager
3. **Removes GNOME packages** while preserving GTK libraries and shared components
4. **Preserves all infrastructure** - filesystem mounts, accounts, secrets, tailnet

## Prerequisites

- akira is running Fedora 43 with GNOME installed
- Network connectivity via Tailscale
- mdt user has sudo access
- ROCm GPU drivers installed (AMD Strix Point)
- Access to Azure Key Vault for secrets sync

## Running the Conversion

### Check Mode (Dry Run)

Always run in check mode first to see what changes will be made:

```bash
cd ~/dev/miket-infra-devices

ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/workstations/akira-fedora-kde.yml \
  --check
```

### Full Conversion

Run the complete conversion playbook:

```bash
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/workstations/akira-fedora-kde.yml
```

Or use the wrapper playbook:

```bash
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/deploy-akira-fedora-kde.yml
```

### Running Specific Phases

Archive GNOME configs only:
```bash
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/workstations/akira-fedora-kde.yml \
  --tags gnome-archive
```

Install KDE only:
```bash
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/workstations/akira-fedora-kde.yml \
  --tags kde
```

Remove GNOME only (after KDE is working):
```bash
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/workstations/akira-fedora-kde.yml \
  --tags gnome-removal
```

## Post-Conversion Steps

### 1. Reboot the System

```bash
sudo systemctl reboot
```

### 2. Verify KDE Session

After reboot:
- SDDM should present the login screen
- Select "Plasma (Wayland)" session
- Log in as your user (miket)

### 3. Verify Display Manager

```bash
# Check SDDM is running
sudo systemctl status sddm

# Verify default target
systemctl get-default
# Expected: graphical.target

# Verify display manager link
ls -la /etc/systemd/system/display-manager.service
# Should point to sddm.service
```

### 4. Verify Filesystem Mounts

```bash
# Check symlinks
ls -la ~/flux ~/space ~/time

# Verify mounts
df -h /flux /space /time
```

### 5. Verify AI Services (if applicable)

```bash
# Check if vLLM or llama-server is running
systemctl status llama-server

# Test AI API
curl http://localhost:8080/health
```

## GNOME Config Archive Location

All GNOME configuration is archived (not deleted) to:

```
~/.mkt/archives/gnome-config-{timestamp}/
├── MANIFEST.md              # Archive documentation
├── dconf-backup.ini         # Full dconf database dump
├── .config/
│   ├── gnome-shell/         # Shell extensions, settings
│   ├── dconf/               # dconf database files
│   ├── gtk-3.0/             # GTK3 settings
│   └── gtk-4.0/             # GTK4 settings
└── .local/share/
    ├── gnome-shell/         # Shell data
    └── keyrings/            # GNOME keyring (passwords)
```

## Rollback Procedure

If you need to restore GNOME:

### 1. Reinstall GNOME Desktop

```bash
sudo dnf install @gnome-desktop-environment gdm
```

### 2. Restore GNOME Configuration

```bash
# Find your archive
ARCHIVE=$(ls -td ~/.mkt/archives/gnome-config-* | head -1)

# Restore dconf database
dconf load / < "$ARCHIVE/dconf-backup.ini"

# Copy config directories back
cp -r "$ARCHIVE/.config/gnome-shell" ~/.config/
cp -r "$ARCHIVE/.config/dconf" ~/.config/
cp -r "$ARCHIVE/.local/share/gnome-shell" ~/.local/share/
```

### 3. Switch Display Manager

```bash
sudo systemctl disable sddm
sudo systemctl enable gdm
sudo systemctl set-default graphical.target
sudo systemctl reboot
```

## Idempotency

The conversion playbook is idempotent. Running it multiple times will:

- Skip archiving if archive already exists for the same timestamp
- Skip package installation if packages are already installed
- Skip package removal if packages are already removed
- Show "changed=0" for tasks that are already in the desired state

```bash
# Second run should show minimal changes
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/workstations/akira-fedora-kde.yml

# Expected: "changed=0" or very few changes
```

## Troubleshooting

### SDDM Not Starting

```bash
# Check SDDM status
sudo systemctl status sddm

# Check logs
sudo journalctl -u sddm -f

# Force graphical target
sudo systemctl set-default graphical.target
sudo systemctl isolate graphical.target
```

### KDE Session Crashes

```bash
# Check Plasma logs
journalctl --user -u plasma-plasmashell

# Reset Plasma config (destructive)
rm -rf ~/.config/plasma*
rm -rf ~/.local/share/plasma*
```

### GTK Apps Look Wrong

GTK apps may look unstyled until you configure Plasma's GTK theme:

1. Open System Settings → Appearance → Application Style
2. Click "Configure GNOME/GTK Application Style"
3. Select "Breeze" for GTK2 and GTK3

### Keyring Issues

If passwords aren't remembered:

1. Open KDE Wallet Manager
2. Create a new wallet or migrate from GNOME keyring
3. GNOME keyring is archived at `~/.mkt/archives/gnome-config-*/keyrings/`

## What's Preserved

- ✅ Filesystem mounts (`/flux`, `/space`, `/time`)
- ✅ User symlinks (`~/flux`, `~/space`, `~/time`)
- ✅ Tailscale connectivity and tags
- ✅ SSH keys and authorized_keys
- ✅ Azure Key Vault secrets integration
- ✅ ROCm GPU drivers and AI stack
- ✅ Podman containers and images
- ✅ Firewall rules (via firewalld_tailnet role)
- ✅ mdt automation account
- ✅ miket interactive user account

## What's Changed

- 🔄 Desktop environment: GNOME → KDE Plasma
- 🔄 Display manager: GDM → SDDM
- 🔄 Terminal: GNOME Terminal → Konsole
- 🔄 File manager: Nautilus → Dolphin
- 🔄 Text editor: GNOME Text Editor → Kate
- 🔄 Settings: GNOME Control Center → KDE System Settings

## Related Documentation

- [ADR-004: KDE Plasma Standard](../architecture/adr/ADR-004-kde-plasma-standard.md)
- [ARMITAGE_REBUILD_FEDORA_KDE_OLLAMA.md](./ARMITAGE_REBUILD_FEDORA_KDE_OLLAMA.md)
- [AKIRA_POWER_RUNBOOK.md](./AKIRA_POWER_RUNBOOK.md)
- [FILESYSTEM_ARCHITECTURE.md](../architecture/FILESYSTEM_ARCHITECTURE.md)



