# Documentation

This directory collects architecture notes, runbooks, and reference material to support operating all managed devices. Each subdirectory should focus on a specific topic so documentation stays easy to navigate.

## Structure

- **`architecture/`** - System design, principles, and architectural decisions
- **`communications/`** - COMMUNICATION_LOG.md (chronological action log)
- **`product/`** - Management documents (STATUS.md, EXECUTION_TRACKER.md, TEAM_ROLES.md)
- **`runbooks/`** - Permanent operational procedures and troubleshooting guides
- **`migration/`** - Migration plans and procedures
- **`archive/`** - Historical documentation (read-only reference)

## Documentation Standards

### Principles

1. **Single Source of Truth** - Each topic documented once, referenced elsewhere
2. **Permanent vs. Ephemeral** - Only permanent docs in this tree; ephemeral content goes in COMMUNICATION_LOG.md
3. **Current State** - STATUS.md, EXECUTION_TRACKER.md, COMMUNICATION_LOG.md updated immediately after actions
4. **No Duplication** - Reference existing docs, don't recreate
5. **Organized by Purpose** - Runbooks for operations, architecture for design, product for management

### What Goes Where

**Point-in-time reports** → `docs/communications/COMMUNICATION_LOG.md` (summarized)
**Operational procedures** → `docs/runbooks/`
**System architecture** → `docs/architecture/` or `docs/product/`
**Current status** → `docs/product/STATUS.md`
**Task tracking** → `docs/product/EXECUTION_TRACKER.md`
**Historical reference** → `docs/archive/` (read-only)

### What NOT to Create

- ❌ Ephemeral .md files in root directory
- ❌ Duplicate status or tracking files
- ❌ Point-in-time reports as separate files
- ❌ Artifact .txt files (log outcomes, delete reports)

See `docs/product/TEAM_ROLES.md` for complete documentation protocols.
