# Quick Start: Non-Interactive Ansible Setup

## Initial Setup (One-Time)

### 1. Ensure SSH Agent is Running

```bash
./scripts/ensure_ssh_agent.sh
```

**What it does:**
- Starts ssh-agent if not running
- Adds your SSH key (`~/.ssh/id_ed25519` or `~/.ssh/id_rsa`) to the agent
- Verifies key is loaded

**Expected output:**
```
Using SSH key: /home/mdt/.ssh/id_ed25519
SSH key already loaded in ssh-agent
✅ SSH agent is running and key is loaded
```

### 2. Configure 1Password Secrets

Ensure these secrets exist in 1Password:

**Ansible Vault Password:**
- Vault: `Automation`
- Item: `ansible-vault`
- Field: `password`
- Path: `op://Automation/ansible-vault/password`

**Wintermute Sudo Password (if Linux):**
- Vault: `Automation`
- Item: `wintermute`
- Field: `sudo`
- Path: `op://Automation/wintermute/sudo`

### 3. Sign In to 1Password CLI

**Option A: Service Account (Headless)**
```bash
export OP_SERVICE_ACCOUNT_TOKEN="your-service-account-token"
op account list  # Verify
```

**Option B: Desktop + CLI**
```bash
op signin
op account list  # Verify
```

### 4. Test Non-Interactive Setup

```bash
cd ansible
ansible-playbook playbooks/diag_no_prompts.yml -l wintermute
```

**Expected output:**
```
✅ Vault decryption: PASSED (no prompt required)
✅ SSH connection: PASSED (no passphrase prompt)
✅ Become/sudo: PASSED (no password prompt)
✅ ALL NON-INTERACTIVE CHECKS PASSED
```

## Running Ansible Playbooks

After setup, run playbooks normally - no flags needed:

```bash
cd ansible
ansible-playbook playbooks/your-playbook.yml -l wintermute
```

**No prompts required!** All secrets are retrieved automatically.

## Troubleshooting

### "Error: 1Password CLI (op) is not installed"
```bash
# Install 1Password CLI (see README.md for full instructions)
```

### "Error: Not signed in to 1Password account"
```bash
op signin
# Or set service account token
export OP_SERVICE_ACCOUNT_TOKEN="your-token"
```

### "SSH key passphrase prompt"
```bash
./scripts/ensure_ssh_agent.sh
ssh-add ~/.ssh/id_ed25519  # If key has passphrase
```

### "Become password prompt"
- Set: `export ANSIBLE_BECOME_PASS="your-sudo-password"`
- Or ensure 1Password item exists: `op://Automation/wintermute/sudo`

## Files Changed

- `ansible/ansible.cfg` - Vault identity list, become_ask_pass disabled
- `scripts/vault_pass.sh` - 1Password vault password retrieval
- `scripts/ensure_ssh_agent.sh` - SSH agent management
- `ansible/host_vars/wintermute.yml` - Become password configuration
- `ansible/playbooks/diag_no_prompts.yml` - Diagnostic playbook
- `scripts/deploy-armitage-vllm.sh` - Removed --ask-vault-pass
- `scripts/manage-vault.sh` - Updated vault handling
- `.gitignore` - Added 1Password and vault temp files
- `README.md` - Added comprehensive non-interactive secrets section

## Why This Fixes the Prompt

1. **Vault Password**: Retrieved automatically via `scripts/vault_pass.sh` from 1Password
2. **SSH Passphrase**: Handled by ssh-agent (key loaded by `ensure_ssh_agent.sh`)
3. **Become Password**: Set in `host_vars/wintermute.yml` from env var or 1Password

All three sources are now non-interactive. See `docs/NON_INTERACTIVE_SETUP.md` for detailed explanation.

