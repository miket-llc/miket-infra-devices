# Migration to File-Based Vault Passwords

## Summary

**Before:** Ansible used 1Password CLI (`op`) via `scripts/vault_pass.sh` to retrieve vault passwords.

**After:** Ansible uses local files (`/etc/ansible/.vault-pass.txt` and `/etc/ansible/.become-pass.txt`) with no external dependencies.

## What Changed

### 1. Vault Password
- **Old:** `vault_identity_list = default@../scripts/vault_pass.sh` (called `op read`)
- **New:** `vault_identity_list = default@/etc/ansible/.vault-pass.txt`

### 2. Become Password
- **Old:** Commented out or via environment variable
- **New:** `ansible_become_password: "{{ lookup('file', '/etc/ansible/.become-pass.txt') | trim }}"` in `group_vars/all/auth.yml`

### 3. Files Retired
- `scripts/vault_pass.sh` → `scripts/vault_pass.sh.RETIRED` (kept for reference)

## CLI Examples

### Before (1Password)
```bash
# Vault operations required op signin
op signin
ansible-playbook playbooks/my-playbook.yml
```

### After (File-Based)
```bash
# No external dependencies, no signin required
ansible-playbook -i inventory/hosts.yml playbooks/my-playbook.yml
```

### Vault Management

**Before:**
```bash
# Edit vaulted file with op integration
ansible-vault edit group_vars/windows/vault.yml
# Would call scripts/vault_pass.sh which calls op
```

**After:**
```bash
# Edit vaulted file with local password file
ansible-vault edit group_vars/windows/vault.yml
# Reads /etc/ansible/.vault-pass.txt automatically
```

## Benefits

✅ **Zero dependencies** - No 1Password CLI required  
✅ **No authentication** - No `op signin` needed  
✅ **Faster** - No network calls to 1Password  
✅ **Simpler** - Direct file read instead of script execution  
✅ **Offline capable** - Works without internet connection  

## Setup on New Control Node

```bash
# 1. Extract passwords from backup (1Password, etc.)
VAULT_PASS=$(op read "op://miket.io/Ansible - Motoko Key Vault/password")

# 2. Create files
sudo mkdir -p /etc/ansible
echo "$VAULT_PASS" | sudo tee /etc/ansible/.vault-pass.txt > /dev/null
echo "" | sudo tee /etc/ansible/.become-pass.txt > /dev/null  # Empty for passwordless sudo

# 3. Set permissions
sudo chmod 600 /etc/ansible/.vault-pass.txt /etc/ansible/.become-pass.txt
sudo chown mdt:mdt /etc/ansible/.vault-pass.txt /etc/ansible/.become-pass.txt
sudo chmod 755 /etc/ansible

# 4. Test
cd ansible && ansible-playbook -i inventory/hosts.yml playbooks/diag_no_prompts.yml
```

## Rollback (If Needed)

To restore 1Password integration:

```bash
# 1. Restore vault_pass.sh
mv scripts/vault_pass.sh.RETIRED scripts/vault_pass.sh

# 2. Update ansible.cfg
sed -i 's|vault_identity_list = default@/etc/ansible/.vault-pass.txt|vault_identity_list = default@../scripts/vault_pass.sh|' ansible/ansible.cfg

# 3. Remove file-based auth
rm ansible/group_vars/all/auth.yml

# 4. Sign in to 1Password
op signin
```

