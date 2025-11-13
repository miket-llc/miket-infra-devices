# Update Playbooks

This directory contains playbooks for managing system updates across Linux, Windows, Docker, and application code.

## Playbooks

### `all-updates.yml`
Master orchestrator playbook that coordinates all update types. Use this for comprehensive system updates.

**Usage:**
```bash
# Run all updates
ansible-playbook -i ../inventory/hosts.yml playbooks/updates/all-updates.yml --ask-vault-pass

# Check mode (dry run)
ansible-playbook -i ../inventory/hosts.yml playbooks/updates/all-updates.yml --check
```

**Tags:**
- `linux` - Linux system updates only
- `windows` - Windows system updates only
- `docker` - Docker image updates only
- `apps` - Application code updates only
- `security` - Security updates only
- `pre-check` - Pre-flight checks only
- `notify` - Send notifications

### `linux-updates.yml`
Updates Linux systems (Debian/Ubuntu) with security and critical packages.

**Features:**
- Security and critical updates only
- Kernel cleanup (keeps last 2 kernels)
- Pre-flight checks (disk space, services)
- Post-update verification

**Usage:**
```bash
ansible-playbook -i ../inventory/hosts.yml playbooks/updates/linux-updates.yml
```

**Tags:**
- `pre-check` - Pre-flight checks only
- `updates` - Package updates
- `cleanup` - Cleanup tasks
- `security` - Security-related tasks only

### `windows-updates.yml`
Updates Windows systems with security and critical Windows Updates, plus Chocolatey packages.

**Features:**
- Security and critical Windows Updates only
- Chocolatey package updates (selective)
- Reboot requirement detection (notify only)
- Pre-flight checks

**Usage:**
```bash
ansible-playbook -i ../inventory/hosts.yml playbooks/updates/windows-updates.yml --ask-vault-pass
```

**Tags:**
- `pre-check` - Pre-flight checks only
- `updates` - Windows Update tasks
- `chocolatey` - Chocolatey package updates
- `reboot-check` - Reboot requirement checks only
- `security` - Security-related tasks only

### `docker-updates.yml`
Updates Docker images and containers for all configured services.

**Features:**
- Pull latest Docker images
- Update docker-compose services
- Rolling updates (zero-downtime)
- Health check verification

**Usage:**
```bash
ansible-playbook -i ../inventory/hosts.yml playbooks/updates/docker-updates.yml
```

**Tags:**
- `pre-check` - Pre-flight checks only
- `pull` - Pull Docker images
- `update` - Update containers
- `verify` - Health checks

**Configuration:**
Configure Docker images and compose files in `group_vars/all/updates.yml`:
```yaml
docker_update_images:
  - vllm/vllm-openai:latest

docker_update_compose_files:
  - /opt/vllm-motoko/docker-compose.yml

docker_health_checks:
  - url: "http://localhost:8001/health"
    status_code: 200
```

### `app-updates.yml`
Updates application scripts and configuration files.

**Features:**
- PowerShell script updates (Windows)
- Shell script updates (Linux)
- Configuration file updates
- Idempotent (only updates changed files)

**Usage:**
```bash
ansible-playbook -i ../inventory/hosts.yml playbooks/updates/app-updates.yml --ask-vault-pass
```

**Tags:**
- `scripts` - Update application scripts
- `configs` - Update configuration files

**Configuration:**
Configure scripts and configs in `group_vars/all/updates.yml`:
```yaml
app_update_scripts:
  - src: "scripts/Auto-ModeSwitcher.ps1"
    dest: "C:\\Users\\mdt\\dev\\{{ inventory_hostname }}\\scripts\\Auto-ModeSwitcher.ps1"

app_update_configs:
  - src: "templates/config.yml.j2"
    dest: "/etc/app/config.yml"
    mode: "0644"
```

## Configuration

All update settings are configured in `group_vars/all/updates.yml`. See that file for detailed configuration options.

Key settings:
- `update_frequency`: weekly/daily/monthly
- `update_security_only`: true/false
- `update_schedule_day`: Day of week
- `update_schedule_time`: Time (HH:MM)
- `auto_reboot`: false (notify only)
- `update_notification_email`: Email for notifications
- `update_notification_webhook`: Webhook URL for notifications

## Scheduling

Automated scheduling is handled by the `system-updates` role. See the [System Updates Runbook](../../../docs/runbooks/system-updates.md) for details.

## Examples

### Update Everything
```bash
ansible-playbook -i ../inventory/hosts.yml playbooks/updates/all-updates.yml --ask-vault-pass
```

### Update Only Linux Systems
```bash
ansible-playbook -i ../inventory/hosts.yml playbooks/updates/all-updates.yml --tags linux
```

### Update Only Security Patches
```bash
ansible-playbook -i ../inventory/hosts.yml playbooks/updates/all-updates.yml --tags security
```

### Check What Would Be Updated
```bash
ansible-playbook -i ../inventory/hosts.yml playbooks/updates/all-updates.yml --check
```

### Update Specific Host
```bash
ansible-playbook -i ../inventory/hosts.yml playbooks/updates/all-updates.yml --limit motoko --ask-vault-pass
```

### Check Windows Reboot Requirements
```bash
ansible-playbook -i ../inventory/hosts.yml playbooks/updates/windows-updates.yml --tags reboot-check --ask-vault-pass
```

## Safety Features

All playbooks include:
- **Pre-flight checks**: Disk space, service health
- **Idempotency**: Safe to run multiple times
- **Check mode**: Dry-run capability
- **Post-update verification**: Service health checks
- **Detailed reporting**: What was updated and what requires attention

## Related Documentation

- [System Updates Runbook](../../../docs/runbooks/system-updates.md)
- Update configuration: `group_vars/all/updates.yml`
- System updates role: `roles/system-updates/`

