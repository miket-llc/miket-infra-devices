# Ansible Vault Setup and Management

This document explains how to set up and manage Ansible Vault for storing sensitive credentials across the infrastructure.

## Overview

Ansible Vault encrypts sensitive data such as:
- User passwords (Linux/macOS)
- Windows WinRM passwords
- API keys and tokens
- MAC addresses and other sensitive identifiers

## Directory Structure

```
ansible/
├── group_vars/
│   ├── all/
│   │   └── vault.yml          # Linux/macOS user passwords
│   ├── windows/
│   │   └── vault.yml          # Windows WinRM passwords
│   └── linux/
│       └── vault.yml          # Linux-specific secrets
├── host_vars/
│   └── armitage.yml           # References vault variables
└── inventory/
    └── hosts.yml              # References vault variables
```

## Initial Setup

### Step 1: Create Vault Directories

```bash
cd ~/miket-infra-devices
mkdir -p ansible/group_vars/{all,windows,linux}
```

### Step 2: Create Vault Files

#### Linux/macOS User Passwords

```bash
ansible-vault create ansible/group_vars/all/vault.yml
```

Add content:
```yaml
# Linux/macOS user passwords
# Format: { 'username': 'encrypted_password_hash' }
# Generate hash: python3 -c "import crypt; print(crypt.crypt('password', crypt.mksalt(crypt.METHOD_SHA512)))"

vault_user_passwords:
  mdt: '$6$your-generated-hash-here'
```

#### Windows WinRM Passwords

```bash
ansible-vault create ansible/group_vars/windows/vault.yml
```

Add content:
```yaml
# Windows WinRM passwords for Ansible automation
vault_armitage_password: "your-armitage-password"
vault_wintermute_password: "your-wintermute-password"
```

#### Linux-Specific Secrets

```bash
ansible-vault create ansible/group_vars/linux/vault.yml
```

Add content:
```yaml
# Linux-specific secrets (if needed)
# Example: API keys, service passwords, etc.
```

### Step 3: Generate Password Hashes (Linux/macOS)

For Linux/macOS, passwords must be stored as encrypted hashes:

```bash
# Generate SHA-512 password hash
python3 -c "import crypt; print(crypt.crypt('your-password', crypt.mksalt(crypt.METHOD_SHA512)))"
```

Copy the output (starts with `$6$`) and use it in the vault file.

## Vault Password Management

### Option 1: Interactive Password Entry

Always prompted for vault password:
```bash
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/standardize-users.yml \
  --ask-vault-pass
```

### Option 2: Vault Password File

Create a password file:
```bash
# Create directory
mkdir -p ~/.ansible

# Create password file (one-time password)
echo "your-vault-password" > ~/.ansible/vault_pass.txt
chmod 600 ~/.ansible/vault_pass.txt
```

Use with playbooks:
```bash
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/standardize-users.yml \
  --vault-password-file ~/.ansible/vault_pass.txt
```

### Option 3: Environment Variable

Set vault password file path:
```bash
export ANSIBLE_VAULT_PASSWORD_FILE=~/.ansible/vault_pass.txt

# Now playbooks will use it automatically
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/standardize-users.yml
```

### Option 4: Vault Password Script

For more advanced scenarios (e.g., fetching from password manager):

```bash
# Create executable script
cat > ~/.ansible/vault_pass.sh << 'EOF'
#!/bin/bash
# Fetch password from 1Password, HashiCorp Vault, etc.
op read "op://Infrastructure/Ansible Vault/password"
EOF

chmod +x ~/.ansible/vault_pass.sh
export ANSIBLE_VAULT_PASSWORD_FILE=~/.ansible/vault_pass.sh
```

## Common Vault Operations

### View Encrypted Vault File

```bash
ansible-vault view ansible/group_vars/all/vault.yml
```

### Edit Encrypted Vault File

```bash
ansible-vault edit ansible/group_vars/all/vault.yml
```

### Create New Vault File

```bash
ansible-vault create ansible/group_vars/all/vault.yml
```

### Encrypt Existing File

