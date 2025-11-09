# MCP Server Deployment Guide

This guide covers deploying Model Context Protocol (MCP) servers on Motoko using Ansible.

## Overview

MCP servers are deployed as Docker containers managed by Docker Compose. All containers run on a dedicated Docker network (`mcpnet`) and store their data under `/mnt/data/containers/mcp/volumes/`.

## Prerequisites

### Pre-deployment Checks

Before deploying, verify:

```bash
# Check disk space on /mnt/data
df -h /mnt/data

# Verify Docker root directory (should show /mnt/data/docker after deployment)
docker info | grep -i "Docker Root Dir"
```

### Required Collections

Ensure the `community.docker` collection is installed:

```bash
ansible-galaxy collection install community.docker
```

## First-Time Setup

### 1. Create Vault File

Create the encrypted vault file for MCP secrets:

```bash
cd ansible
ansible-vault create group_vars/mcp_hosts.vault.yml
```

Copy the template from `group_vars/mcp_hosts.vault.yml.template` and fill in your actual secrets.

**Alternative:** Copy the template and encrypt it:

```bash
cd ansible
cp group_vars/mcp_hosts.vault.yml.template group_vars/mcp_hosts.vault.yml
# Edit group_vars/mcp_hosts.vault.yml with your secrets
ansible-vault encrypt group_vars/mcp_hosts.vault.yml
```

**Important:** The vault password file should be located at `/etc/ansible/.vault-pass.txt` (configured in `ansible.cfg`).

### 2. Verify Inventory

Ensure `motoko` is in the `mcp_hosts` group in `inventory/hosts.yml`:

```yaml
mcp_hosts:
  hosts:
    motoko:
```

## Deployment

### Image Verification

Before deployment, the playbook will verify that all Docker images exist. If any images are missing, the playbook will fail with instructions to check the Docker MCP Catalog.

To manually verify an image exists:
```bash
docker manifest inspect mcp/<server-name>:latest
```

