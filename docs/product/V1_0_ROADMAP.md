---
document_title: "miket-infra-devices v1.0 Roadmap"
author: "Codex-PM-011 (miket-infra-devices)"
last_updated: 2025-11-23
version: v1.7.0
status: Draft
related_initiatives:
  - initiatives/device-onboarding
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md#2025-11-23-roadmap-creation
---

# miket-infra-devices v1.0 Roadmap

## Executive Overview
- **Current state:** Client-side mounts, OS cloud sync, and devices view are operational on macOS and Windows (wintermute pending vault credentials). Tailscale connectivity and data lifecycle controls are stable via miket-infra.
- **Vision:** Deliver a consistent, compliant device platform aligned to miket-infra v2.0 so that onboarding/offboarding is zero-touch, remote access is predictable, and compliance evidence is continuously generated.
- **Key outcomes:** 100% of devices enrolled with validated mounts, compliant remote access paths (NoMachine + Tailscale/Cloudflare), and measurable UX health; device telemetry and compliance proof aligned to miket-infra observability and Entra CA.

## Completed
- Deployed cross-platform mounts (macOS `~/.mkt/*` + symlinks, Windows `X:/S:/T:`) with loop prevention and OS cloud sync to `/space/devices`.
- Server-side `/space/devices` structure live with user-facing symlinks; validation playbooks available.
- Documentation standards established (single-source model, communication log discipline).
- GNOME freeze remediation, watchdog deployment, and data lifecycle automation completed on motoko.
- Lessons learned: enforce device credentials early (vault), use LAN/Tailscale fallback paths, keep remote access UX unified (NoMachine over RDP where possible).

## Objectives & Key Results (OKRs)
- **O1: Zero-touch device onboarding/offboarding**
  - KR1: 100% of devices onboarded via single playbook with per-user credential retrieval (no manual drive mapping) by 2025-12-31.
  - KR2: Offboarding automation removes mounts, secrets, and scheduled tasks within 30 minutes of trigger with audit log in COMMUNICATION_LOG.
  - KR3: Device ACL alignment verified against miket-infra Tailscale policy for every wave with automated validation playbook.
- **O2: Endpoint security posture**
  - KR1: Full-disk encryption attested for macOS and Windows endpoints; evidence stored in `/space/devices/<host>/compliance` by 2025-12-15.
  - KR2: Antivirus/EDR baseline documented and enforced; weekly compliance report emitted to miket-infra observability sink.
  - KR3: Entra ID device compliance checks integrated; conditional access passes for 100% managed devices.
- **O3: Remote access UX (NoMachine + Tailscale SSH/RDP fallback)**
  - KR1: NoMachine client/server standardization deployed to all platforms with <2% connection failure rate in weekly tests.
  - KR2: Tailscale ACLs and Cloudflare Access policies mapped for device personas; drift checks run weekly.
  - KR3: Median first-connection time under 90 seconds for new device after onboarding.
- **O4: Compliance, monitoring, and observability**
  - KR1: Azure Monitor log shipping live for device agents with dashboards for mounts, sync, and remote-access health by 2026-01-15.
  - KR2: Alerting/runbook links for top 5 device failure modes published in docs/runbooks with tested remediation steps.
  - KR3: EXECUTION_TRACKER and COMMUNICATION_LOG updates within 24 hours for 100% roadmap changes.

