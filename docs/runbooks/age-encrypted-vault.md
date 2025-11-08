# Age-Encrypted Ansible Vault Password

This document explains how to use **age encryption** with SSH keys to store the Ansible vault password locally. This is the **most automation-friendly** solution as it requires no external services, no interactive logins, and works perfectly over SSH.

## Why Age Encryption?

**Age** (Actually Good Encryption) is a modern encryption tool that:
- ✅ **Uses SSH keys** - Works with your existing SSH infrastructure
- ✅ **No external services** - Everything is local, no network required
- ✅ **No interactive logins** - Perfect for automation and SSH access
- ✅ **Fast and simple** - Lightweight, easy to use
- ✅ **Secure** - Uses modern encryption (X25519, ChaCha20Poly1305)

## Quick Setup

```bash
# 1. Install age (if not already installed)
sudo apt install age
# Or: go install -a github.com/FiloSottile/age/cmd/age@latest

# 2. Run setup script
cd ~/miket-infra-devices
./scripts/setup-age-encrypted-vault.sh

# 3. Test it works
./scripts/ansible-vault-password-age.sh

# 4. Use with Ansible (no prompts needed!)
ansible-playbook -i ansible/inventory/hosts.yml playbooks/test-connectivity.yml
```

## How It Works

1. **Encryption**: Your vault password is encrypted using your SSH public key
2. **Storage**: Encrypted file stored at `~/.ansible/vault_pass.age`
3. **Decryption**: Ansible automatically decrypts using your SSH private key
4. **No authentication needed**: SSH keys handle everything

## Manual Setup

If you prefer to set it up manually:

```bash
# 1. Get your vault password (from 1Password, Azure Key Vault, etc.)
read -sp "Vault password: " VAULT_PASSWORD

# 2. Encrypt with your SSH public key
echo -n "$VAULT_PASSWORD" | age --encrypt \
    --recipients-file ~/.ssh/id_ed25519.pub \
    > ~/.ansible/vault_pass.age

# 3. Secure the file
chmod 600 ~/.ansible/vault_pass.age

# 4. Test decryption
age --decrypt -i ~/.ssh/id_ed25519.pub ~/.ansible/vault_pass.age
```

## Configuration

The script automatically detects your SSH key. To use a specific key:

```bash
export ANSIBLE_VAULT_SSH_KEY="$HOME/.ssh/custom_key.pub"
```

To use a different encrypted file location:

```bash
export ANSIBLE_VAULT_PASSWORD_FILE="$HOME/.ansible/custom_vault_pass.age"
```

## Multi-Source Fallback

The `ansible-vault-password.sh` script (configured in `ansible.cfg`) tries sources in order:

1. **age-encrypted file** (primary - no external deps)
2. Azure Key Vault (if available)
3. 1Password (if available)
4. Local plaintext file (fallback)

This ensures reliability while prioritizing automation-friendly options.

## Security Considerations

### ✅ Advantages

- **No external dependencies** - Works offline, no network required
- **SSH key security** - Uses your existing, well-protected SSH keys
- **Local storage** - Encrypted file stays on your server
- **No credentials to manage** - SSH keys handle authentication

### 🔒 Best Practices

1. **Protect SSH private key**: Keep `~/.ssh/id_ed25519` secure (600 permissions)
2. **Backup encrypted file**: Store `~/.ansible/vault_pass.age` in version control (it's encrypted!)
3. **Rotate keys**: If SSH key is compromised, re-encrypt with new key
4. **Multiple recipients**: Can encrypt for multiple SSH keys (team access)

## Encrypting for Multiple Recipients

To allow multiple people/systems to decrypt:

```bash
# Create recipients file with multiple public keys
cat > /tmp/recipients.txt << EOF
ssh-ed25519 AAAAC3... user1@host1
ssh-ed25519 AAAAC3... user2@host2
EOF

# Encrypt for all recipients
echo -n "$VAULT_PASSWORD" | age --encrypt \
    --recipients-file /tmp/recipients.txt \
    > ~/.ansible/vault_pass.age
```

## Rotating the Password

When you need to change the vault password:

```bash
# 1. Get new password
read -sp "New vault password: " NEW_PASSWORD

# 2. Re-encrypt
echo -n "$NEW_PASSWORD" | age --encrypt \
    --recipients-file ~/.ssh/id_ed25519.pub \
    > ~/.ansible/vault_pass.age

# 3. Re-encrypt all Ansible vault files with new password
ansible-vault rekey ansible/group_vars/windows/vault.yml
```

## Troubleshooting

### "age: command not found"
```bash
# Install age
sudo apt install age
# Or: go install -a github.com/FiloSottile/age/cmd/age@latest
```

### "no identity matched"
- Verify SSH public key matches private key
- Check SSH key path: `ls -la ~/.ssh/id_ed25519*`
- Try specifying key explicitly: `export ANSIBLE_VAULT_SSH_KEY=~/.ssh/id_ed25519.pub`

### "permission denied"
```bash
chmod 600 ~/.ansible/vault_pass.age
chmod 600 ~/.ssh/id_ed25519
```

### Script falls back to other sources
- This is expected if age-encrypted file doesn't exist or can't be decrypted
- Check file exists: `ls -la ~/.ansible/vault_pass.age`
- Test decryption manually: `age --decrypt -i ~/.ssh/id_ed25519.pub ~/.ansible/vault_pass.age`

## Comparison with Other Solutions

| Solution | External Service | Interactive Login | SSH-Friendly | Automation-Friendly |
|----------|-----------------|-------------------|--------------|---------------------|
| **age + SSH** | ❌ No | ❌ No | ✅ Yes | ✅ Yes |
| Azure Key Vault | ✅ Yes | ⚠️ Maybe* | ⚠️ Maybe* | ⚠️ Maybe* |
| 1Password | ✅ Yes | ✅ Yes | ❌ No | ❌ No |
| Plaintext file | ❌ No | ❌ No | ✅ Yes | ✅ Yes |

*Azure Key Vault can work without interactive login if using Managed Identity or Service Principal, but requires Azure infrastructure.

## Related Documentation

- [Ansible Vault Setup](./ansible-vault-setup.md)
- [Age Encryption Tool](https://github.com/FiloSottile/age)
- [SSH Key Management](../architecture/ssh-key-management.md)

