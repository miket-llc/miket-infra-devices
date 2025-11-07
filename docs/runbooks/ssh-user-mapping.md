# SSH User Mapping Configuration

## Overview
This document describes our user mapping strategy without full SSO.

## User Mapping Table

| Device/Tag     | Standard User | Local Alternative | Notes                    |
|---------------|--------------|-------------------|--------------------------|
| tag:linux     | mdt          | -                 | Standard Linux user      |
| tag:windows   | mdt          | miket             | Windows local accounts   |
| tag:macos     | miket        | -                 | macOS primary user       |
| motoko        | mdt          | -                 | Linux server             |
| count-zero    | miket        | -                 | macOS workstation        |
| wintermute    | mdt          | -                 | Windows workstation      |
| armitage      | mdt          | -                 | Windows workstation      |

## SSH Config Template

Add to `~/.ssh/config`:

```ssh
# Linux servers - use mdt
Host *.tail2e55fe.ts.net motoko armitage wintermute
    User mdt
    IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    ForwardAgent yes

# macOS devices - use current user
Host count-zero* 
    User miket
    IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    ForwardAgent yes

# Default for Tailscale IPs
Host 100.*
    User mdt
    IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    ForwardAgent yes
```

## Tailscale SSH Usage

With the above config:
```bash
# These all work without specifying username:
ssh motoko.tail2e55fe.ts.net
ssh 100.92.23.71

# Or use the aliases we created:
ssh-motoko
```

## Password Management

User passwords are managed via Ansible Vault:
- **Linux/macOS**: Passwords stored as encrypted hashes in `ansible/group_vars/all/vault.yml`
- **Windows**: Passwords stored in `ansible/group_vars/windows/vault.yml`
- See [Password Recovery Runbook](./password-recovery.md) for reset procedures
- See [Ansible Vault Setup](./ansible-vault-setup.md) for vault management

## Future SSO Considerations

When ready for full SSO, consider:
1. **LDAP/AD Integration**: Central user directory
2. **SAML/OIDC**: For web-based services
3. **Kerberos**: For transparent authentication
4. **FreeIPA/JumpCloud**: Turnkey solutions

For now, this lightweight approach provides:
- Consistent usernames where practical
- Easy SSH access via Tailscale
- No complex SSO infrastructure to maintain
- Easy rollback if needed
- Centralized password management via Ansible Vault

