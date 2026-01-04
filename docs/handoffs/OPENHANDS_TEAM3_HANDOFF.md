# Handoff Prompt: miket-infra-devices → chezmoi / DX Team

**From:** Team 2 (miket-infra-devices - Device Provisioning)
**To:** Team 3 (chezmoi / DX / Docs)
**Date:** 2025-12-23
**Status:** ✅ IMPLEMENTATION COMPLETE

---

## YOU MAY IMPLEMENT THE FOLLOWING (OPTIONAL)

Team 2 has deployed LLM client tools and OpenHands across the device fleet.
No chezmoi changes are required for basic functionality.

This handoff identifies opportunities for DX improvements that you MAY implement if beneficial.

---

## WHAT WAS DEPLOYED

### Wrapper Commands Added

| Command | Location | Purpose |
|---------|----------|---------|
| `llm-env` | `/usr/local/bin/llm-env` | LLM environment wrapper |
| `oh` | `/usr/local/bin/oh` | OpenHands wrapper |
| `llm-doctor` | `/usr/local/bin/llm-doctor` | Diagnostics |

### Configuration Files

| Path | Purpose |
|------|---------|
| `/etc/miket/llm/contract.json` | LLM Contract (roles, gateway URL) |
| `/etc/miket/llm/README.md` | Configuration documentation |

### User-Level Files

| Path | Purpose |
|------|---------|
| `~/.local/bin/openhands` | OpenHands CLI (via uv) |
| `~/.openhands/config.toml` | Optional user config |

---

## CONFIRMATION: NO DOTFILES MODIFIED

Team 2 did NOT modify any chezmoi-managed files:
- No changes to `~/.bashrc`, `~/.zshrc`, `~/.profile`
- No changes to `~/.config/*`
- No shell aliases or functions added
- All tools installed to system paths (`/usr/local/bin/`)

---

## POTENTIAL DX IMPROVEMENTS (YOUR DECISION)

### Option A: No Changes (Recommended)

The current implementation is functional without chezmoi integration:
- Commands are in PATH via `/usr/local/bin/`
- No aliases needed (commands are short: `oh`, `llm-env`)
- No completions exist upstream yet

**Recommendation:** Document in onboarding only.

### Option B: Shell Completions (Low Priority)

If/when OpenHands or llm-env gain shell completion support:
- Add completion scripts to chezmoi as opt-in
- Pattern: `~/.config/zsh/completions/_oh`

**Status:** Not available upstream. Defer.

### Option C: Prompt Integration (Consider Carefully)

A prompt segment showing current LLM role could be useful:
- Only if `LLM_MODEL` is set in environment
- Performance impact must be negligible

**Recommendation:** Defer unless users request. The role is typically transient (set per command, not per shell session).

### Option D: Convenience Aliases (Not Recommended)

Aliases like `ohs` for `oh serve` add little value:
- Commands are already short
- Would need to be documented
- Creates chezmoi coupling

**Recommendation:** Do not add.

---

## WHAT TO DOCUMENT

### Onboarding Updates

Add to onboarding docs:

```markdown
## AI Development Tools

OpenHands is available on all workstations. Quick start:

    oh serve                # Start OpenHands GUI
    oh serve --mount-cwd    # With current directory mounted
    llm-doctor              # Run diagnostics

See: docs/runbooks/OPENHANDS_USAGE.md
```

### Developer Hub (if applicable)

Add link to:
- `docs/runbooks/OPENHANDS_USAGE.md`
- `docs/reference/LLM_CLIENT_STANDARD.md`

---

## OS-SPECIFIC CAVEATS

### macOS (count-zero)

- Requires Docker Desktop (not installed by Ansible)
- User must start Docker Desktop manually
- Command: `open -a Docker` before `oh serve`

### Windows (wintermute)

- Native Windows deferred
- Use WSL2 with Linux configuration
- Document WSL2 setup in `docs/runbooks/wsl2-standardization.md`

### Linux (armitage, akira, atom)

- Uses Podman (installed automatically)
- No additional user action needed

---

## KNOWN FRICTION POINTS

| Issue | Belongs To | Status |
|-------|------------|--------|
| macOS requires manual Docker start | User/DX | Document only |
| No shell completions | Upstream OpenHands | Defer |
| Windows native unsupported | Team 2 | WSL2 workaround documented |
| First request slow (warmup) | LiteLLM/Backend | Expected behavior |

---

## VALIDATION COMMANDS

To verify deployment works:

```bash
# Quick check
llm-doctor --quick

# Full diagnostics
llm-doctor

# Test OpenHands
oh serve  # Opens http://localhost:3000
```

---

## DOCUMENTATION LINKS

| Document | Path |
|----------|------|
| Usage Runbook | `docs/runbooks/OPENHANDS_USAGE.md` |
| Client Standard | `docs/reference/LLM_CLIENT_STANDARD.md` |
| Discovery Notes | `docs/notes/OPENHANDS_DISCOVERY.md` |
| LLM Contract | `/etc/miket/llm/contract.json` (on device) |

---

## DELIVERABLES CHECKLIST (TEAM 3)

- [ ] Review this handoff
- [ ] Decide on Option A/B/C/D above
- [ ] Update onboarding docs if needed
- [ ] If any chezmoi changes: PR with opt-in module + rollback
- [ ] If no changes: Confirm "no chezmoi changes required"

---

## FINAL HANDOFF TO CHIEF ARCHITECT

When complete, write summary with:
- What you changed (or "no changes")
- Links to docs added
- How to enable/disable any optional module
- Any friction points that remain

---

**Handoff Complete:** 2025-12-23
**Prepared By:** Codex-CA-001 (Chief Architect)
