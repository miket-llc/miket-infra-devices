# Prevent Tailscale Disconnection - Use Enrollment Keys

## Problem

Motoko (and other servers) keep getting disconnected from Tailscale when other clients make changes. This happens because:

1. **Manual login is fragile** - Requires interactive authentication
2. **No automatic reconnection** - If disconnected, manual intervention needed
3. **Ephemeral keys are better** - As per architecture, servers should use enrollment keys

## Solution: Use Enrollment Keys for Servers

Per the architecture documentation (`docs/reference/tailnet.md`):
> **Key rotation** – Ephemeral auth keys are used for unattended servers; they are renewed via the automation controller at least every 90 days.

### For Motoko (Ansible Control Node)

**Current (Manual Login):**
```bash
sudo tailscale up --advertise-tags=tag:server,tag:linux,tag:ansible --ssh --accept-dns=true --accept-routes=true --advertise-routes=192.168.1.0/24
# Then manually authenticate via browser
```

**Better (Enrollment Key):**
```bash
# Get enrollment key from Terraform
cd ~/miket-infra/infra/tailscale/entra-prod
terraform output enrollment_key

# Use it to connect (no manual authentication needed)
sudo tailscale up \
  --auth-key=$(terraform output -raw enrollment_key) \
  --advertise-tags=tag:server,tag:linux,tag:ansible \
  --ssh \
  --accept-dns=true \
  --accept-routes=true \
  --advertise-routes=192.168.1.0/24
```

### Benefits

1. **No manual authentication** - Works automatically
2. **Resilient to disconnection** - Can reconnect automatically
3. **Follows architecture** - Matches documented best practices
4. **Preauthorized** - No approval needed

### Implementation

Update `scripts/setup-tailscale.sh` to:
1. Check if running on motoko (server)
2. If Terraform is available, try to get enrollment key
3. Use enrollment key if available, fall back to manual login

### Quick Reconnection Script

For now, use `/tmp/quick-reconnect-motoko.sh` to quickly reconnect after disconnection.

## Related Documentation

- [Tailnet Architecture](../reference/tailnet.md)
- [Reconnect Motoko Guide](./reconnect-motoko-tailscale.md)

