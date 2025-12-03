# Netdata Data Estate Dashboard

**Last Updated:** 2025-12-03  
**Author:** AI Assistant  
**Scope:** motoko data estate monitoring via Netdata

## Overview

The Data Estate Dashboard provides visibility into the health and status of the PHC (Personal Home Cloud) storage infrastructure on motoko. It surfaces metrics from the data-estate-status collector and systemd failure notifications into the Netdata UI.

## Accessing the Dashboard

### Primary: Netdata Cloud

1. Go to https://app.netdata.cloud
2. Navigate to the **Homelab** space
3. Select **motoko** from the node list
4. The Data Estate charts appear in the **data_estate** section

### Secondary: Local Dashboard (break-glass)

1. SSH to motoko or connect via Tailscale
2. Access http://motoko:19999 or http://100.x.x.x:19999 (Tailscale IP)
3. Navigate to the **data_estate** section in the left menu

## Dashboard Sections

### 1. Mount Health (`data_estate.mount_health`)

Shows real-time mount status for the three data estate volumes:

| Mount    | Expected State | Description |
|----------|---------------|-------------|
| `/flux`  | 1 (mounted)   | Active working data volume |
| `/space` | 1 (mounted)   | System of Record (SoR) - primary storage |
| `/time`  | 1 (mounted)   | Time Machine / backup target (optional) |

**Values:**
- `1` = Mount healthy and accessible
- `0` = Mount unavailable or inaccessible

**Actions when unhealthy:**
- Check `mount` output on motoko
- Review `dmesg` for disk errors
- Check `systemctl status` for automount units
- Verify cables/hardware if persistent

### 2. Job Age (`data_estate.job_age`)

Shows hours since each data lifecycle job last succeeded:

| Job | SLO (Critical) | Warning | Description |
|-----|---------------|---------|-------------|
| `space-mirror` | 48h | 24h | rclone sync /space → B2 |
| `flux-backup` | 48h | 24h | restic backup /flux → B2 |
| `flux-local-snap` | 12h | 8h | Local restic snapshot |
| `flux-graduate` | 168h (7d) | 144h (6d) | Weekly /flux → /space graduation |

**Interpreting values:**
- `-1` = No successful run recorded (check markers/journal)
- `0-N` = Hours since last success

**Actions when stale:**
```bash
# Check job status
systemctl status space-mirror.service
systemctl status flux-backup.service

# View recent logs
journalctl -u space-mirror.service -n 50

# Check marker files
cat /space/_ops/data-estate/markers/b2_mirror.json
cat /space/_ops/data-estate/markers/restic_cloud.json

# Run job manually (as root)
systemctl start space-mirror.service
```

### 3. SLO Compliance (`data_estate.slo_compliance`)

Shows overall SLO compliance as a percentage:

| Value | Status | Action |
|-------|--------|--------|
| 80-100% | Healthy | No action needed |
| 60-79% | Warning | Investigate stale jobs |
| 0-59% | Critical | Multiple jobs failing - urgent |

The percentage is calculated from the data-estate-status.sh collector which runs every 6 hours.

### 4. Recent Failures (`data_estate.failures`)

Counts of failures per job in the last 60 minutes:

| Metric | Description |
|--------|-------------|
| `space-mirror` | space-mirror.service failures |
| `flux-backup` | flux-backup.service failures |
| `flux-local-snap` | flux-local.service failures |
| `flux-graduate` | flux-graduate.service failures |
| `total` | Sum of all failures |

**Actions when elevated:**
```bash
# Review failure log
tail -50 /var/log/systemd-failures.log

# Check specific unit
systemctl status <service-name>
journalctl -u <service-name> --since "1 hour ago"
```

## Alarms

The following alarms are configured:

### Mount Alarms
| Alarm | Trigger | Severity |
|-------|---------|----------|
| `data_estate_flux_unmounted` | /flux unavailable | Critical |
| `data_estate_space_unmounted` | /space unavailable | Critical |
| `data_estate_time_unmounted` | /time unavailable | Warning (silent) |

