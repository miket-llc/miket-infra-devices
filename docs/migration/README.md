# Migration Documentation

This directory contains migration guides and plans for the MikeT Personal Hybrid Cloud infrastructure.

## Current Migrations

### Motoko: Ubuntu 24.04 → Fedora 43

**Status:** Ready for execution  
**Method:** GRUB loopback (no USB required)  
**Approach:** Minimal manual steps, Ansible-driven restoration

**Documents:**
- **[motoko-ubuntu-to-fedora-43.md](./motoko-ubuntu-to-fedora-43.md)** - Complete migration guide with stage-specific prompts
- **[ubuntu-to-fedora-quick-reference.md](./ubuntu-to-fedora-quick-reference.md)** - Quick command reference (legacy, superseded by above)
- **[ubuntu-to-fedora-migration.md](./ubuntu-to-fedora-migration.md)** - Original draft guide (legacy)

**Scripts:**
- `scripts/stage1-prepare-migration.sh` - Automates Stage 1 (backup + ISO + GRUB)
- `scripts/motoko-pre-migration-backup.sh` - Backup script (called by stage1)
- `scripts/cleanup-ubuntu-config.sh` - Cleanup old desktop configs on Fedora
- `ansible/scripts/bootstrap-motoko-fedora.sh` - Bootstrap Fedora with Ansible

**Playbooks:**
- `ansible/playbooks/motoko/fedora-base.yml` - Fedora 43 base configuration

---

## Quick Start

### For Motoko Migration

**Stage 1 (Ubuntu, via SSH):**
```bash
# From count-zero
ssh mdt@motoko 'bash -s' < ~/miket-infra-devices/scripts/stage1-prepare-migration.sh

# Follow prompts, then reboot
```

**Stage 2 (Manual, local console):**
- Boot from "Fedora 43 Workstation Live (Install)" in GRUB
- Run Fedora installer with custom partitioning
- Format `/` but preserve `/space`, `/flux`, `/time`, `/home`

**Stage 3 (Fedora, local console):**
```bash
# First boot after installation
~/miket-infra-devices/scripts/cleanup-ubuntu-config.sh
sudo dnf install -y openssh-server git curl
sudo systemctl enable --now sshd
```

**Stage 4 (Fedora, via SSH from count-zero):**
```bash
# Bootstrap Ansible
ssh mdt@motoko 'bash -s' < ~/miket-infra-devices/ansible/scripts/bootstrap-motoko-fedora.sh

# Verify services
ssh mdt@motoko
cd ~/miket-infra-devices/ansible
ansible-playbook -i inventory/hosts.yml \
  playbooks/motoko/verify-phc-services.yml \
  --limit motoko --connection=local
```

---

## Migration Philosophy

### What We Preserve
- **Data partitions**: `/space` (SoR), `/flux` (runtime), `/time` (Time Machine)
- **User data**: SSH keys, code, docs, Obsidian (from `/home/mdt`)
- **Ansible repository**: Source of truth for all configuration

### What We DON'T Preserve
- **Desktop configs**: KDE/GNOME cache, state, settings
- **System packages**: Rebuild via package manager
- **Service configs**: Use Ansible templates, not direct `/etc` restoration

### Guiding Principles
1. **Ansible is source of truth** - No manual `/etc` edits
2. **Minimal manual steps** - Automate everything possible
3. **Data safety first** - Never format data partitions
4. **Reference, don't restore** - Old configs are for Ansible template reference only
5. **PHC invariants** - Maintain `/space`, `/flux`, `/time` architecture

---

## Related Documentation

- [Architecture Review](../ARCHITECTURE_REVIEW.md)
- [PHC Prompt](../../PHC_PROMPT.md)
- [Communication Log](../communications/COMMUNICATION_LOG.md)

---

**Last Updated:** 2025-11-29


