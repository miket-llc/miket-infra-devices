# SSH User Mapping Configuration

## Overview

This document describes our user mapping strategy without full SSO.

**Deploy SSH config automatically:**
```bash
make deploy-ssh-config
```

This uses the Ansible role `ssh_client_config` to deploy standardized SSH config to all workstations.

## Automation Account: `mdt`

**Full Name:** Management, Deployment, and Tooling Account

The `mdt` account is the dedicated automation account for infrastructure management:
- **Management**: Infrastructure management operations
- **Deployment**: Automated deployment and configuration  
- **Tooling**: Automation tooling and scripts

This account is separate from user accounts and used exclusively by Ansible and infrastructure automation. See [Account Architecture](../architecture/account-architecture.md) for complete details.

## User Mapping Table

| Device/Tag     | Standard User | Local Alternative | Notes                    |
|---------------|--------------|-------------------|--------------------------|
| tag:linux     | mdt          | -                 | Automation account (MDT)  |
| tag:windows   | mdt          | miket             | Automation account (MDT)  |
| tag:macos     | miket        | -                 | macOS primary user       |
| motoko        | mdt          | -                 | Automation account (MDT)  |
| count-zero    | miket        | -                 | macOS workstation        |
| wintermute    | mdt          | -                 | Automation account (MDT)  |
| armitage      | mdt          | -                 | Automation account (MDT)  |

## SSH Config Deployment

SSH config is deployed via Ansible role `ssh_client_config`:

```bash
# Deploy to all workstations
make deploy-ssh-config

# Deploy to specific host
cd ansible && ansible-playbook -i inventory/hosts.yml playbooks/deploy-ssh-config.yml -l count-zero
```

### Safe Design (Include-based)

The role uses SSH's `Include` directive for safe, non-destructive deployment:

```
~/.ssh/
├── config              # Your existing config (NEVER touched except to add Include)
└── config.d/
    └── miket-infra.conf   # Our managed config (safe to delete)
```

**How it works:**
1. Creates `~/.ssh/config.d/` directory
2. Adds `Include config.d/*` to top of your config (only if not present)
3. Deploys our config to `config.d/miket-infra.conf`

**Your existing SSH config entries are preserved.**

### Removing the Config

To remove our managed SSH config:

```bash
# Just delete the managed file
rm ~/.ssh/config.d/miket-infra.conf

# The Include directive can stay (it ignores missing files)
```

### What's Included

The managed config provides:
- Correct user mappings per device type (mdt for Linux/Windows, miket for macOS)
- 1Password SSH agent configuration on macOS
- Tailscale hostnames and FQDN aliases
- Fallback for direct Tailscale IP access

## Tailscale SSH Usage

With the above config:
```bash
# These all work without specifying username:
ssh motoko.pangolin-vega.ts.net
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

