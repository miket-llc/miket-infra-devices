# Account Architecture

## Overview

This document describes the account architecture for infrastructure devices, including user accounts, automation accounts, and the separation between them.

## Three-Layer Account Model

### Layer 1: User Accounts (Context-Specific)

User accounts are used for daily interactive use and are context-specific:

| Context | Account Type | Example | Usage |
|---------|-------------|---------|-------|
| **Personal** | Local Account | `mdt` | Personal use, gaming, personal projects (simplified to local account only) |
| **Day Job** | Employer Account | (varies) | Work tasks, employer-managed resources |
| **Business** | Entra ID | `mike@miket.io` | Business infrastructure, miket.io services |

**Characteristics:**
- Multiple accounts can coexist on the same device
- Used for interactive login and daily work
- Context-specific (personal vs work vs business)
- May have different privileges and access levels

### Layer 2: Automation Account (Infrastructure)

The **`mdt`** account is the dedicated automation account for infrastructure management.

**Full Name:** Management, Deployment, and Tooling Account

**Purpose:**
- **Management**: Infrastructure management operations
- **Deployment**: Automated deployment and configuration
- **Tooling**: Automation tooling and scripts

**Characteristics:**
- Local account on all devices (separate from user accounts)
- Administrative privileges (sudo/Administrator) for automation tasks
- Used exclusively by Ansible and infrastructure automation
- Never used for interactive login or daily work
- Password managed via Ansible Vault
- Consistent across all devices (Linux, Windows, macOS)

**Rationale:**
The `mdt` account provides a consistent, trusted automation identity across all infrastructure devices. It is separate from user accounts to:
- Isolate automation from user activity
- Enable independent password management
- Provide clear audit trail for automation operations
- Support multi-context user environments (personal/work/business)

### Layer 3: Service Accounts (Future)

Service accounts for specific applications and services (to be implemented when needed):
- Managed via Entra ID when ready
- Application-specific credentials
- Rotated independently

## Account Mapping

| Device | OS | User Accounts | Automation Account |
|--------|----|--------------|-------------------|
| motoko | Linux | (varies) | `mdt` (local) |
| armitage | Windows | `mdt` (local) | `mdt` (local, automation) |
| wintermute | Windows | `mdt` (local) | `mdt` (local, automation) |
| count-zero | macOS | `miket` (local) | `mdt` (local) |

## Implementation Details

### Windows Devices

**User Accounts:**
- Local account (`mdt`) for personal use and automation (simplified approach)
- Entra ID account (`mike@miket.io`) for business use
- Day job account (varies by employer)

**Automation Account:**
- Local `mdt` account created specifically for Ansible
- Administrator privileges
- Password stored in `ansible/group_vars/windows/vault.yml`
- Used only for WinRM/Ansible connections

**Why Local Account?**
WinRM with NTLM authentication requires local accounts. Microsoft accounts cannot be used for WinRM automation, so a dedicated local account is necessary.

### Linux/macOS Devices

**User Accounts:**
- Personal accounts for daily use
- May include business accounts when needed

**Automation Account:**
- Local `mdt` account
- Sudo privileges (NOPASSWD)
- SSH key-based authentication
- Password optional (stored in vault if needed)

## Security Model

### Separation of Concerns

1. **User accounts** are for interactive use and context switching
2. **Automation account** is for infrastructure management only
3. **Service accounts** (future) will be for application-specific needs

### Password Management

- **User accounts**: Managed by their respective identity providers (Microsoft, Entra ID, employer)
- **Automation account**: Managed via Ansible Vault
  - Linux/macOS: Encrypted password hashes in `ansible/group_vars/all/vault.yml`
  - Windows: Plaintext passwords (encrypted by vault) in `ansible/group_vars/windows/vault.yml`

### Access Control

- Automation account has administrative privileges for automation tasks
- User accounts have standard user privileges (unless elevated for specific needs)
- Tailscale ACLs control network access based on device tags
- SSH/WinRM access controlled by Tailscale SSH rules and firewall rules

## Future SSO Considerations

When ready for full SSO:

1. **Phase 1 (Current)**: Local automation accounts, Entra ID for Tailscale SSO
2. **Phase 2**: Expand Entra ID usage for business services
3. **Phase 3**: Migrate automation to Entra ID service accounts (optional - local accounts can remain)

The current architecture supports incremental migration to SSO without requiring immediate changes to automation accounts.

## Related Documentation

- [SSH User Mapping](../runbooks/ssh-user-mapping.md)
- [Ansible Vault Setup](../runbooks/ansible-vault-setup.md)
- [Standardize Users Playbook](../../ansible/playbooks/standardize-users.yml)
- [Tailscale Integration](../tailscale-integration.md)

