#!/bin/sh
# Ansible Vault Password Script - 1Password Integration
# Retrieves vault password from 1Password CLI non-interactively
# Used by Ansible via vault_identity_list in ansible.cfg
#
# Pattern used: op read op://miket.io/Ansible - Motoko Key Vault/password
# Alternative: op read op://Automation/ansible-vault/password (if Automation vault exists)

set -eu

# Ensure 1Password CLI is available
if ! command -v op >/dev/null 2>&1; then
    echo "Error: 1Password CLI (op) is not installed or not in PATH" >&2
    exit 1
fi

# Check if signed in to 1Password account
if ! op account list >/dev/null 2>&1; then
    echo "Error: Not signed in to 1Password account. Run 'op signin' first." >&2
    exit 1
fi

# Retrieve vault password from 1Password
# Try Automation vault first (as per requirements), fallback to miket.io vault
VAULT_PASSWORD=$(op read "op://Automation/ansible-vault/password" 2>/dev/null) || \
VAULT_PASSWORD=$(op read "op://miket.io/Ansible - Motoko Key Vault/password" 2>/dev/null) || {
    echo "Error: Failed to retrieve vault password from 1Password" >&2
    echo "Tried:" >&2
    echo "  - op://Automation/ansible-vault/password" >&2
    echo "  - op://miket.io/Ansible - Motoko Key Vault/password" >&2
    echo "Ensure one of these items exists and you have access." >&2
    exit 1
}

# Check if password is empty
if [ -z "$VAULT_PASSWORD" ]; then
    echo "Error: Vault password is empty" >&2
    exit 1
fi

# Output only the password (no newline, no stderr)
printf '%s' "$VAULT_PASSWORD"
