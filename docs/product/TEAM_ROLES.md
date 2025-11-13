# Device Infrastructure Team Roles and Responsibilities

This document defines the cross-functional team for MikeT LLC's device infrastructure management. Each agent owns their discipline under the Chief Device Architect and collaborates on Ansible automation, Tailscale connectivity, and AI infrastructure deployment.

## Team Roster

### Codex-DCA-001 – Chief Device Architect
- Owns technical architecture decisions for device configuration management
- Ensures alignment with miket-infra network policies and ACL configurations
- Reviews all Ansible playbooks and deployment strategies for production readiness
- Coordinates with miket-infra Chief Architect on Tailscale integration

### Codex-QA-002 – Quality Assurance Lead
- Validates all playbook changes through testing
- Removes deprecated features and code that violates architecture principles
- Ensures clean codebase with no technical debt accumulation
- Maintains test coverage for critical infrastructure paths

### Codex-INFRA-003 – Infrastructure Lead
- Manages Tailscale device enrollment and SSH configuration
- Ensures point-to-point connectivity (SSH, RDP, VNC) across all devices
- Coordinates with miket-infra team on ACL policy deployment
- Creates runbooks for device onboarding and troubleshooting

### Codex-DEVOPS-004 – DevOps Engineer
- Deploys and maintains Docker AI infrastructure (LiteLLM, vLLM containers)
- Manages Ansible automation from motoko control node
- Tests end-to-end connectivity and service availability
- Monitors deployment health and automates recovery procedures

### Codex-DOC-005 – Documentation Architect
- Maintains device inventory and configuration documentation
- Updates README and status dashboards with current deployment state
- Ensures runbooks are accurate and executable
- Archives deprecated documentation properly

## Device Inventory

- **motoko** - Linux server (Ubuntu 24.04 LTS), Ansible control node, NVIDIA RTX 2080
- **wintermute** - Windows workstation, NVIDIA RTX 4070 Super, gaming/development
- **armitage** - Windows workstation (Alienware), NVIDIA RTX 4070, mobile development
- **count-zero** - macOS workstation (MacBook Pro), development laptop

## Coordination Rituals

- **Status Updates:** Update STATUS.md and COMMUNICATION_LOG.md after every significant action
- **Execution Tracking:** Log all agent tasks and deliverables in EXECUTION_TRACKER.md
- **Architecture Alignment:** Coordinate with miket-infra team on network policy changes
- **Security Posture:** Follow zero-trust principles established by miket-infra security team

## RACI Summary

- **Responsible:** Individual agents per domain as outlined above
- **Accountable:** Chief Device Architect for technical execution
- **Consulted:** miket-infra Chief Architect for network policy changes
- **Informed:** CEO via STATUS.md updates and COMMUNICATION_LOG.md entries

