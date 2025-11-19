# USB Storage Management Role

Manages 20TB USB 3.0 drive connected to motoko with two partitions:
- **Time Machine partition**: APFS format, read-only access for count-zero backups
- **Space partition**: ext4 format, file cache storage for enterprise cloud storage

## Features

- Auto-detects USB drive partitions by label
- Installs APFS read-only support (apfs-fuse) for Time Machine partition
- Reformats space partition to ext4 for optimal Linux performance
- Configures persistent mounts via fstab
- Sets proper permissions and ownership
- Creates file cache directory structure
- Provides mount helper script for Time Machine partition

## Usage

### From motoko (self-management)

```bash
cd ~/miket-infra-devices/ansible
ansible-playbook -i inventory/hosts.yml \
  playbooks/motoko/configure-usb-storage.yml \
  --limit motoko \
  --connection=local
```

### Detection Script

Before running the playbook, you can detect the drive:

```bash
~/miket-infra-devices/scripts/detect-usb-drive.sh
```

## Configuration

Default variables (override in `host_vars/motoko.yml` or playbook):

```yaml
usb_timemachine_mount: /mnt/usb-timemachine
usb_space_mount: /mnt/usb-space
usb_space_filesystem: ext4
usb_apfs_readonly: true
usb_apfs_driver: "apfs-fuse"
```

## Requirements

- Ubuntu 24.04 (or compatible Debian-based system)
- Build tools (installed automatically)
- FUSE3 libraries (installed automatically)
- Root/sudo access

## Time Machine Access

The Time Machine partition is configured for read-only access. To mount manually:

```bash
sudo mount-timemachine.sh
```

Or mount directly:

```bash
sudo apfs-fuse /dev/sdX1 /mnt/usb-timemachine -o allow_other,ro
```

## File Cache Structure

After configuration, the space partition will have:

```
/mnt/usb-space/
├── cache/    # Temporary cache files
├── files/    # User files
└── temp/     # Temporary storage
```

## Notes

- **APFS Support**: Uses apfs-fuse for read-only access. For write access, consider Paragon APFS for Linux (commercial license required).
- **Data Safety**: The playbook will NOT reformat the space partition unless explicitly configured. Set `usb_backup_before_format: true` to backup data first.
- **Time Machine**: The partition remains APFS to maintain compatibility with macOS Time Machine backups from count-zero.



