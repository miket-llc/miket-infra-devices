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
- **Documentation Standards:**
  - **NO ephemeral .md files** - Point-in-time reports belong in COMMUNICATION_LOG.md, not root-level files
  - **NO duplicate documentation** - Single source of truth for each topic
  - **Runbooks are permanent** - Located in `docs/runbooks/` with descriptive names
  - **Architecture docs are permanent** - Located in `docs/architecture/` or `docs/product/`
  - **Status is current** - STATUS.md, EXECUTION_TRACKER.md, COMMUNICATION_LOG.md updated immediately after actions
  - **Artifacts are logged, not stored** - Deployment reports summarized in COMMUNICATION_LOG.md, not stored as .txt files
  - **Root directory is clean** - Only README.md and essential guides in root; all else organized in docs/

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

## Documentation Protocols

### What to Document Where

**COMMUNICATION_LOG.md** (`docs/communications/`):
- All agent actions and decisions (chronological)
- Point-in-time deployment reports (summarized, not full dumps)
- Incident reports (summary format, detailed runbooks referenced)
- Status changes and resolutions

**EXECUTION_TRACKER.md** (`docs/product/`):
- Current agent status and deliverables
- Task completion tracking
- Blockers and dependencies

**STATUS.md** (`docs/product/`):
- Current infrastructure state (operational/not operational)
- Critical issues requiring attention
- Device inventory status

**Runbooks** (`docs/runbooks/`):
- Permanent operational procedures
- Troubleshooting guides
- Setup instructions
- Recovery procedures

**Architecture Docs** (`docs/architecture/`, `docs/product/`):
- System design and principles
- Handoff documents
- Specifications

### What NOT to Create

- ❌ **Ephemeral .md files in root** - Use COMMUNICATION_LOG.md instead
- ❌ **Duplicate documentation** - Reference existing docs, don't recreate
- ❌ **Point-in-time reports as files** - Summarize in COMMUNICATION_LOG.md
- ❌ **Artifact .txt files** - Log key outcomes, delete detailed reports
- ❌ **Status files that duplicate STATUS.md** - Update STATUS.md instead
- ❌ **Incident reports as separate files** - Use COMMUNICATION_LOG.md with runbook references

### Documentation Lifecycle

1. **Create**: Only permanent, reusable documentation (runbooks, architecture)
2. **Update**: Keep STATUS.md, EXECUTION_TRACKER.md, COMMUNICATION_LOG.md current
3. **Archive**: Move obsolete docs to `docs/archive/` (don't delete historical context)
4. **Delete**: Remove truly ephemeral files (point-in-time reports, duplicate status files)
5. **Consolidate**: Merge duplicate or overlapping documentation

## RACI Summary

- **Responsible:** Individual agents per domain as outlined above
- **Accountable:** Chief Device Architect for technical execution
- **Consulted:** miket-infra Chief Architect for network policy changes
- **Informed:** CEO via STATUS.md updates and COMMUNICATION_LOG.md entries