### Job Freshness Alarms
| Alarm | Warning | Critical |
|-------|---------|----------|
| `data_estate_space_mirror_stale` | >24h | >48h |
| `data_estate_flux_backup_stale` | >36h | >48h |
| `data_estate_flux_local_stale` | >8h | >12h |
| `data_estate_flux_graduate_stale` | >144h (6d) | >168h (7d) |

### SLO Compliance Alarm
| Alarm | Warning | Critical |
|-------|---------|----------|
| `data_estate_slo_compliance_low` | <80% | <60% |

### Failure Count Alarm
| Alarm | Warning | Critical |
|-------|---------|----------|
| `data_estate_failures_elevated` | ≥2/hour | ≥5/hour |

### Disk Usage Alarms
| Alarm | Warning | Critical |
|-------|---------|----------|
| `data_estate_disk_flux_usage` | >80% | >90% |
| `data_estate_disk_space_usage` | >80% | >90% |
| `data_estate_disk_time_usage` | >80% | >90% |

## Example: Healthy State

When the data estate is healthy, you should see:

```
Mount Health:
  flux: 1
  space: 1
  time: 1

Job Age (hours):
  space-mirror: 2
  flux-backup: 8
  flux-local-snap: 1
  flux-graduate: 36

SLO Compliance: 100%

Recent Failures: 0 (all jobs)
```

## Example: Degraded State (After Deliberate Failure)

To test alerting, you can deliberately cause a failure:

```bash
# Trigger a one-time failure (as root)
systemctl stop flux-local.service
echo "exit 1" | sudo tee /tmp/fail-test.sh
sudo chmod +x /tmp/fail-test.sh
sudo systemd-run --unit=flux-local-test --on-failure=failure-notify@flux-local-test.service /tmp/fail-test.sh
```

After the failure, you should see:

```
Recent Failures:
  flux-local-snap: 0 (test unit is different)
  total: 1

# Or check the failure log
$ tail /var/log/systemd-failures.log
[2025-12-03T10:00:00+00:00] FAILURE: flux-local-test failed on motoko
```

The `data_estate_failures_elevated` alarm will fire if failures accumulate.

## Troubleshooting

### Charts not appearing

1. Check if the collector is running:
   ```bash
   curl -s localhost:19999/api/v1/charts | jq '.charts | to_entries[] | select(.key | startswith("data_estate"))'
   ```

2. Check collector logs:
   ```bash
   journalctl -u netdata -n 100 | grep -i data_estate
   ```

3. Verify collector is deployed:
   ```bash
   ls -la /usr/libexec/netdata/python.d/data_estate.chart.py
   cat /etc/netdata/python.d/data_estate.conf
   ```

### Data showing -1 for job ages

This means no successful run was recorded. Check:

1. Marker files exist:
   ```bash
   ls -la /space/_ops/data-estate/markers/
   ```

2. Status JSON is current:
   ```bash
   cat /space/_ops/data-estate/status.json | jq .
   ```

3. Timers are active:
   ```bash
   systemctl list-timers | grep -E "(space-mirror|flux-)"
   ```

### Alarms not firing

1. Check health config is loaded:
   ```bash
   curl -s localhost:19999/api/v1/alarms | jq '.alarms | to_entries[] | select(.key | startswith("data_estate"))'
   ```

2. Verify alarm file:
   ```bash
   cat /etc/netdata/health.d/data_estate.conf
   ```

3. Restart netdata if needed:
   ```bash
   sudo systemctl restart netdata
   ```

## Deployment

The Data Estate dashboard is deployed via Ansible:

```bash
# From motoko or control node
ansible-playbook -i inventory/hosts.yml playbooks/deploy-netdata.yml --limit motoko

# Or just run the netdata role
ansible-playbook -i inventory/hosts.yml playbooks/deploy-netdata.yml --limit motoko --tags "data_estate"
```

## Related Documentation

- [Data Estate Status Collector](/docs/runbooks/data-estate-status.md)
- [Motoko Disk Maintenance](/docs/runbooks/motoko-disk-maintenance.md)
- [Netdata Troubleshooting](/docs/runbooks/netdata-troubleshooting.md)

