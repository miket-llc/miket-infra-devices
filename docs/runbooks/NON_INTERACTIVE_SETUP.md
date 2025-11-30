# Why This Fixes the Password Prompt Issue

## Problem
Ansible was prompting for passwords during runs against Wintermute, interrupting automation.

## Root Causes Identified

The diagnostic playbook (`playbooks/diag_no_prompts.yml`) checks three potential sources:

1. **Ansible Vault Password** (`ask-vault-pass`)
   - **Issue**: Vault password not automatically retrieved
   - **Fix**: `scripts/vault_pass.sh` retrieves from 1Password CLI non-interactively
   - **Config**: `ansible.cfg` uses `vault_identity_list = default@../scripts/vault_pass.sh`

2. **SSH Key Passphrase**
   - **Issue**: SSH key requires passphrase, ssh-agent not running or key not loaded
   - **Fix**: `scripts/ensure_ssh_agent.sh` ensures ssh-agent is running and key is loaded
   - **Prevention**: Key passphrases handled by ssh-agent or 1Password SSH agent

3. **Become/Sudo Password** (`become_ask_pass`)
   - **Issue**: `ansible_become_password` not set, Ansible prompts interactively
   - **Fix**: `host_vars/wintermute.yml` sets `ansible_become_password` from env var or 1Password
   - **Config**: `ansible.cfg` sets `become_ask_pass = False` to prevent fallback prompts

## Solution Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Ansible Playbook Run                     │
└─────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
┌───────────────┐  ┌───────────────┐  ┌───────────────┐
│ Vault Decrypt │  │  SSH Connect  │  │ Become/Sudo   │
└───────────────┘  └───────────────┘  └───────────────┘
        │                   │                   │
        ▼                   ▼                   ▼
┌───────────────┐  ┌───────────────┐  ┌───────────────┐
│ vault_pass.sh │  │ensure_ssh_    │  │host_vars/      │
│ (1Password)   │  │agent.sh       │  │wintermute.yml  │
└───────────────┘  └───────────────┘  └───────────────┘
        │                   │                   │
        ▼                   ▼                   ▼
┌───────────────┐  ┌───────────────┐  ┌───────────────┐
│ 1Password CLI │  │  ssh-agent    │  │ 1Password or  │
│               │  │  + SSH keys   │  │ ENV variable  │
└───────────────┘  └───────────────┘  └───────────────┘
```

## Key Changes

1. **ansible.cfg**
   - `vault_identity_list`: Points to 1Password script (replaces `vault_password_file`)
   - `become_ask_pass = False`: Prevents interactive become prompts

2. **scripts/vault_pass.sh**
   - POSIX-compliant shell script
   - Validates 1Password CLI availability and sign-in status
   - Retrieves password from `op://Automation/ansible-vault/password`
   - Exits non-zero on failure (prevents silent failures)

3. **scripts/ensure_ssh_agent.sh**
   - Starts ssh-agent if not running
   - Loads SSH key automatically
   - Documents key location for troubleshooting

4. **ansible/host_vars/wintermute.yml**
   - Sets `ansible_become_password` with fallback chain:
     - Environment variable (`ANSIBLE_BECOME_PASS`)
     - 1Password lookup plugin
     - Pipe lookup (direct `op read`)
     - Empty string (assumes passwordless sudo)

5. **Removed `--ask-vault-pass` flags**
   - Scripts no longer need explicit vault flags
   - Ansible automatically uses `vault_identity_list`

## Why This Works

- **Non-interactive**: All password retrieval happens programmatically
- **Fail-fast**: Scripts exit with clear errors if prerequisites missing
- **Fallback chain**: Multiple methods ensure resilience
- **Security**: Secrets never logged, retrieved on-demand from 1Password
- **Automation-friendly**: No human interaction required

## Verification

Run the diagnostic playbook to confirm all three sources are non-interactive:

```bash
cd ansible
ansible-playbook playbooks/diag_no_prompts.yml -l wintermute
```

Expected: All checks pass with no prompts.

