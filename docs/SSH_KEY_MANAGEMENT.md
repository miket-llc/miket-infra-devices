# SSH Key Management for Infrastructure

## Overview

Infrastructure SSH keys are stored in 1Password for secure sharing across devices while maintaining accessibility on the headless control node (motoko).

## Key Locations

### Motoko (Control Node)
**Location:** `~/.ssh/id_ed25519` (standard location)
- **Purpose:** Primary SSH key for infrastructure management
- **Access:** Direct filesystem access (no 1Password required)
- **Used for:** Ansible, direct SSH to all infrastructure devices
- **Backup:** Stored in 1Password for disaster recovery

### 1Password Vault (miket.io)
**Items:**
- `SSH Key - Infrastructure Access to count-zero` (private key)
- `SSH Public Key - Infrastructure Access to count-zero` (public key)

**Tags:** `ssh`, `infrastructure`, `count-zero`, `ansible`

**Purpose:** 
- Share key with other workstations/devices
- Disaster recovery if motoko is lost
- Allow infrastructure management from any authorized device

## Device Access Configuration

### Count-Zero (macOS)
**Authorized Keys:** `~/.ssh/authorized_keys`
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDz3izMDijshZeztWcFPw0P83v2BlKy4MOurTXcfDLfy ansible-vault-motoko
```

**Access From:**
- motoko (direct, no 1Password needed)
- Any device with key from 1Password

## Using the Key from Other Devices

### Retrieve from 1Password

```bash
# Sign in to 1Password CLI
eval $(op signin)

# Download the private key
op document get "SSH Key - Infrastructure Access to count-zero" --vault miket.io > ~/.ssh/id_ed25519_infra
chmod 600 ~/.ssh/id_ed25519_infra

# Download the public key
op document get "SSH Public Key - Infrastructure Access to count-zero" --vault miket.io > ~/.ssh/id_ed25519_infra.pub
chmod 644 ~/.ssh/id_ed25519_infra.pub

# Use it
ssh -i ~/.ssh/id_ed25519_infra mdt@count-zero.pangolin-vega.ts.net
```

### Configure SSH to Use the Key

Add to `~/.ssh/config`:
```
Host count-zero count-zero.pangolin-vega.ts.net
    User mdt
    IdentityFile ~/.ssh/id_ed25519_infra
    IdentitiesOnly yes
```

Then simply:
```bash
ssh count-zero
```

## Security Considerations

### Motoko (Headless Server)
- ✅ Key stored in standard location (`~/.ssh/`)
- ✅ No 1Password dependency (headless operation)
- ✅ Protected by filesystem permissions (600)
- ✅ Backed up in 1Password for disaster recovery

### Other Devices
- ✅ Key retrieved from 1Password when needed
- ✅ 1Password protects with master password + 2FA
- ✅ Audit trail of key access
- ✅ Can revoke access by removing from 1Password

### Count-Zero
- ✅ Only authorized public keys in `authorized_keys`
- ✅ SSH only accessible via Tailscale network (100.64.0.0/10)
- ✅ No password authentication required
- ✅ Can revoke access by removing public key

## Key Rotation

If the key needs to be rotated:

1. **Generate new key on motoko:**
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_new -C "ansible-vault-motoko-$(date +%Y%m%d)"
   ```

2. **Store in 1Password:**
   ```bash
   cat ~/.ssh/id_ed25519_new | op document create --title "SSH Key - Infrastructure Access to count-zero (NEW)" --vault "miket.io"
   ```

3. **Add to count-zero:**
   ```bash
   # On count-zero
   cat >> ~/.ssh/authorized_keys << 'EOF'
   ssh-ed25519 AAAA... ansible-vault-motoko-20251113
   EOF
   ```

4. **Test new key:**
   ```bash
   ssh -i ~/.ssh/id_ed25519_new mdt@count-zero.pangolin-vega.ts.net hostname
   ```

5. **Replace old key:**
   ```bash
   mv ~/.ssh/id_ed25519 ~/.ssh/id_ed25519_old
   mv ~/.ssh/id_ed25519_new ~/.ssh/id_ed25519
   ```

6. **Remove old public key from count-zero**

7. **Update 1Password document**

## Ansible Configuration

The key is automatically used by Ansible when connecting to count-zero:

```yaml
# ansible/inventory/hosts.yml
count-zero:
  ansible_host: count-zero.pangolin-vega.ts.net
  ansible_user: mdt
  ansible_ssh_private_key_file: ~/.ssh/id_ed25519  # motoko uses default
```

Other devices should update their Ansible config to use the 1Password-retrieved key:
```yaml
ansible_ssh_private_key_file: ~/.ssh/id_ed25519_infra
```

## Documentation

- SSH key stored in 1Password: `miket.io` vault
- Key name: `SSH Key - Infrastructure Access to count-zero`
- Motoko location: `~/.ssh/id_ed25519` (standard, no 1Password needed)
- Count-zero authorized_keys: `~/.ssh/authorized_keys`

