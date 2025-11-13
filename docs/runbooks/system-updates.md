# System Updates Runbook

## Overview

This runbook describes how to manage system updates across Linux, Windows, Docker, and application code using the Ansible update playbooks. The update system is configured for weekly automated updates with security and critical patches only.

## Update Strategy

- **Frequency**: Weekly (Sunday at 2 AM)
- **Scope**: Security + Critical Updates Only
- **Feature Updates**: Excluded
- **Reboot Policy**: Notify only, manual scheduling required
- **Automation**: Fully automated with notifications

## Manual Update Execution

### Check What Would Be Updated (Dry Run)

```bash
# Check all systems
ansible-playbook -i inventory/hosts.yml playbooks/updates/all-updates.yml --check

# Check specific host
ansible-playbook -i inventory/hosts.yml playbooks/updates/all-updates.yml --limit motoko --check

# Check only Linux systems
ansible-playbook -i inventory/hosts.yml playbooks/updates/linux-updates.yml --check
```

### Run Updates

```bash
# Update all systems
ansible-playbook -i inventory/hosts.yml playbooks/updates/all-updates.yml --ask-vault-pass

# Update specific host
ansible-playbook -i inventory/hosts.yml playbooks/updates/all-updates.yml --limit motoko --ask-vault-pass

# Update only Linux systems
ansible-playbook -i inventory/hosts.yml playbooks/updates/linux-updates.yml

# Update only Windows systems
ansible-playbook -i inventory/hosts.yml playbooks/updates/windows-updates.yml --ask-vault-pass

# Update only Docker services
ansible-playbook -i inventory/hosts.yml playbooks/updates/docker-updates.yml

# Update only application code
ansible-playbook -i inventory/hosts.yml playbooks/updates/app-updates.yml --ask-vault-pass
```

### Selective Updates

```bash
# Security updates only
ansible-playbook -i inventory/hosts.yml playbooks/updates/all-updates.yml --tags security

# Check reboot requirements only (Windows)
ansible-playbook -i inventory/hosts.yml playbooks/updates/windows-updates.yml --tags reboot-check --ask-vault-pass
```

## Automated Scheduling

### Linux (systemd Timer)

The `system-updates` role creates a systemd timer on the control node (motoko) that runs weekly updates automatically.

**Setup:**
```bash
ansible-playbook -i inventory/hosts.yml -e "ansible_host=motoko" playbooks/setup-update-scheduling.yml
```

**Check Status:**
```bash
systemctl status system-updates.timer
systemctl list-timers system-updates.timer
```

**Manual Trigger:**
```bash
systemctl start system-updates.service
```

**Disable:**
```bash
systemctl stop system-updates.timer
systemctl disable system-updates.timer
```

### Windows (Scheduled Task)

Windows hosts have a scheduled task that can trigger updates. The task runs weekly on Sunday at 2 AM.

**Check Status:**
```powershell
Get-ScheduledTask -TaskName "System Updates"
```

**Manual Trigger:**
```powershell
Start-ScheduledTask -TaskName "System Updates"
```

## Configuration

### Update Settings

Edit `group_vars/all/updates.yml` to configure:
- Update frequency and schedule
- Update scope (security-only vs all)
- Reboot handling
- Notification settings
- Package exclusions

### Host-Specific Overrides

Override settings per host in `host_vars/<hostname>/updates.yml`:

```yaml
update_schedule_day: Monday
update_schedule_time: "03:00"
update_exclude_packages:
  - kernel
  - kernel-headers
```

### Docker Image Updates

Configure Docker images to update in `group_vars/all/updates.yml`:

```yaml
docker_update_images:
  - vllm/vllm-openai:latest
  - nginx:latest

docker_update_compose_files:
  - /opt/vllm-motoko/docker-compose.yml
  - /opt/litellm/docker-compose.yml

docker_health_checks:
  - url: "http://localhost:8001/health"
    status_code: 200
```

### Application Code Updates

Configure scripts and configs to update:

```yaml
app_update_scripts:
  - src: "scripts/Auto-ModeSwitcher.ps1"
    dest: "C:\\Users\\mdt\\dev\\{{ inventory_hostname }}\\scripts\\Auto-ModeSwitcher.ps1"

app_update_configs:
  - src: "templates/config.yml.j2"
    dest: "/etc/app/config.yml"
    mode: "0644"
```

## Notifications

### Email Notifications

Configure email notifications in `group_vars/all/updates.yml`:

```yaml
update_notification_email: "admin@example.com"
```

Requires SMTP configuration on the control node.

### Webhook Notifications

Configure webhook (e.g., Slack) notifications:

```yaml
update_notification_webhook: "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
```

## Troubleshooting

### Updates Fail on Linux

1. Check disk space:
   ```bash
   df -h
   ```

2. Check apt cache:
   ```bash
   sudo apt update
   sudo apt list --upgradable
   ```

3. Check service status:
   ```bash
   systemctl status docker
   systemctl status ssh
   ```

### Updates Fail on Windows

1. Check Windows Update service:
   ```powershell
   Get-Service wuauserv
   ```

2. Check for pending reboots:
   ```powershell
   Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
   ```

3. Check WinRM connectivity:
   ```bash
   ansible windows -i inventory/hosts.yml -m win_ping
   ```

### Docker Updates Fail

1. Check Docker service:
   ```bash
   systemctl status docker  # Linux
   Get-Service "Docker Desktop Service"  # Windows
   ```

2. Check disk space for Docker:
   ```bash
   docker system df
   ```

3. Check container logs:
   ```bash
   docker logs <container_name>
   ```

### Scheduled Updates Not Running

**Linux:**
```bash
# Check timer status
systemctl status system-updates.timer

# Check service logs
journalctl -u system-updates.service

# Check last run
systemctl list-timers system-updates.timer
```

**Windows:**
```powershell
# Check task status
Get-ScheduledTask -TaskName "System Updates"

# Check task history
Get-WinEvent -LogName Microsoft-Windows-TaskScheduler/Operational | Where-Object {$_.Message -like "*System Updates*"}
```

## Rollback Procedures

### Linux Package Rollback

```bash
# List recent package changes
grep " install " /var/log/dpkg.log | tail -20

# Remove specific package version
sudo apt remove <package-name>

# Reinstall specific version
sudo apt install <package-name>=<version>
```

### Windows Update Rollback

```powershell
# List installed updates
Get-HotFix | Sort-Object InstalledOn -Descending

# Uninstall specific update
wusa /uninstall /kb:<KB-number>
```

### Docker Rollback

```bash
# Revert to previous image
docker pull <image>:<previous-tag>
docker compose -f <compose-file> up -d
```

## Monitoring

### Update History

Check update logs:
- Linux: `/var/log/apt/history.log`
- Windows: Event Viewer → Windows Logs → System
- Ansible: Check playbook output logs

### Health Checks

After updates, verify:
1. Critical services are running
2. Applications are functional
3. No unexpected reboots occurred
4. Disk space is adequate

## Best Practices

1. **Always test in check mode first**: Use `--check` to preview changes
2. **Update during maintenance windows**: Schedule updates during low-usage periods
3. **Monitor after updates**: Verify services and applications post-update
4. **Keep backups**: Ensure backups are current before major updates
5. **Document changes**: Note any manual interventions or issues
6. **Review notifications**: Check update reports and reboot requirements

## Related Documentation

- [Ansible Vault Setup](ansible-vault-setup.md)
- [Ansible Windows Setup](../ansible-windows-setup.md)
- Update playbooks README: `ansible/playbooks/updates/README.md`

