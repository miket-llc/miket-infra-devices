# Self-Management on Motoko

## Important: Use Local Connection

When running Ansible playbooks **on Motoko to manage Motoko itself**, you must use the `--connection=local` flag.

### Why?

The inventory is configured to use SSH (`ansible_host: motoko.tail2e55fe.ts.net`), which works great for remote management. However, when running on Motoko itself, SSH to localhost requires special key setup that may not be configured.

### Solution

Always use `--connection=local` for self-management playbooks:

```bash
cd ~/miket-infra-devices/ansible

# Deploy vLLM on Motoko (self-management)
ansible-playbook -i inventory/hosts.yml \
  playbooks/motoko/deploy-vllm.yml \
  --limit motoko \
  --connection=local

# Deploy LiteLLM on Motoko (self-management)
ansible-playbook -i inventory/hosts.yml \
  playbooks/motoko/deploy-litellm.yml \
  --limit motoko \
  --connection=local
```

### Alternative: Configure SSH for Localhost

If you prefer SSH even for localhost, you can:

1. **Add SSH key to authorized_keys:**
   ```bash
   cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
   ```

2. **Or use localhost in inventory:**
   ```yaml
   motoko:
     ansible_host: localhost
     ansible_connection: local
   ```

But `--connection=local` is simpler and more efficient for self-management.

### Remote Management (No Change Needed)

For managing other devices, continue using SSH as normal:

```bash
# Manage Armitage (remote)
ansible-playbook -i inventory/hosts.yml \
  playbooks/remote/armitage-vllm-setup.yml \
  --limit armitage
  # No --connection flag needed - uses SSH via Tailscale
```

## Summary

- **Self-management (Motoko → Motoko)**: Use `--connection=local`
- **Remote management (Motoko → Other devices)**: Use default SSH connection
