# motoko-devops Consolidation Plan

**Date:** 2025-01-XX  
**Purpose:** Migrate motoko-devops scripts and configurations into miket-infra-devices

---

## Overview

The `motoko-devops` repository contains reusable administrative scripts that should be consolidated into `miket-infra-devices` as part of the modernization effort. This document provides a framework for categorizing and migrating scripts.

---

## Migration Categories

### Category A: Ansible Roles (Infrastructure as Code)

**Criteria:**
- System configuration tasks
- Service deployments
- Package management
- User management
- Idempotent operations

**Migration Path:**
```
motoko-devops/scripts/configure-X.sh
  → ansible/roles/X/tasks/main.yml
  → ansible/roles/X/defaults/main.yml
  → ansible/roles/X/handlers/main.yml
```

**Examples:**
- `configure-docker.sh` → `ansible/roles/docker/`
- `setup-samba.sh` → `ansible/roles/samba/`
- `configure-backup.sh` → `ansible/roles/backup/`

**Checklist:**
- [ ] Convert shell logic to Ansible modules
- [ ] Add idempotency checks
- [ ] Create role defaults/main.yml
- [ ] Add role meta/main.yml (dependencies)
- [ ] Test role with `ansible-playbook --check`
- [ ] Document role in `ansible/roles/X/README.md`

---

### Category B: Standardized Scripts (Operational Tools)

**Criteria:**
- One-off maintenance tasks
- Backup scripts
- Health checks
- Manual operations
- Non-idempotent operations

**Migration Path:**
```
motoko-devops/scripts/operation-X.sh
  → scripts/operations/X.sh
```

**Directory Structure:**
```
scripts/operations/
├── backup/
│   ├── backup-docker.sh
│   └── backup-volumes.sh
├── maintenance/
│   ├── cleanup-logs.sh
│   └── update-packages.sh
└── health-checks/
    ├── check-services.sh
    └── check-disk-space.sh
```

**Checklist:**
- [ ] Add shebang and error handling
- [ ] Add usage/help text
- [ ] Standardize logging format
- [ ] Add configuration file support (if needed)
- [ ] Document in `scripts/operations/README.md`

---

### Category C: Docker Compose (Service Definitions)

**Criteria:**
- Service definitions
- Multi-container applications
- Environment configurations
- Volume definitions

**Migration Path:**
```
motoko-devops/docker/service.yml
  → docker-compose/motoko/service.yml
```

**Directory Structure:**
```
docker-compose/
├── motoko/
│   ├── docker-compose.yml          # Main compose file
│   ├── litellm.yml
│   ├── vllm-reasoning.yml
│   ├── vllm-embeddings.yml
│   └── textgen-webui.yml            # If exists in motoko-devops
└── README.md
```

**Checklist:**
- [ ] Validate compose file syntax
- [ ] Update volume paths (use variables)
- [ ] Update network names (use project name)
- [ ] Add health checks
- [ ] Document environment variables
- [ ] Test with `docker compose config`

---

### Category D: Grafana/Prometheus (Observability)

**Criteria:**
- Monitoring configurations
- Alert rules
- Dashboard definitions
- Exporter configs

**Migration Path:**
```
motoko-devops/monitoring/X.yml
  → tools/monitoring/X.yml
```

**Directory Structure:**
```
tools/monitoring/
├── prometheus.yml                   # Already exists
├── alerts/
│   ├── armitage.yml                 # Already exists
│   ├── motoko.yml                   # NEW
│   └── common.yml                   # NEW
└── grafana/
    └── dashboards/
        ├── armitage.json            # Already exists
        ├── motoko.json              # NEW
        └── ansible.json              # NEW
```

**Checklist:**
- [ ] Validate Prometheus config syntax
- [ ] Validate alert rule syntax
- [ ] Test Grafana dashboard JSON
- [ ] Update scrape targets (use Tailscale hostnames)
- [ ] Document alert thresholds

---

### Category E: Obsolete/Redundant

**Criteria:**
- Scripts replaced by Ansible playbooks
- Duplicate functionality
- Deprecated tools
- Unused scripts

**Action:**
1. Document deprecation reason
2. Add deprecation notice to script
3. Keep for reference period (3 months)
4. Remove after migration period

**Documentation:**
```
docs/migration/DEPRECATED.md
```

---

## Migration Process

### Phase 1: Assessment (Week 1)

1. **Audit motoko-devops:**
   ```bash
   # List all scripts
   find motoko-devops -type f -name "*.sh" -o -name "*.yml" -o -name "*.yaml" > scripts-inventory.txt
   
   # Categorize each script
   # Create spreadsheet: Script | Category | Dependencies | Notes
   ```

2. **Identify Dependencies:**
   - Which scripts call other scripts?
   - Which scripts have hardcoded paths?
   - Which scripts require specific environment?

3. **Document Findings:**
   - Create `docs/migration/SCRIPT_CATALOG.md`
   - List all scripts with categorization
   - Note any blockers or concerns

### Phase 2: Migration (Week 2-3)

1. **Migrate Category A (Ansible Roles):**
   - Start with most-used scripts
   - Convert one role at a time
   - Test each role thoroughly

2. **Migrate Category B (Scripts):**
   - Standardize script format
   - Add error handling
   - Test on target systems