## Dependency Sequencing
| Wave | Timeframe | Focus Area | Critical Dependencies | Owners |
|------|-----------|------------|-----------------------|--------|
| Wave 1 | 2025-11 → 2025-12 | Device onboarding automation + credential unblocks | miket-infra: Tailscale ACL freeze dates; Entra ID device compliance signals; Windows vault password availability | Codex-CA-001, Codex-PM-011 |
| Wave 2 | 2025-12 → 2026-01 | Remote access UX (NoMachine first), Cloudflare Access alignment | miket-infra: NoMachine server config + ACLs; Cloudflare Access posture; updated LiteLLM/L4 routing | Codex-NET-006, Codex-UX-010 |
| Wave 3 | 2026-01 → 2026-02 | Compliance + observability (Azure Monitor, alerting, runbooks) | miket-infra: Observability pipelines and dashboards; audit log retention; Entra/Conditional Access policies | Codex-SEC-004, Codex-SRE-005 |
| Wave 4 | 2026-02 → 2026-03 | Optimization & UX polish (automation hardening, onboarding TTFD) | miket-infra: Platform v2.0 release cadence; change freeze windows; budget approvals | Codex-PD-002, Codex-FIN-008 |

## Wave Planning Updates
- **Wave 1 (Onboarding & credentials)** ✅ **COMPLETE** (2025-11-23, v1.7.0)
  - Actions: unblock Windows vault credentials; tighten mount validation; create per-device kickoff checklist; validate Tailscale ACL alignment.  
  - Dependencies discovered: MagicDNS fix from miket-infra; Entra device compliance feed format; vault password owner for wintermute.
  - **Completed:** RDP/VNC cleanup (DEV-010), NoMachine client standardization (DEV-005), NoMachine E2E testing (DEV-011), smoke tests, documentation updates.
  - **Status:** Wave 1 release criteria met. Ready for Wave 2.
- **Wave 2 (Remote access UX)** 🚧 **READY TO START**
  - Actions: Cloudflare Access mapping for device personas; remote app policies (NoMachine, SSH); certificate enrollment; Tailscale ACL drift checks.
  - Dependencies discovered: NoMachine server images and firewall baselines from miket-infra → **DELIVERED 2025-11-22** (v9.2.18-3, port 4000); Cloudflare Access mapping for device apps (pending Wave 2).
- **Wave 3 (Compliance & observability)**  
  - Actions: ship Azure Monitor agent configs; define SLOs for mounts/sync; implement alerting to Ops channel; publish runbooks.  
  - Dependencies discovered: Azure Monitor workspace IDs and ingestion rules; miket-infra dashboards for shared view.
- **Wave 4 (Optimization)**  
  - Actions: reduce onboarding TTFD <30 minutes; add automated regression tests for mounts/remote access; cost controls for NoMachine licensing.  
  - Dependencies discovered: Budget approval cycle; platform v2.0 freeze windows.

## Release Criteria (Exit Checklist)
- **Wave 1:** Credentialless playbook runs across macOS/Windows with zero manual steps; Tailscale ACL validation job green; COMMUNICATION_LOG entry filed with evidence.  
- **Wave 2:** NoMachine + Tailscale remote access tested across all devices; fallback path documented; <2% failure in weekly smoke tests.  
- **Wave 3:** Azure Monitor dashboards live; alerting bound to runbooks; compliance evidence stored per device; EXECUTION_TRACKER links populated.  
- **Wave 4:** Onboarding/offboarding TTFD <30 minutes; regression suite automated in CI; UX survey NPS ≥ 8 for remote access.

## Governance & Reporting
- **Cadence:** Weekly alignment with miket-infra (review COMMUNICATION_LOG + EXECUTION_TRACKER); monthly deep review of roadmap vs miket-infra v2.0 waves; quarterly strategic review to refresh OKRs.  
- **Artifacts:** Every change updates COMMUNICATION_LOG within 24 hours; EXECUTION_TRACKER reflects agent status; DAY0_BACKLOG tracks tasks with dependencies; roadmap version increments per semantic versioning.  
- **Risk management:** Track blockers in EXECUTION_TRACKER; elevate cross-repo dependencies early (Tailscale ACLs, Entra compliance, Cloudflare Access). No deployment without passing release criteria for the active wave.
- **Alignment Protocol:** Follow [ROADMAP_ALIGNMENT_PROTOCOL.md](./ROADMAP_ALIGNMENT_PROTOCOL.md) for cross-project validation checklists, review templates, escalation paths, and integration point verification.
