# /space Sync Monitoring Guide

The bulk `/space` sync from motoko to akira is running in the background and can be monitored, stopped, and resumed.

## Current Status

**Sync is running in the background on motoko**

- **PID:** Check with `space-sync-monitor.sh`
- **Log file:** `/var/log/space-migration/space-sync-*.log`
- **Status file:** `/var/log/space-migration/space-sync-status.json`

## Monitoring Commands

### Check Status
```bash
# From motoko or via Ansible
ssh mdt@motoko "space-sync-monitor.sh"

# Or via Ansible
ansible motoko -i inventory/hosts.yml -m shell -a "space-sync-monitor.sh"
```

### Follow Live Progress
```bash
# From motoko
ssh mdt@motoko "space-sync-monitor.sh --follow"

# Or directly tail the log
ssh mdt@motoko "tail -f /var/log/space-migration/space-sync-*.log"
```

### Check Process
```bash
ssh mdt@motoko "ps aux | grep space-sync-background"
ssh mdt@motoko "cat /var/log/space-migration/space-sync.pid"
```

## Stopping the Sync

The sync can be safely stopped - it uses `--partial` so it can resume:

```bash
# Find the PID
PID=$(ssh mdt@motoko "cat /var/log/space-migration/space-sync.pid")

# Stop gracefully
ssh mdt@motoko "kill $PID"

# Or force stop
ssh mdt@motoko "kill -9 $PID"
```

## Resuming the Sync

Simply run the script again - rsync will resume from where it left off:

```bash
# Via SSH
ssh mdt@motoko "nohup /usr/local/bin/space-sync-background.sh bulk > /dev/null 2>&1 &"

# Or via Ansible
ansible motoko -i inventory/hosts.yml -m shell -a "nohup /usr/local/bin/space-sync-background.sh bulk > /dev/null 2>&1 &"
```

## Verifying Completion

When the sync completes, check:

```bash
# Check status
ssh mdt@motoko "space-sync-monitor.sh"

# Verify sizes match (allowing for ephemeral data differences)
ssh mdt@akira "du -sh /space"
ssh mdt@motoko "du -sh /space"

# Check for errors in log
ssh mdt@motoko "grep -i error /var/log/space-migration/space-sync-*.log | tail -20"
```

## Expected Duration

- **Bulk sync:** 4-8 hours for ~10TB (depends on network speed)
- **Delta sync:** 15-60 minutes (only changed files)

## Next Steps After Sync Completes

1. Verify sync completion
2. Run delta sync before cutover: `space-sync-background.sh delta`
3. Stage Nextcloud: `ansible-playbook playbooks/migration/nextcloud-stage-akira.yml --limit akira`
4. Execute cutover: `ansible-playbook playbooks/migration/nextcloud-cutover.yml`

