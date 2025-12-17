# Monitoring (Prometheus/Grafana) Runbook

## Overview

PHC monitoring uses a Prometheus + Grafana stack deployed on Akira, with node_exporter on all Linux servers. This replaces the previous Netdata Cloud setup with a self-hosted, low-maintenance solution.

## Architecture

```
                    ┌─────────────────────────────────────────────┐
                    │               AKIRA                         │
                    │  ┌─────────────┐  ┌─────────────┐           │
                    │  │ Prometheus  │──│  Grafana    │           │
                    │  │   :9090     │  │   :3000     │           │
                    │  └─────┬───────┘  └─────────────┘           │
                    │        │                                     │
                    │  ┌─────┴───────┐                            │
                    │  │  Blackbox   │ HTTP probes                │
                    │  │   :9115     │ (nextcloud.miket.io)       │
                    │  └─────────────┘                            │
                    └─────────────────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          │                   │                   │
    ┌─────┴─────┐       ┌─────┴─────┐       ┌─────┴─────┐
    │  motoko   │       │   atom    │       │ armitage  │
    │   :9100   │       │   :9100   │       │   :9100   │
    │node_export│       │node_export│       │node_export│
    └───────────┘       └───────────┘       └───────────┘
```

## Access

All access is restricted to the Tailnet (100.64.0.0/10).

| Service    | URL                                       | Notes                    |
|------------|-------------------------------------------|--------------------------|
| Grafana    | http://akira.pangolin-vega.ts.net:3000    | Primary UI               |
| Prometheus | http://akira.pangolin-vega.ts.net:9090    | Query/targets            |
| Blackbox   | http://akira.pangolin-vega.ts.net:9115    | HTTP probe metrics       |

### Grafana Login

- **Anonymous access**: Enabled (read-only Viewer role)
- **Admin access**: `admin` / password in `/flux/runtime/secrets/grafana.env`

## Dashboards

Three dashboards are provisioned automatically:

1. **PHC Node Exporter** - CPU, memory, disk, network for all Linux hosts
2. **PHC HTTP Endpoints** - Uptime, latency, SSL expiry for Nextcloud
3. **PHC Prometheus Stats** - Scrape targets, TSDB storage, series count

Dashboards are read-only (provisioned as code). To modify, edit the JSON templates in:
```
ansible/roles/observability_stack/templates/dashboards/
```

## Common Tasks

### Add a New Linux Host

1. Add host to `monitoring_exporters` group in `ansible/inventory/hosts.yml`:
   ```yaml
   monitoring_exporters:
     hosts:
       new-host:
   ```

2. Add to Prometheus targets in `ansible/roles/observability_stack/defaults/main.yml`:
   ```yaml
   prometheus_node_exporter_targets:
     - name: new-host
       address: "new-host.pangolin-vega.ts.net:9100"
   ```

3. Deploy:
   ```bash
   make deploy-observability
   ```

### Add a New HTTP Probe

1. Edit `ansible/roles/observability_stack/defaults/main.yml`:
   ```yaml
   blackbox_http_targets:
     - name: my_service
       url: "https://my-service.example.com/health"
       module: http_2xx
   ```

2. Deploy:
   ```bash
   ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/deploy-observability.yml --tags stack --limit akira
   ```

### Check Target Status

```bash
# From any host on tailnet
curl -s http://akira.pangolin-vega.ts.net:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, instance: .labels.instance, health: .health}'
```

### Restart the Stack

```bash
# On Akira
sudo systemctl restart observability-stack

# Or via docker compose
cd /flux/apps/observability
sudo podman compose restart
```

### View Container Logs

```bash
# On Akira
sudo podman logs prometheus
sudo podman logs grafana
sudo podman logs blackbox
```

## Verification

### After Deployment

Run validation:
```bash
make validate-observability
```

Or manually verify:

1. **Prometheus targets up**:
   ```bash
   curl -s http://akira.pangolin-vega.ts.net:9090/api/v1/targets | jq '.data.activeTargets[] | select(.health == "up")'
   ```

2. **Grafana responding**:
   ```bash
   curl -s http://akira.pangolin-vega.ts.net:3000/api/health
   ```

3. **node_exporter on each host**:
   ```bash
   curl -s http://motoko.pangolin-vega.ts.net:9100/metrics | head -5
   ```

### Network Access Verification

From a non-tailnet network, these should fail:
```bash
curl --connect-timeout 5 http://akira.pangolin-vega.ts.net:3000  # Should timeout
curl --connect-timeout 5 http://motoko.pangolin-vega.ts.net:9100  # Should timeout
```

## Troubleshooting

### Prometheus Target Down

1. Check if node_exporter is running:
   ```bash
   ssh motoko 'systemctl status node_exporter'
   ```

2. Check firewall:
   ```bash
   ssh motoko 'sudo firewall-cmd --list-rich-rules | grep 9100'
   ```

3. Test connectivity from Akira:
   ```bash
   curl -v http://motoko.pangolin-vega.ts.net:9100/metrics
   ```

### Grafana Dashboard Empty

1. Check Prometheus is scraping:
   - Go to Prometheus UI → Status → Targets
   - Verify targets show "UP"

2. Check datasource:
   - Grafana → Settings → Data sources → Prometheus
   - Click "Test" button

### Stack Won't Start

1. Check systemd:
   ```bash
   sudo systemctl status observability-stack
   sudo journalctl -u observability-stack -n 50
   ```

2. Check container health:
   ```bash
   cd /flux/apps/observability
   sudo podman compose ps
   sudo podman compose logs
   ```

3. Check disk space:
   ```bash
   df -h /flux
   ```

## Storage

| Path | Purpose | Retention |
|------|---------|-----------|
| `/flux/apps/observability/prometheus/data` | Prometheus TSDB | 15 days |
| `/flux/apps/observability/grafana/data` | Grafana SQLite DB | Indefinite |
| `/space/_services/observability/` | Config backups | Indefinite |

Prometheus retention is configured in `docker-compose.yml`:
- `--storage.tsdb.retention.time=15d`
- `--storage.tsdb.retention.size=10GB`

## Ports and Firewall

| Port | Service | Allowed From |
|------|---------|--------------|
| 9090 | Prometheus | 100.64.0.0/10 (Tailnet) |
| 3000 | Grafana | 100.64.0.0/10 (Tailnet) |
| 9115 | Blackbox | 100.64.0.0/10 (Tailnet) |
| 9100 | node_exporter | 100.64.0.0/10 (Tailnet) |

## Related Documentation

- Ansible roles: `ansible/roles/observability_stack/`, `ansible/roles/observability_exporters/`
- Playbook: `ansible/playbooks/deploy-observability.yml`
- Secrets: `ansible/secrets-map.yml` (grafana entry)
