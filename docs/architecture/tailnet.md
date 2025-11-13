# Tailnet Architecture

## Overview
The tailnet connects workstations, servers, and management tooling over the managed Tailscale mesh. Each node authenticates with the organization SSO provider, advertises its IP inside the tailnet, and registers DNS names that match the entries in `ansible/inventory/hosts.yml`. This keeps automation and manual access aligned around a single source of truth.

## Control flow
1. **Device provisioning** – A newly imaged device installs the Tailscale agent, authenticates the owning user, and pulls its ACL tags.
2. **Configuration management** – Ansible targets the device via its stable `*.tailnet-name.ts.net` hostname. Capability-oriented inventory groups (for example `gpu_8gb`) allow playbooks to be restricted to appropriate hardware.
3. **Operational tooling** – Monitoring, remote wake, and self-service scripts operate against tailnet addresses. Grafana and Prometheus scrape exporters on the `100.x.y.z` tailnet IPs, while Wake-on-LAN broadcasts are relayed through a subnet router.
4. **User workflows** – Operators run CLI helpers from the `tools/cli` package or interact through the UI bundle in `tools/ui`, both of which assume tailnet reachability.

## Security model

### Defense in Depth: Network + Device Layers

**Network Layer (Tailscale ACL):**
- Managed in `miket-infra` repository
- Controls routing and access policy at network level
- Example: "Allow mike@miket.io to SSH/RDP to tagged devices"

**Device Layer (Host Firewalls):**
- Managed in `miket-infra-devices` repository
- Windows: Firewall rules restrict RDP to Tailscale subnet (100.64.0.0/10)
- Linux: UFW/firewalld rules restrict SSH/VNC to Tailscale subnet
- Provides protection if network ACL is misconfigured or compromised

**Zero-trust principle:** Both layers must allow traffic. Even if Tailscale ACL is bypassed, device firewalls block unauthorized access.

### Additional Security Controls

- **Device posture** – MFA-backed logins and device keys gate tailnet joins. Enforced auto-updates ensure the Tailscale daemon patches itself.
- **Key rotation** – Ephemeral auth keys are used for unattended servers; they are renewed via the automation controller at least every 90 days.
- **Auditability** – All administrative commands run through tailnet logged endpoints. Syslog and Prometheus remote-write events include the tailnet node key for attribution.

## Future cloud integration
- **Subnet routing to cloud VPCs** – Extend the tailnet with subnet routers inside each cloud VPC so on-premises workstations can reach managed services without public exposure.
- **OIDC federation** – Map tailnet identities to cloud IAM roles. This allows deploying infrastructure via GitHub Actions runners that log in with tailnet devices.
- **Centralized secrets management** – Back Tailnet ACL tags with a cloud secrets backend (e.g., HashiCorp Vault). Devices fetch per-service credentials using their tag grants, eliminating static secrets in inventories.
- **Metrics aggregation** – Use cloud-hosted Prometheus with long-term storage (such as Cortex or Thanos) while keeping tailnet scrapes local, forwarding only aggregated metrics through an egress proxy.
