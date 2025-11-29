# Backblaze Backup Services - Manual Trigger Guide

## Overview

The Backblaze backup services run automatically on a schedule:
- **flux-backup**: Daily at 05:00 (backup `/flux` to Backblaze B2 using restic)
- **space-mirror**: Nightly at 04:00 (mirror `/space` to Backblaze B2 using rclone)

Both services can be manually triggered when needed.

## Quick Reference

### Using the Helper Script (Recommended)

After deployment, use the `backblaze-trigger.sh` script:

```bash
# Trigger flux backup
sudo backblaze-trigger.sh flux-backup

# Trigger space mirror
sudo backblaze-trigger.sh space-mirror

# Trigger both services
sudo backblaze-trigger.sh all
```

### Using systemctl Directly

You can also trigger services directly using systemctl:

```bash
# Trigger flux backup
sudo systemctl start flux-backup.service

# Trigger space mirror
sudo systemctl start space-mirror.service
```

## Monitoring

### Check Service Status

```bash
# Check if service is running
sudo systemctl status flux-backup.service
sudo systemctl status space-mirror.service
```

### View Live Logs

```bash
# View systemd journal logs
sudo journalctl -u flux-backup.service -f
sudo journalctl -u space-mirror.service -f

# View script log files
sudo tail -f /var/log/flux-backup.log
sudo tail -f /var/log/space-mirror.log
```

### Check Last Run Time

```bash
# Check when timer last triggered
systemctl list-timers flux-backup.timer
systemctl list-timers space-mirror.timer

# Check service execution history
journalctl -u flux-backup.service --since "1 week ago"
journalctl -u space-mirror.service --since "1 week ago"
```

## Service Details

### flux-backup.service

- **Purpose**: Encrypted, deduplicated backup of `/flux` to Backblaze B2
- **Tool**: Restic
- **Destination**: `b2:miket-backups-restic:flux`
- **Schedule**: Daily at 05:00
- **Retention**: 7 daily, 4 weekly, 12 monthly snapshots
- **Log**: `/var/log/flux-backup.log`

### space-mirror.service

- **Purpose**: 1:1 mirror of `/space` to Backblaze B2
- **Tool**: Rclone
- **Destination**: `b2:miket-space-mirror`
- **Schedule**: Nightly at 04:00
- **Mode**: Sync (mirrors deletions)
- **Log**: `/var/log/space-mirror.log`

## Troubleshooting

### Service Fails to Start

1. Check credentials are loaded:
   ```bash
   sudo cat /etc/miket/storage-credentials.env
   ```

2. Check service configuration:
   ```bash
   sudo systemctl cat flux-backup.service
   sudo systemctl cat space-mirror.service
   ```

3. Check for errors:
   ```bash
   sudo journalctl -u flux-backup.service -n 50
   sudo journalctl -u space-mirror.service -n 50
   ```

### Credentials Missing

If you see credential errors, sync secrets from Azure Key Vault:

```bash
# From your local machine
ansible-playbook -i inventory/hosts.yml playbooks/secrets-sync.yml --limit motoko
```

### Verify Backups

```bash
# Check restic snapshots
restic -r b2:miket-backups-restic:flux snapshots

# Check rclone sync status
rclone check /space b2:miket-space-mirror
```

## Deployment

The `backblaze-trigger.sh` script is deployed automatically when you run the data-lifecycle Ansible role:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/motoko/deploy-data-lifecycle.yml
```

The script will be available at `/usr/local/bin/backblaze-trigger.sh` on motoko.

