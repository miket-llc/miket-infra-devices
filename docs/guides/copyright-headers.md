---
document_title: "Copyright Headers Guide"
author: "Documentation Specialist"
last_updated: 2025-01-XX
status: Published
related_initiatives: []
linked_communications: []
---

# Copyright Headers Guide

## Overview

All code files in this repository must include a copyright header. This document explains the policy, automation, and best practices.

## Policy

- **Code files** (`.sh`, `.py`, `.yml`, `.yaml`): Must include copyright header
- **Documentation files** (`.md`): Reference LICENSE file (no header needed)
- **Full license text**: See `LICENSE` file in repository root

## Copyright Header Format

For code files, use this single line:

```bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
```

For Python files:
```python
# Copyright (c) 2025 MikeT LLC. All rights reserved.
```

For YAML files:
```yaml
# Copyright (c) 2025 MikeT LLC. All rights reserved.
```

## Placement

- **Shell scripts**: After shebang (`#!/bin/bash`), before other content
- **Python files**: After shebang (if present), before imports
- **YAML files**: At the very top of the file

## Automation

### One-Time: Add Headers to Existing Files

Run the batch script to add headers to all existing files:

```bash
./scripts/add-copyright-headers.sh
```

This will:
- Scan all `.sh`, `.py`, `.yml`, `.yaml` files
- Skip files that already have copyright headers
- Preserve shebangs in shell/Python scripts
- Show summary of files modified

### Ongoing: Pre-commit Hook

The pre-commit hook automatically adds copyright headers to new files before commit.

**Installation:**

```bash
# Install pre-commit (if not already installed)
pip install pre-commit

# Install the git hooks
pre-commit install
```

**How it works:**
- Runs automatically on `git commit`
- Checks staged files for copyright headers
- Adds header if missing
- Re-stages the file

### IDE Templates (Recommended)

Configure your IDE to automatically include copyright headers in new files:

#### VS Code

1. Install extension: "Auto Copyright" or "Copyright Manager"
2. Configure template in settings

#### Cursor

1. Create file templates in `.cursor/templates/`
2. Configure to use templates for new files

#### Manual Template

When creating new files, copy this template:

**Shell Script:**
```bash
#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.

set -euo pipefail

# Your code here
```

**Python:**
```python
#!/usr/bin/env python3
# Copyright (c) 2025 MikeT LLC. All rights reserved.

# Your code here
```

**YAML:**
```yaml
# Copyright (c) 2025 MikeT LLC. All rights reserved.

# Your configuration here
```

## Documentation Files

Documentation files (`.md`) do **not** need copyright headers. They reference the `LICENSE` file at the repository root.

If you want to add a copyright notice to a documentation file, add it to the front matter:

```yaml
---
document_title: "..."
copyright: "Copyright (c) 2025 MikeT LLC. All rights reserved."
---
```

## Verification

Check if files have copyright headers:

```bash
# Find files without copyright
find . -type f \( -name "*.sh" -o -name "*.py" -o -name "*.yml" -o -name "*.yaml" \) \
  ! -path "./.git/*" ! -path "./node_modules/*" ! -path "./.venv/*" \
  -exec grep -L "Copyright.*MikeT" {} \;
```

## Exceptions

Files that should **not** have copyright headers:
- Generated files (e.g., `__pycache__/`, `.pyc` files)
- Lock files (e.g., `*.lock.yml`)
- Third-party code (if any)
- Files in `.git/`, `node_modules/`, `.venv/`, etc.

## Best Practices

1. **Use automation**: Let pre-commit hooks handle new files
2. **Run batch script once**: Add headers to existing files in one go
3. **Set up IDE templates**: Makes creating new files easier
4. **Review before commit**: Check `git diff` to verify headers are correct

## Troubleshooting

### Pre-commit hook not running

```bash
# Reinstall hooks
pre-commit install --overwrite
```

### Header added incorrectly

The pre-commit hook preserves shebangs. If a header is in the wrong place:
1. Manually fix the file
2. Commit the fix
3. The hook won't modify it again (it detects existing headers)

### Want to skip hook for one commit

```bash
git commit --no-verify
```

(Use sparingly - headers should be added eventually)

## Related Files

- `LICENSE` - Full license text
- `scripts/add-copyright-headers.sh` - Batch header addition
- `scripts/pre-commit-copyright-check.sh` - Pre-commit hook
- `.pre-commit-config.yaml` - Pre-commit configuration