```bash
ansible-vault encrypt ansible/group_vars/all/vault.yml
```

### Decrypt Vault File (for editing outside Ansible)

```bash
ansible-vault decrypt ansible/group_vars/all/vault.yml
# Remember to re-encrypt after editing!
ansible-vault encrypt ansible/group_vars/all/vault.yml
```

### Change Vault Password

```bash
ansible-vault rekey ansible/group_vars/all/vault.yml
```

### Encrypt String (for inline variables)

```bash
ansible-vault encrypt_string 'my-password' --name 'vault_password'
```

Output:
```yaml
vault_password: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          663864396530363865346435663964353239643361653438633236636162633636633...
```

## Usage Examples

### Set User Password on Linux

```bash
# 1. Generate password hash
python3 -c "import crypt; print(crypt.crypt('new-password', crypt.mksalt(crypt.METHOD_SHA512)))"

# 2. Edit vault
ansible-vault edit ansible/group_vars/all/vault.yml

# 3. Update vault_user_passwords['mdt'] with new hash

# 4. Run playbook
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/standardize-users.yml \
  --ask-vault-pass \
  --limit motoko
```

### Update Windows Password

```bash
# 1. Edit Windows vault
ansible-vault edit ansible/group_vars/windows/vault.yml

# 2. Update password variable
# vault_armitage_password: "new-password"

# 3. Test connection
ansible-playbook -i ansible/inventory/hosts.yml \
  -m win_ping \
  --ask-vault-pass \
  --limit armitage
```

### View All Vault Variables

```bash
# View all vault files
ansible-vault view ansible/group_vars/all/vault.yml
ansible-vault view ansible/group_vars/windows/vault.yml
```

## Security Best Practices

1. **Never Commit Unencrypted Secrets**: All vault files should be encrypted
2. **Use Strong Vault Password**: Use a password manager to generate and store vault password
3. **Limit Vault Password Access**: Only share vault password with authorized personnel
4. **Rotate Passwords Regularly**: Update passwords in vault and re-encrypt
5. **Backup Vault Password**: Store vault password securely (password manager, secure notes)
6. **Use Vault Password File**: Avoid typing password repeatedly (use password file)
7. **Audit Vault Access**: Review who has access to vault password
8. **Separate Vaults by Environment**: Use different vaults for dev/staging/prod if needed

## Troubleshooting

### "Vault password is required" Error

```bash
# Solution: Provide vault password
ansible-playbook ... --ask-vault-pass

# Or set password file
export ANSIBLE_VAULT_PASSWORD_FILE=~/.ansible/vault_pass.txt
```

### "Decryption failed" Error

- Verify vault password is correct
- Check if vault file was corrupted
- Restore from backup if needed

### "Variable not found" Error

- Verify variable name matches exactly (case-sensitive)
- Check vault file is in correct `group_vars` directory
- Ensure vault file is loaded (check inventory structure)

## Integration with Password Managers

### 1Password Integration

```bash
# Create vault password script
cat > ~/.ansible/vault_pass.sh << 'EOF'
#!/bin/bash
op read "op://Infrastructure/Ansible Vault/password"
EOF

chmod +x ~/.ansible/vault_pass.sh
export ANSIBLE_VAULT_PASSWORD_FILE=~/.ansible/vault_pass.sh
```

### HashiCorp Vault Integration

```bash
# Fetch password from HashiCorp Vault
cat > ~/.ansible/vault_pass.sh << 'EOF'
#!/bin/bash
vault kv get -field=password secret/ansible/vault
EOF

chmod +x ~/.ansible/vault_pass.sh
export ANSIBLE_VAULT_PASSWORD_FILE=~/.ansible/vault_pass.sh
```

## Related Documentation

- [Password Recovery Runbook](./password-recovery.md)
- [Standardize Users Playbook](../../ansible/playbooks/standardize-users.yml)
- [Ansible Windows Setup](../ansible-windows-setup.md)
- [Ansible Documentation](https://docs.ansible.com/ansible/latest/user_guide/vault.html)

