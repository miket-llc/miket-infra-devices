---
document_title: "miket-infra-devices DAY0 Backlog"
author: "Codex-PM-011 (miket-infra-devices)"
last_updated: 2025-11-23
status: Draft
related_initiatives:
  - initiatives/device-onboarding
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md#2025-11-23-roadmap-creation
  - docs/communications/COMMUNICATION_LOG.md#2025-11-23-wintermute-mounts
---

# DAY0 Backlog (Wave 1 Oriented)

| Task ID | Description | Owner | Dependency | Status | Notes |
|---------|-------------|-------|------------|--------|-------|
| DEV-001 | Obtain Windows vault password and redeploy mounts/sync to wintermute | Codex-WIN-013 | Credential owner (miket-infra) | ✅ Done | Redeployed mounts + OS cloud; verify health writer after logoff/logon |
| DEV-002 | Validate Tailscale ACL alignment + MagicDNS fix for device mounts | Codex-NET-006 | miket-infra ACL/DNS release timeline | ⚠️ Partially Unblocked | ACL alignment verified 2025-11-23; MagicDNS fix remains blocker; LAN fallback operational |
| DEV-003 | Package onboarding/offboarding automation with per-user credential retrieval | Codex-CA-001 | DEV-001 | 🔜 Planned | Must produce audit log + COMMUNICATION_LOG entry |
| DEV-004 | Add CI lint + smoke tests for mounts/remote access playbooks | Codex-PD-002 | None | 🔜 Planned | Include Ansible check-mode + basic connectivity test |
| DEV-005 | Standardize NoMachine client/server configs (NoMachine-only, RDP/VNC retired) | Codex-UX-010 | miket-infra NoMachine server baseline | ✅ **Ready to Execute** | Server baseline delivered 2025-11-22 (v9.2.18-3, port 4000, Tailscale-bound); Wave 2 unblocked |
| DEV-010 | Remove RDP/VNC fallback paths from remote access playbooks | Codex-NET-006 | None | 🔜 Planned | Align with miket-infra architecture decision (RDP/VNC fully retired 2025-11-22) |
| DEV-006 | Define compliance attestations (FileVault/BitLocker/EDR) and evidence storage | Codex-SEC-004 | Entra compliance feed | 🔜 Planned | Store evidence under `/space/devices/<host>/compliance` |
| DEV-007 | Map Cloudflare Access + device personas for remote app access | Codex-SEC-004 | miket-infra Access matrix | 🔜 Planned | Align with Wave 2 rollout |
| DEV-008 | Publish Azure Monitor/observability plan for mounts/sync/remote access | Codex-SRE-005 | miket-infra workspace IDs | 🔜 Planned | Targets Wave 3 |
| DEV-009 | UX instrumentation & survey for remote access TTFD/NPS | Codex-UX-010 | None | 🔜 Planned | Targets Wave 4 optimization |
| DEV-010 | Remove RDP/VNC fallback paths from remote access playbooks and documentation | Codex-NET-006 | None | 🚧 **In Progress** | Align with miket-infra architecture decision (RDP/VNC fully retired 2025-11-22); NoMachine is SOLE remote desktop solution |
| DEV-011 | Test macOS NoMachine client connectivity from count-zero | Codex-MAC-012 | DEV-005 (server baseline) | 🚧 **In Progress** | End-to-end validation: count-zero → motoko/wintermute/armitage on port 4000 via Tailscale |
| DEV-012 | Coordinate NoMachine client testing and MagicDNS fix timeline with miket-infra | Codex-PM-011 | None | 🚧 **In Progress** | Request MagicDNS fix ETA, coordinate client testing, request Wave 2 deliverables timeline |