3. **Migrate Category C (Docker Compose):**
   - Validate compose files
   - Test service startup
   - Update documentation

4. **Migrate Category D (Monitoring):**
   - Import dashboards to Grafana
   - Test alert rules
   - Verify metrics collection

### Phase 3: Testing (Week 4)

1. **Test All Migrations:**
   - Run Ansible playbooks with `--check`
   - Execute operational scripts
   - Start Docker Compose services
   - Verify monitoring works

2. **Update Documentation:**
   - Update README references
   - Create migration runbook
   - Document any breaking changes

### Phase 4: Cleanup (Week 5)

1. **Archive motoko-devops:**
   - Create read-only branch
   - Add deprecation notice to README
   - Update all references

2. **Final Verification:**
   - Ensure no broken links
   - Verify all scripts work
   - Confirm monitoring is functional

---

## Script Standardization Template

### Shell Script Template

```bash
#!/bin/bash
# ============================================================================
# Script Name: operation-name.sh
# Description: Brief description of what this script does
# Usage: ./operation-name.sh [options]
# ============================================================================

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="${SCRIPT_DIR}/../logs/$(basename "$0" .sh).log"

# Functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE" >&2
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "$LOG_FILE"
}

# Main
main() {
    log "Starting operation..."
    
    # Script logic here
    
    success "Operation completed successfully"
}

# Run main function
main "$@"
```

---

## Ansible Role Template

### Role Structure

```
ansible/roles/role-name/
├── defaults/
│   └── main.yml              # Default variables
├── vars/
│   └── main.yml              # Role variables (rarely used)
├── tasks/
│   └── main.yml              # Main tasks
├── handlers/
│   └── main.yml              # Handlers
├── templates/
│   └── config.j2             # Jinja2 templates
├── files/
│   └── static-file           # Static files
├── meta/
│   └── main.yml              # Dependencies
└── README.md                  # Role documentation
```

### Example Role: docker

```yaml
# ansible/roles/docker/defaults/main.yml
---
docker_packages:
  - docker.io
  - docker-compose-plugin

docker_service_enabled: true
docker_service_state: started

docker_users:
  - mdt

# ansible/roles/docker/tasks/main.yml
---
- name: Install Docker packages
  apt:
    name: "{{ docker_packages }}"
    state: present
    update_cache: yes

- name: Add users to docker group
  user:
    name: "{{ item }}"
    groups: docker
    append: yes
  loop: "{{ docker_users }}"

- name: Ensure Docker service is running
  systemd:
    name: docker
    enabled: "{{ docker_service_enabled }}"
    state: "{{ docker_service_state }}"
```

---

## Checklist for Each Script Migration

### Pre-Migration
- [ ] Script categorized correctly
- [ ] Dependencies identified
- [ ] Hardcoded paths documented
- [ ] Environment requirements noted

### During Migration
- [ ] Script converted/tested
- [ ] Documentation updated
- [ ] Tests added (if applicable)
- [ ] Reviewed by team

### Post-Migration
- [ ] Old script marked deprecated
- [ ] New location documented
- [ ] References updated
- [ ] Migration verified

---

## Common Migration Patterns

### Pattern 1: Simple Shell Script → Ansible Task

**Before:**
```bash
apt-get update
apt-get install -y docker.io
systemctl enable docker
systemctl start docker
```

**After:**
```yaml
- name: Install Docker
  apt:
    name: docker.io
    state: present
    update_cache: yes

- name: Enable and start Docker
  systemd:
    name: docker
    enabled: true
    state: started
```

### Pattern 2: Complex Script → Ansible Role

**Before:**
```bash
# configure-service.sh
# 200 lines of shell script
```

**After:**
```yaml
# ansible/roles/service/tasks/main.yml
# Modular, testable, idempotent tasks
```

### Pattern 3: Docker Run → Docker Compose

**Before:**
```bash
docker run -d \
  --name service \
  -p 8000:8000 \
  -v /data:/data \
  image:tag
```

**After:**
```yaml
# docker-compose/motoko/service.yml
version: '3.9'
services:
  service:
    image: image:tag
    ports:
      - "8000:8000"
    volumes:
      - /data:/data
```

---

## Tracking Progress

### Migration Spreadsheet Template

| Script | Category | Status | Dependencies | Notes | Assigned To |
|--------|----------|--------|--------------|-------|-------------|
| configure-docker.sh | A | In Progress | None | Converting to role | @user |
| backup-volumes.sh | B | Pending | docker | Needs testing | @user |
| service.yml | C | Complete | None | Migrated | @user |

---

## Questions to Answer During Migration

1. **Is this script still needed?**
   - Check last usage date
   - Verify functionality still required

2. **Can this be automated?**
   - If manual, document why
   - Consider Ansible playbook if repeatable

3. **Are there dependencies?**
   - List all dependencies
   - Ensure they're available

4. **Is this idempotent?**
   - If not, document why
   - Consider making it idempotent

5. **What's the failure mode?**
   - Document error handling
   - Add appropriate checks

---

## References

- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Prometheus Alerting Rules](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/)

---

**Document Version:** 1.0  
**Last Updated:** 2025-01-XX  
**Status:** Draft - Ready for Review

