# SSH Key Management

This is the canonical documentation for SSH key management in miket-infra-devices.

## Philosophy

SSH keys for infrastructure management are:
1. **Stored on the control node** (motoko) in standard locations
2. **Deployed via Ansible** to managed devices
3. **NOT stored in 1Password** - they're infrastructure automation keys, not user keys
4. **Version controlled patterns** via playbooks, not the keys themselves

This follows the Ansible best practice of keeping keys on the control node and deploying them automatically.

## Related Resources

| Resource | Purpose |
|----------|---------|
| `ansible/roles/ssh_client_config/` | Ansible role for SSH client config |
| `ansible/playbooks/deploy-ssh-config.yml` | Deploy SSH config to workstations |
| `docs/runbooks/ssh-user-mapping.md` | User mapping by device type |
| `make deploy-ssh-config` | One-command SSH config deployment |

## Key Locations

### Motoko (Control Node)
```
~/.ssh/id_ed25519      # Private key (stays on motoko, never leaves)
~/.ssh/id_ed25519.pub  # Public key (deployed to managed devices)
```

**Security:**
- Private key: `600` permissions, only accessible by mdt user
- Public key: `644` permissions, safe to share
- Control node is headless, physically secured, never leaves premises

### Managed Devices
```
~/.ssh/authorized_keys  # Contains motoko's public key
```

## Initial Setup (One-Time Bootstrap)

When adding a new device that doesn't have SSH access yet:

### 1. On Count-Zero (or any new device):

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
```

Get motoko's public key and add it:
```bash
# Option A: Copy manually from motoko
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDz3izMDijshZeztWcFPw0P83v2BlKy4MOurTXcfDLfy ansible-vault-motoko" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

```bash
# Option B: If network access is available, fetch from motoko
ssh motoko "cat ~/.ssh/id_ed25519.pub" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

### 2. Test from Motoko:

```bash
ssh mdt@count-zero.pangolin-vega.ts.net hostname
```

### 3. Run Ansible Playbook (Future Updates):

Once SSH is working, use Ansible for all future key management:

```bash
cd /home/mdt/miket-infra-devices
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/setup-count-zero-access.yml
```

## Ongoing Management

### Add SSH Key to New Devices

Use the `standardize-users.yml` playbook:

```bash
cd /home/mdt/miket-infra-devices
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/remote/standardize-users.yml
```

This automatically:
- Creates the mdt user
- Deploys SSH keys from motoko
- Configures sudo access
- Sets up authorized_keys

### Update SSH Keys

If you rotate the key on motoko:

```bash
# Generate new key on motoko
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_new -C "ansible-vault-motoko-$(date +%Y%m%d)"

# Test with new key
ssh -i ~/.ssh/id_ed25519_new mdt@count-zero.pangolin-vega.ts.net hostname

# If successful, replace old key
mv ~/.ssh/id_ed25519 ~/.ssh/id_ed25519_old
mv ~/.ssh/id_ed25519_new ~/.ssh/id_ed25519

# Redeploy to all devices
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/setup-count-zero-access.yml
```

## How Keys Are Used

### Ansible Playbooks

Keys are read directly from filesystem:

```yaml
# ansible/playbooks/remote/standardize-users.yml
vars:
  standard_users:
    - username: mdt
      ssh_keys:
        - "{{ lookup('file', '~/.ssh/id_ed25519.pub') }}"  # Reads from motoko
```

### Direct SSH

```bash
# Automatic (uses default key)
ssh mdt@count-zero.pangolin-vega.ts.net

# Explicit key file
ssh -i ~/.ssh/id_ed25519 mdt@count-zero.pangolin-vega.ts.net
```

## Why Not 1Password?

1. **Automation Keys vs User Keys**
   - Infrastructure automation keys should live on the control node
   - User personal keys can go in 1Password
   - Mixing them complicates automation

2. **Headless Operation**
   - Motoko needs to run unattended
   - Can't prompt for 1Password password
   - Keys must be filesystem-accessible

3. **Ansible Best Practices**
   - Ansible reads from control node filesystem
   - `lookup('file', ...)` is the standard pattern
   - Keeps secrets management simple

4. **Version Control**
   - Playbooks and patterns are in git
   - Keys themselves are NOT in git
   - Keys on control node, deployed via Ansible

## Security Model

### What's Protected

- ✅ Private key never leaves motoko
- ✅ Motoko is physically secured
- ✅ SSH only via Tailscale (100.64.0.0/10)
- ✅ Key-based auth only (no passwords)
- ✅ Control node is headless/dedicated

### What's Not Protected

- Public keys (they're public by design)
- Playbook patterns (documented in git)
- Inventory structure (visible in repo)

### Threat Model

**Protected Against:**
- External network attacks (Tailscale only)
- Password guessing (key-only auth)
- Unauthorized key use (private key secured on motoko)

**Not Protected Against:**
- Physical access to motoko (but it's in secure premises)
- Compromise of motoko itself (defense in depth via Tailscale, least privilege)

## Related Documentation

- Ansible inventory: `ansible/inventory/hosts.yml`
- User standardization: `ansible/playbooks/remote/standardize-users.yml`
- SSH key deployment: `ansible/playbooks/setup-count-zero-access.yml`
- Ansible configuration: `ansible/ansible.cfg`

