# Password Recovery and Reset Runbook

This document provides procedures for recovering or resetting passwords for the `mdt` user across all infrastructure devices.

## Overview

The infrastructure uses a standardized `mdt` user account across all devices:
- **Linux servers** (motoko): SSH key authentication (primary), password optional
- **Windows workstations** (wintermute, armitage): WinRM password authentication
- **macOS devices** (count-zero): SSH key authentication (primary), password optional

## Quick Reference

| Device | OS | Primary Auth | Password Reset Method |
|--------|----|--------------|----------------------|
| motoko | Linux | SSH keys | Method 1, 2, or 3 |
| wintermute | Windows | WinRM password | Method 4 |
| armitage | Windows | WinRM password | Method 4 |
| count-zero | macOS | SSH keys | Method 5 |

## Method 1: Reset Password via Another User with Sudo (Linux)

If you have access to another user account with sudo privileges:

```bash
# SSH to the device using another account
ssh otheruser@motoko.tail2e55fe.ts.net

# Reset mdt password
sudo passwd mdt

# Enter new password when prompted
```

## Method 2: Reset Password via Ansible (Linux/macOS)

If you have SSH key access but need to set/reset the password:

### Step 1: Generate Password Hash

```bash
# On motoko (control node)
python3 -c "import crypt; print(crypt.crypt('your-new-password', crypt.mksalt(crypt.METHOD_SHA512)))"
```

Copy the generated hash (starts with `$6$`).

### Step 2: Create/Update Ansible Vault

```bash
cd ~/miket-infra-devices

# Create vault file if it doesn't exist
ansible-vault create ansible/group_vars/all/vault.yml

# Or edit existing vault
ansible-vault edit ansible/group_vars/all/vault.yml
```

Add or update:
```yaml
vault_user_passwords:
  mdt: '$6$your-generated-hash-here'
```

### Step 3: Run Playbook

```bash
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/standardize-users.yml \
  --ask-vault-pass \
  --limit motoko
```

## Method 3: Reset Password via Console/Recovery Mode (Linux)

If you have physical or console access:

### Ubuntu/Debian Recovery Mode

1. Boot into recovery mode (hold Shift during boot, or select recovery option in GRUB)
2. Select "root - Drop to root shell prompt"
3. Remount filesystem as read-write:
   ```bash
   mount -o remount,rw /
   ```
4. Reset password:
   ```bash
   passwd mdt
   ```
5. Reboot:
   ```bash
   reboot
   ```

### Single User Mode

1. Edit GRUB boot entry (press 'e' at boot menu)
2. Find the line starting with `linux` and add `single` or `init=/bin/bash`
3. Boot and remount:
   ```bash
   mount -o remount,rw /
   passwd mdt
   sync
   reboot
   ```

## Method 4: Reset Windows Password

### Option A: Via Another Admin Account

1. Log in with another administrator account
2. Open PowerShell as Administrator
3. Reset password:
   ```powershell
   $user = [ADSI]"WinNT://localhost/mdt,user"
   $user.SetPassword("new-password-here")
   $user.SetInfo()
   ```

### Option B: Via Windows Recovery/Reset Tools

1. Boot from Windows installation media
2. Select "Repair your computer" → "Troubleshoot" → "Command Prompt"
3. Use `net user` command:
   ```cmd
   net user mdt new-password-here
   ```

### Option C: Update via Ansible Vault

1. Update Windows password in vault:
   ```bash
   cd ~/miket-infra-devices
   ansible-vault edit ansible/group_vars/windows/vault.yml
   ```

2. Update the password variable:
   ```yaml
   vault_armitage_password: "new-password-here"
   vault_wintermute_password: "new-password-here"
   ```

3. Test WinRM connection:
   ```bash
   ansible-playbook -i ansible/inventory/hosts.yml \
     -m win_ping \
     --ask-vault-pass \
     --limit armitage
   ```

## Method 5: Reset macOS Password

### Option A: Via Another Admin Account

1. Log in with another administrator account
2. Open Terminal
3. Reset password:
   ```bash
   sudo dscl . -passwd /Users/mdt "new-password-here"
   ```

### Option B: Via Recovery Mode

1. Boot into Recovery Mode (hold Command+R during boot)
2. Open Terminal from Utilities menu
3. Reset password:
   ```bash
   resetpassword
   ```
   Follow the GUI wizard to reset the password.

### Option C: Via Single User Mode

1. Boot holding Command+S
2. Remount filesystem:
   ```bash
   /sbin/mount -uw /
   ```
3. Reset password:
   ```bash
   launchctl load /System/Library/LaunchDaemons/com.apple.opendirectoryd.plist
   dscl . -passwd /Users/mdt "new-password-here"
   reboot
   ```

## Verification

After resetting a password, verify access:

### Linux/macOS
```bash
# Test SSH with password
ssh mdt@motoko.tail2e55fe.ts.net
# Enter password when prompted

# Test sudo
sudo whoami
# Should return 'root' without password (NOPASSWD configured)
```

### Windows
```bash
# Test WinRM via Ansible
ansible-playbook -i ansible/inventory/hosts.yml \
  -m win_ping \
  --ask-vault-pass \
  --limit armitage
```

## Prevention: Password Management Best Practices

1. **Use SSH Keys**: Primary authentication method for Linux/macOS
2. **Store Passwords in Vault**: Use Ansible Vault for all passwords
3. **Document Changes**: Update vault and commit changes (vault files are encrypted)
4. **Regular Audits**: Periodically verify access to all devices
5. **Backup Vault Password**: Store Ansible Vault password securely (password manager)

## Ansible Vault Password Management

### Setting Vault Password via Environment Variable

```bash
# Set vault password file
export ANSIBLE_VAULT_PASSWORD_FILE=~/.ansible/vault_pass.txt

# Or use vault password script
export ANSIBLE_VAULT_PASSWORD_FILE=~/.ansible/vault_pass.sh
chmod +x ~/.ansible/vault_pass.sh
```

### Using Vault Password File

Create `~/.ansible/vault_pass.txt`:
```
your-vault-password-here
```

Then run playbooks without `--ask-vault-pass`:
```bash
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/standardize-users.yml \
  --limit motoko
```

## Emergency Access Procedures

If all authentication methods fail:

1. **Linux**: Use console/KVM access → Recovery mode
2. **Windows**: Use Windows Recovery Environment → Reset password
3. **macOS**: Use Recovery Mode → Reset password
4. **Physical Access**: May require on-site access for some devices

## Related Documentation

- [SSH User Mapping](./ssh-user-mapping.md)
- [Ansible Windows Setup](../ansible-windows-setup.md)
- [Standardize Users Playbook](../../ansible/playbooks/standardize-users.yml)
- [Ansible Vault Setup](./ansible-vault-setup.md)

