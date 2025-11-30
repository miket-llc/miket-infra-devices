# Tailnet Reference

The tailnet connects workstations, servers, and automation via Tailscale. Hostnames must mirror Ansible inventory to keep automation and interactive access aligned.

## Control flow
1. **Provisioning:** Install Tailscale, authenticate with **Entra ID**, and apply ACL tags (`tag:server`, `tag:workstation`, `tag:macos`, etc.).
2. **Configuration management:** Ansible targets MagicDNS hostnames (`*.pangolin-vega.ts.net`); capability groups (e.g., `gpu_8gb`) restrict playbook scope.
3. **Operations:** Monitoring and remote tooling reach devices on tailnet IPs; Wake-on-LAN and exporters run over the mesh, not the public internet.
4. **Ingress:** Public traffic terminates at Cloudflare Tunnel + Access on motoko; no device is directly exposed.

## Security model
- **Network layer:** ACLs defined in `miket-infra` enforce least-privilege per tag and user.
- **Device layer:** Host firewalls mirror ACL intent (SSH/RDP/NoMachine limited to tailnet ranges). Both layers must allow traffic.
- **Posture & updates:** Tailscale auto-updates stay enabled; device keys are rotated per Tailscale policy.
- **Auditability:** Administrative access flows through tailnet identities; logs and telemetry include the node identity.

## Integration boundaries
- **Secrets:** Automation identities use AKV-sourced credentials; do not introduce alternate secret stores for tailnet auth.
- **DNS:** MagicDNS names must stay consistent with `ansible/inventory/hosts.yml`.
- **Cloud reach:** If cloud VPC access is required, add subnet routers with ACL-scoped routes via `miket-infra` Terraform.
