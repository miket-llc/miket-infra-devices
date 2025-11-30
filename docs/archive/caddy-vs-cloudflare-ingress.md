# Caddy + OIDC vs. Cloudflare Tunnel for device ingress

> **Archived:** Cloudflare Tunnel + Access with Entra SSO is now the mandatory ingress pattern per `docs/architecture/PHC_VNEXT_ARCHITECTURE.md`. This comparison is kept for historical context only.

## Quick comparison

| Area | Caddy + OIDC (Entra) on tailnet | Cloudflare Tunnel |
| --- | --- | --- |
| Operational burden | Runs on existing nodes; single binary and OIDC config; tailnet ACLs already in place. | Managed tunnel lifecycle; requires Cloudflare account, connector, and DNS wiring. |
| Latency | Direct tailnet path; no extra middlebox. | Traffic hairpins through Cloudflare POP before reaching the device. |
| Offline mode | Works as long as tailnet is reachable (peer-to-peer or DERP). | Fails closed if tunnel agent cannot reach Cloudflare. |
| Secret handling | OIDC client secret stored locally; can use Tailscale node ACL scoping and file permissions. | Tunnel credentials stored on node and in Cloudflare; JWT-style service tokens for app-level auth. |

## Recommendation

Start with **Caddy + Entra over the tailnet** for private ingress. If later needed, layer **Cloudflare Tunnel** for selective public ingress (e.g., limited paths or hosts) while keeping Caddy as the origin terminator.

## Proof-of-concept scope

- Configure a single Caddy instance on the tailnet to terminate HTTPS and enforce Entra OIDC for one device-facing app.
- Keep DNS/Tailscale MagicDNS scoped to internal consumers; no public DNS while validating the flow.
- Monitor logs for auth flow, TLS handshakes, and tailnet routing to confirm stability.

## Rollback plan

Toggle the site block in the Caddy config (comment out or disable the relevant server block) and reload Caddy to revert to the previous access pattern.
