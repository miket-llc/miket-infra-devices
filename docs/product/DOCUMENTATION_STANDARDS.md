---
document_title: "miket-infra-devices Documentation Standards"
author: "Codex-DOC-009 (DocOps & EA Librarian)"
last_updated: 2025-11-23
status: Published
related_initiatives:
  - initiatives/device-onboarding
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md#2025-11-23-roadmap-creation
---

# Documentation Standards

Use this guide for every artifact. No Markdown lives outside the documented taxonomy. Update this file when standards change and log the update.

## Taxonomy
- `docs/product/`: Roadmaps, execution trackers, status dashboards, team roles, standards.
- `docs/communications/`: `COMMUNICATION_LOG.md` only (chronological log).
- `docs/initiatives/<initiative>/`: Initiative packages (plans, runbooks, tests) when created.
- `docs/runbooks/`: Permanent operational procedures and troubleshooting guides.
- `docs/reference/`: Durable architecture and control references.
- `docs/guides/`: Targeted troubleshooting or how-to guides.
- `docs/reports/`: Status dashboards and executive communications.
- `docs/architecture/`: Vision, ADRs, architectural guardrails.
- `docs/archive/`: Historical reference (read-only).

## Front Matter (Mandatory)
Every Markdown file MUST start with:

```yaml
---
# Copyright (c) 2025 MikeT LLC. All rights reserved.
document_title: "<title>"
author: "<role or name>"
last_updated: YYYY-MM-DD
status: Draft|In Review|Published
related_initiatives:
  - initiatives/device-onboarding
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md#YYYY-MM-DD-<anchor>
---
```

**Copyright Notice**: All documentation files must include the copyright notice as the first line of front matter: `# Copyright (c) 2025 MikeT LLC. All rights reserved.`

## Consolidation Rules
- Single source of truth per topic; link instead of duplicate.
- No ephemeral Markdown in repo root or ad-hoc folders—summarize in `COMMUNICATION_LOG.md`.
- Initiative content belongs in `docs/initiatives/<name>/` packages.
- Archive deprecated material in `docs/archive/` with context; do not delete history.

## Communication & Tracking Discipline
- Update `COMMUNICATION_LOG.md` within 24 hours for substantive changes with anchor links to artifacts.
- Keep `EXECUTION_TRACKER.md` and `STATUS.md` current after each action.
- DAY0 backlog and roadmap must reference the latest communication log anchor.

## Version Management
- Source of truth: `README.md` **Architecture Version** field.
- Semantic versioning: Major = breaking capability; Minor = new features/modules; Patch = documentation or fixes.
- When version changes: update `README.md`, `docs/product/STATUS.md`, and any referenced deliverable headers; commit message format `release: bump version from v<old> to v<new> with <scope>`.

## Review & Enforcement
- Weekly check: verify new docs have front matter and live in correct directory.
- PR/merge gate: reject changes without communication log entry and tracker updates.
- Chief Architect ensures multi-persona reviews reference the appropriate role documentation before sign-off.
