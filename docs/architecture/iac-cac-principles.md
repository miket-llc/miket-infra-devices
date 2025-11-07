# Infrastructure as Code (IaC) and Configuration as Code (CaC) Principles

## Overview

This repository follows Infrastructure as Code (IaC) and Configuration as Code (CaC) principles to ensure all infrastructure changes are:
- **Version controlled**: All configurations tracked in Git
- **Reproducible**: Can be recreated from code
- **Auditable**: Changes tracked through commits
- **Automated**: Changes applied via Ansible, not manual steps
- **Testable**: Can be validated before applying

## Core Principles

### 1. Code First, Manual Never

**Rule**: All infrastructure changes must be made through code, never manually.

**Why**: 
- Manual changes are lost, undocumented, and irreproducible
- Code changes are versioned, reviewable, and repeatable
- Enables disaster recovery and environment recreation

**Examples**:
- ✅ Create user accounts via Ansible playbooks
- ✅ Configure services via Ansible roles
- ✅ Update firewall rules via Terraform (miket-infra)
- ❌ Manually create accounts on devices
- ❌ Manually edit configuration files
- ❌ Manually run commands on servers

### 2. Single Source of Truth

**Rule**: Configuration lives in one place, consumed everywhere.

**Why**:
- Eliminates drift between environments
- Ensures consistency across devices
- Makes updates straightforward

**Implementation**:
- **Device inventory**: `ansible/inventory/hosts.yml`
- **Device configs**: `devices/{hostname}/config.yml`
- **Host variables**: `ansible/host_vars/{hostname}.yml`
- **Group variables**: `ansible/group_vars/{group}/`
- **Tailscale ACLs**: `miket-infra/infra/tailscale/entra-prod/`

### 3. Idempotency

**Rule**: All automation must be idempotent - running multiple times produces the same result.

**Why**:
- Safe to re-run playbooks
- Handles partial failures gracefully
- Enables continuous reconciliation

**Implementation**:
- Use Ansible modules (they're idempotent by design)
- Check state before making changes
- Use `state: present` not `state: created`

### 4. Declarative Configuration

**Rule**: Describe desired state, not steps to achieve it.

**Why**:
- Easier to understand intent
- Tool handles implementation details
- More resilient to changes

**Examples**:
- ✅ "User `mdt` should exist with sudo privileges"
- ✅ "Docker service should be running"
- ❌ "Run `useradd`, then `usermod`, then edit sudoers"

### 5. Version Control Everything

**Rule**: All configuration files must be in Git.

**Why**:
- History of changes
- Rollback capability
- Collaboration and review
- Documentation through commits

**What to commit**:
- ✅ Ansible playbooks and roles
- ✅ Configuration templates
- ✅ Documentation
- ✅ Scripts and automation
- ❌ Secrets (use Ansible Vault)
- ❌ Generated files (use `.gitignore`)

### 6. Secrets Management

**Rule**: Secrets stored encrypted, never in plaintext.

**Why**:
- Security best practice
- Enables safe version control
- Centralized secret management

**Implementation**:
- Use Ansible Vault for passwords and keys
- Store vault password securely (password manager)
- Never commit unencrypted secrets
- Rotate secrets regularly

### 7. Testing Before Applying

**Rule**: Validate changes before applying to production.

**Why**:
- Catch errors early
- Understand impact before applying
- Build confidence in changes

**Methods**:
- `ansible-playbook --check` (dry-run)
- `ansible-playbook --diff` (show changes)
- Test on non-production devices first
- Review Terraform plan before apply

### 8. Documentation as Code

**Rule**: Documentation lives alongside code.

**Why**:
- Stays in sync with code
- Easy to find and update
- Part of the same review process

**Structure**:
- `docs/architecture/` - System architecture
- `docs/runbooks/` - Operational procedures
- Inline comments in code
- README files in each directory

## Workflow

### Making Changes

1. **Plan**: Understand what needs to change
2. **Code**: Write/modify Ansible playbooks, Terraform, or configs
3. **Test**: Run with `--check` or `--diff`
4. **Review**: Commit and push for review (if team)
5. **Apply**: Run playbook/Terraform apply
6. **Verify**: Confirm changes took effect
7. **Document**: Update docs if needed

### Example: Adding a New User Account

**Wrong Way** (Manual):
```bash
# On each device manually:
ssh device1
sudo useradd mdt
sudo usermod -aG sudo mdt
# ... repeat for each device
```

**Right Way** (IaC/CaC):
```yaml
# 1. Update ansible/playbooks/standardize-users.yml
# 2. Test:
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/standardize-users.yml \
  --check --diff

# 3. Apply:
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/standardize-users.yml
```

## Repository Structure

```
miket-infra-devices/
├── ansible/              # Configuration as Code
│   ├── playbooks/        # High-level automation
│   ├── roles/            # Reusable components
│   ├── inventory/        # Device definitions
│   └── group_vars/       # Group configurations
├── devices/              # Device-specific configs
│   └── {hostname}/       # Single source of truth per device
├── scripts/              # Automation scripts
└── docs/                 # Documentation as Code

miket-infra/              # Infrastructure as Code
└── infra/
    └── tailscale/        # Network infrastructure
```

## Enforcement

### Pre-commit Checks

- Lint Ansible playbooks: `ansible-lint`
- Validate YAML: `yamllint`
- Check Terraform: `terraform validate`

### Code Review

- All changes reviewed before merging
- Documentation updated with code changes
- Secrets verified to be encrypted

### Continuous Reconciliation

- Regular playbook runs to ensure state
- Monitoring for configuration drift
- Automated remediation where possible

## Benefits

1. **Reproducibility**: Recreate entire infrastructure from code
2. **Consistency**: Same configuration across all devices
3. **Speed**: Automated changes faster than manual
4. **Safety**: Version control enables rollback
5. **Collaboration**: Team can review and contribute
6. **Documentation**: Code is self-documenting
7. **Auditability**: Full history of changes

## Anti-Patterns to Avoid

❌ **Manual changes**: "I'll just SSH in and fix it"
❌ **Copy-paste configs**: "I'll copy from another device"
❌ **Undocumented changes**: "I'll remember what I did"
❌ **Secrets in code**: "It's just a password"
❌ **One-off scripts**: "I'll write a quick script"
❌ **Snowflake servers**: "This one is special"

## Related Documentation

- [Account Architecture](./account-architecture.md)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)

