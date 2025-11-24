# PHC Prompt

## Runbook Ordering
1. Storage backplane
2. AI fabric
3. Remote access baseline
4. Service catalog surfacing
5. Ingress/SSO POC
> Note: AI fabric convergence depends on mounted Flux/Space paths and the location of the LiteLLM configuration.

Use this ordering at the top of the PHC prompt to guide assistants and keep execution aligned with the intended sequencing.

---

## Execution Guidance
Follow each phase in order. Do not advance until the preceding phase is validated and handed off.

### 1) Storage backplane
- Validate connectivity and capacity of the storage substrate.
- Confirm data protection policies and replication targets.
- Deliver a ready state signal before AI fabric work begins.
- Before enabling any timers, capture a restore point via snapshot or `restic backup --tag pre-backplane`.

### 2) AI fabric
- Mount Flux/Space paths prior to service bring-up.
- Locate and load the LiteLLM configuration before initializing models.
- Smoke-test orchestration, telemetry, and basic inference pathways.
- Preserve the previous LiteLLM configuration as a `.bak` file and document how to switch back before rolling out changes.

### 3) Remote access baseline
- Establish bastion / jump host access with MFA.
- Verify role scoping and least-privilege entitlements for operators.
- Record access patterns and logging destinations.

### 4) Service catalog surfacing
- Publish available services and APIs through the catalog.
- Annotate operational runbooks, SLOs, and ownership metadata.
- Confirm service discovery works from approved client paths.
- Prepend each entry with a schema block capturing the required fields below so new services stay discoverable and recoverable:

  ```yaml
  name: <service-name>
  owner: <team-or-individual>
  host: <hostname-or-fqdn>
  ingress: <tls/ports/dns>
  auth: <sso/mechanism/scopes>
  data_tier: <storage-layer-and-class>
  backup_policy: <rpo/rto/schedule>
  health_check_url: <http(s)://...>
  status: <green|yellow|red>
  ```

- Example (follow existing YAML indentation/field casing for this repo):

  ```yaml
  name: lite-llm-proxy
  owner: ai-platform
  host: motoko.pangolin-vega.ts.net
  ingress: https://motoko.pangolin-vega.ts.net:4000
  auth: tailscale-identity + api-key
  data_tier: local-ssd (/space) with encrypted-at-rest mount
  backup_policy: restic daily @02:00 with 30d retention
  health_check_url: https://motoko.pangolin-vega.ts.net:4000/health
  status: green
  ```

- Mirror the catalog slices in `docs/product/STATUS.md` with a concise ✅/⚠️/❌ row per component so stakeholders can scan readiness at a glance.

### 5) Ingress/SSO POC
- Prototype ingress with enforced TLS and rate controls.
- Integrate SSO with the selected identity provider and capture claims mapping.
- Document user journey, fallback flows, and audit requirements.
- Enable the new SSO in shadow/sidecar mode first, then cut over DNS once validations are complete.
