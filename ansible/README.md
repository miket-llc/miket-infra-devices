# Ansible Automation

This directory houses inventories, playbooks, and reusable roles for automating configuration across the fleet. Keep environment-specific variables separated so production and lab assets can be targeted safely.

## Inventory group conventions

The shared inventory (`inventory/hosts.yml`) defines host operating-system families along with capability-oriented groups that make targeting GPU or Wake-on-LAN ready systems straightforward:

| Group | Purpose | Typical usage |
| ----- | ------- | ------------- |
| `gpu_8gb` | Linux and Windows nodes with ~8 GB of dedicated GPU VRAM | `ansible-playbook playbooks/gpu-driver.yml -l gpu_8gb` |
| `gpu_12gb` | Windows nodes with 12 GB+ VRAM suitable for heavier ML jobs | `ansible-playbook playbooks/vllm.yml -l gpu_12gb` |
| `wol_enabled` | Devices that can be powered on remotely via Wake-on-LAN | `ansible-playbook playbooks/power/wol.yml -l wol_enabled` |

When adding a new host, place it under the appropriate OS family and opt in to any capability groupings it supports. This keeps playbooks focused on the features they configure rather than specific device names.

## Ansible Vault

Sensitive credentials (passwords, API keys, etc.) are stored in encrypted Ansible Vault files located in `group_vars/`:

- `group_vars/all/vault.yml` - Linux/macOS user passwords
- `group_vars/windows/vault.yml` - Windows WinRM passwords
- `group_vars/linux/vault.yml` - Linux-specific secrets

### Quick Start

```bash
# Initialize vault structure
./scripts/manage-vault.sh init

# Create all vault files
./scripts/manage-vault.sh create-all

# Edit a vault file
./scripts/manage-vault.sh edit windows/vault.yml

# Generate password hash for Linux/macOS
./scripts/manage-vault.sh generate-hash

# Test vault access
./scripts/manage-vault.sh test
```

### Using Vault Files

```bash
# Run playbooks with vault (interactive password prompt)
ansible-playbook -i inventory/hosts.yml playbooks/standardize-users.yml --ask-vault-pass

# Or use vault password file
export ANSIBLE_VAULT_PASSWORD_FILE=~/.ansible/vault_pass.txt
ansible-playbook -i inventory/hosts.yml playbooks/standardize-users.yml
```

See [Ansible Vault Setup](../../docs/runbooks/ansible-vault-setup.md) for detailed documentation.