If an image doesn't exist, you may need to:
1. Check the [Docker MCP Catalog](https://docs.docker.com/ai/mcp-catalog-and-toolkit/catalog/) for the correct image name
2. Build a custom Docker image from the npm package (`@modelcontextprotocol/server-*`)
3. Use a community-built image (verify authenticity)
4. Comment out the server in `group_vars/mcp_hosts.yml` until an official image is available

### Deploy MCP Servers

Run the playbook:

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/mcp.yml
```

The playbook will:
1. Configure Docker daemon to use `/mnt/data/docker` as data-root
2. Create necessary directories and Docker network
3. Render environment file from vault secrets
4. Deploy all MCP servers via Docker Compose

### Idempotency

The playbook is idempotent - you can run it multiple times safely. It will:
- Only restart Docker if `daemon.json` changes
- Only recreate containers if configuration changes
- Pull latest images on each run

## Verification

After deployment, verify everything is working:

```bash
# Verify Docker root directory
docker info | grep -i "Docker Root Dir"
# Should show: Docker Root Dir: /mnt/data/docker

# List volume directories
ls -R /mnt/data/containers/mcp/volumes | head

# Check container status
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep mcp-

# Check all MCP containers
docker ps --filter "name=mcp-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# View logs for a specific service
docker logs mcp-github

# Check Docker network
docker network inspect mcpnet
```

## Configuration

### Adding/Removing Services

Edit `group_vars/mcp_hosts.yml` to modify the `mcp_servers` list:

```yaml
mcp_servers:
  - name: mcp-example
    image: modelcontextprotocol/server-example:latest
    env:
      EXAMPLE_TOKEN: "{{ vault_mcp_env.EXAMPLE_TOKEN }}"
    data_dirs:
      - { name: cache, container_path: /var/lib/mcp }
```

Then re-run the playbook.

### Updating Secrets

Edit the vault file:

```bash
ansible-vault edit group_vars/mcp_hosts.vault.yml
```

Then re-run the playbook to update the environment file and restart containers.

### Port Exposure

By default, MCP servers run on the internal Docker network only. To expose a port:

```yaml
- name: mcp-example
  image: modelcontextprotocol/server-example:latest
  ports:
    - "127.0.0.1:8080:8080"  # Loopback only
  # or
  ports:
    - "8080:8080"  # All interfaces (not recommended)
```

## Troubleshooting

### Containers Not Starting

1. Check container logs:
   ```bash
   docker logs mcp-<service-name>
   ```

2. Verify environment variables:
   ```bash
   docker exec mcp-<service-name> env | grep -i <service>
   ```

3. Check Docker network:
   ```bash
   docker network inspect mcpnet
   ```

### Docker Root Directory Not Changed

If Docker root directory hasn't changed after deployment:

1. Verify `/etc/docker/daemon.json`:
   ```bash
   cat /etc/docker/daemon.json
   ```

2. Check if Docker service restarted:
   ```bash
   systemctl status docker
   ```

3. Manually restart Docker (if needed):
   ```bash
   sudo systemctl restart docker
   ```

### Permission Issues

If you see permission errors:

1. Verify directory ownership:
   ```bash
   ls -la /mnt/data/containers/mcp/
   ```

2. Ensure directories are owned by root:
   ```bash
   sudo chown -R root:root /mnt/data/containers/mcp/
   ```

## Rollback

### Revert Docker Daemon Configuration

If you need to revert the Docker daemon configuration:

```bash
# Restore backup if it exists
if [ -f /etc/docker/daemon.json.bak ]; then
  sudo mv /etc/docker/daemon.json.bak /etc/docker/daemon.json
  sudo systemctl restart docker
fi
```

### Stop All MCP Services

To stop all MCP services:

```bash
cd /mnt/data/containers/mcp
docker compose -f docker-compose.mcp.yml down
```

### Remove All MCP Services

To completely remove all MCP services and data:

```bash
# Stop and remove containers
cd /mnt/data/containers/mcp
docker compose -f docker-compose.mcp.yml down -v

# Remove network
docker network rm mcpnet

# Remove data directories (WARNING: This deletes all data)
sudo rm -rf /mnt/data/containers/mcp
```

## Image Updates

MCP server images are pulled on each playbook run (`pull: always`). To update a specific image:

```bash
docker pull modelcontextprotocol/server-<name>:latest
docker compose -f /mnt/data/containers/mcp/docker-compose.mcp.yml up -d <service-name>
```

## Security Notes

1. **Secrets Management**: All secrets are stored in Ansible Vault and rendered to `/etc/mcp/mcp.env` with `0600` permissions (root-only read).

2. **Network Isolation**: MCP servers run on a dedicated Docker network (`mcpnet`) and are not exposed to the public internet by default.

3. **Port Binding**: Services are configured to bind to loopback (`127.0.0.1`) only unless explicitly configured otherwise.

4. **Access**: Access MCP servers via:
   - SSH tunnel to Motoko
   - Tailscale VPN (if configured)
   - Direct SSH connection

## Maintenance

### Viewing Logs

All containers use JSON file logging with rotation:
- Max size: 10MB per log file
- Max files: 3 per container

View logs:
```bash
# Follow logs
docker logs -f mcp-<service-name>

# View last 100 lines
docker logs --tail 100 mcp-<service-name>
```

### Disk Space Monitoring

Monitor disk usage:

```bash
# Check Docker data usage
du -sh /mnt/data/docker

# Check MCP volumes
du -sh /mnt/data/containers/mcp/volumes/*

# Check log sizes
docker system df
```

### Updating Configuration

After modifying `group_vars/mcp_hosts.yml`, re-run the playbook:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/mcp.yml
```

## Related Documentation

- [Ansible Configuration](../ansible.cfg)
- [Docker Host Role](../roles/docker-host/README.md)
- [MCP Role](../roles/mcp/README.md)

