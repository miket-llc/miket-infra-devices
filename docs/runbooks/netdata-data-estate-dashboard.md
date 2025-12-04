# Netdata Data Estate Dashboard

## Access

- **Tailscale:** http://motoko:19999 → `data_estate` section
- **Cloudflare:** https://netdata.miket.io (requires Access policy)
- **Netdata Cloud:** https://app.netdata.cloud → Homelab → motoko

## Charts

| Chart | Description |
|-------|-------------|
| `mount_health` | 1=OK, 0=DOWN for /flux, /space, /time |
| `job_age` | Hours since last success per job |
| `slo_compliance` | Overall compliance percentage |
| `recent_failures` | Failure counts in last hour |

## SLO Thresholds

| Job | Warning | Critical |
|-----|---------|----------|
| space-mirror | >24h | >48h |
| flux-backup | >24h | >48h |
| flux-local-snap | >8h | >12h |
| flux-graduate | >6 days | >7 days |

## Quick Troubleshooting

```bash
# Check job status
systemctl status space-mirror flux-backup flux-local flux-graduate

# View failures
tail -50 /var/log/systemd-failures.log

# Check data estate status
cat /space/_ops/data-estate/status.json | jq .

# Run job manually
sudo systemctl start space-mirror.service
```

## Deployment

```bash
cd ~/dev/miket-infra-devices/ansible
ansible-playbook -i inventory/hosts.yml playbooks/deploy-netdata.yml --limit motoko
```

