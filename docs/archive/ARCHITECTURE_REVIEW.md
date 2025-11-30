# Repository Architecture Review & Modernization Plan

**Date:** 2025-01-XX  
**Reviewer:** Senior DevOps & Systems Architect  
**Purpose:** Consolidation of motoko-devops into miket-infra-devices, performance optimization, and vLLM deployment on Motoko

---

## Executive Summary

This document provides a comprehensive review of the `miket-infra-devices` repository structure, identifies areas for consolidation with `motoko-devops`, recommends performance improvements, and proposes a vLLM deployment strategy for Motoko.

### Key Findings

1. **Repository Structure:** Well-organized with clear separation of concerns, but some duplication exists between `inventory/` and `inventories/`
2. **Ansible Configuration:** Good foundation with fact caching and smart gathering, but missing pipelining and SSH ControlPersist optimizations
3. **Observability:** Prometheus/Grafana assets exist but ARA integration is missing; callback plugins are basic
4. **vLLM Deployment:** Currently deployed on Armitage/Wintermute; Motoko needs similar setup for small reasoning/embedding models
5. **Consolidation Opportunity:** motoko-devops scripts should migrate as Ansible roles or standardized scripts

---

## 1. Repository Review & Architecture Assessment

### 1.1 Current Structure Analysis

```
miket-infra-devices/
├── ansible/
│   ├── ansible.cfg              # ✅ Good: Fact caching, smart gathering
│   ├── inventory/              # ✅ Primary inventory (hosts.yml)
│   ├── inventories/            # ⚠️  Duplicate? Contains hosts.ini
│   ├── group_vars/             # ✅ Well-organized by OS groups
│   ├── host_vars/              # ✅ Device-specific overrides
│   ├── playbooks/              # ✅ Organized by purpose
│   ├── roles/                  # ✅ Reusable roles
│   └── deploy-litellm.yml      # ✅ LiteLLM proxy deployment
├── devices/                    # ✅ Device-specific configs
│   ├── inventory.yaml          # ✅ Human-readable device inventory
│   ├── motoko/                 # ⚠️  Minimal config (needs expansion)
│   ├── armitage/               # ✅ Comprehensive config
│   └── wintermute/             # ✅ Comprehensive config
├── scripts/                    # ✅ Bootstrap and deployment scripts
├── tools/                      # ✅ Monitoring and CLI tools
└── docs/                       # ✅ Comprehensive documentation
```

### 1.2 Motoko Configuration Responsibilities

**Motoko manages:**

1. **Self-Management (Localhost):**
   - Docker and Docker Compose services
   - LiteLLM proxy (routing to Armitage/Wintermute)
   - vLLM embeddings service (BGE Base)
   - System services (Samba, AFP, fail2ban, postfix)
   - Backup storage management (`/mnt/lacie`)
   - Docker root management (`/mnt/data/docker`)

2. **Remote Management (via Ansible):**
   - Armitage: vLLM deployment, Windows workstation mode, gaming mode
   - Wintermute: vLLM deployment, Windows workstation mode
   - Count-zero: macOS configuration (minimal)
   - All devices: User standardization, Tailscale configuration

**Recommendation:** Create a clear separation:
- `ansible/playbooks/motoko/` - Self-management playbooks
- `ansible/playbooks/remote/` - Remote device management
- `devices/motoko/` - Expand with comprehensive config similar to Armitage/Wintermute

### 1.3 Inventory Structure Issues

**Current State:**
- `ansible/inventory/hosts.yml` - Primary YAML inventory (✅ Used)
- `ansible/inventories/hosts.ini` - INI format (⚠️ Unused?)
- `devices/inventory.yaml` - Human-readable device metadata (✅ Documentation)

**Recommendation:**
- **Keep:** `ansible/inventory/hosts.yml` (primary)
- **Remove or Document:** `ansible/inventories/hosts.ini` (if unused, delete; if legacy, document)
- **Keep:** `devices/inventory.yaml` (documentation only)

---

## 2. Consolidation Plan: motoko-devops → miket-infra-devices

### 2.1 Migration Strategy

**Principle:** Convert motoko-devops scripts into Ansible roles, standardized scripts, or Docker Compose workflows where appropriate.

### 2.2 Script Categorization Framework

When reviewing motoko-devops, categorize scripts as:

#### **Category A: Ansible Roles** (Infrastructure as Code)
- System configuration tasks
- Service deployments
- Package management
- User management
- **Example:** `motoko-devops/scripts/configure-docker.sh` → `ansible/roles/docker/tasks/main.yml`

#### **Category B: Standardized Scripts** (Operational Tools)
- One-off maintenance tasks
- Backup scripts
- Health checks
- **Location:** `scripts/operations/` or `scripts/maintenance/`
- **Example:** `motoko-devops/scripts/backup-docker.sh` → `scripts/operations/backup-docker.sh`

#### **Category C: Docker Compose** (Service Definitions)
- Service definitions that belong in Docker Compose
- **Location:** `docker-compose/` or `services/`
- **Example:** `motoko-devops/docker/textgen-webui.yml` → `docker-compose/textgen-webui.yml`

#### **Category D: Grafana/Prometheus** (Observability)
- Monitoring configurations
- Alert rules
- Dashboard definitions
- **Location:** `tools/monitoring/` (already exists)
- **Example:** `motoko-devops/monitoring/alerts.yml` → `tools/monitoring/alerts/`

#### **Category E: Obsolete/Redundant**
- Scripts replaced by Ansible playbooks
- Duplicate functionality
- **Action:** Document deprecation, remove after migration period

### 2.3 Recommended Directory Structure (Post-Consolidation)

```
miket-infra-devices/
├── ansible/
│   ├── ansible.cfg              # Enhanced with pipelining, ControlPersist
│   ├── inventory/
│   │   └── hosts.yml            # Single source of truth
│   ├── group_vars/
│   │   ├── all/
│   │   │   └── vault.yml        # Encrypted secrets
│   │   ├── linux/
│   │   ├── windows/
│   │   └── motoko.yml           # Motoko-specific vars
│   ├── host_vars/
│   │   ├── motoko/
│   │   ├── armitage/
│   │   └── wintermute/
│   ├── playbooks/
│   │   ├── motoko/              # NEW: Self-management
│   │   │   ├── self-configure.yml
│   │   │   ├── deploy-vllm.yml
│   │   │   └── deploy-services.yml
│   │   ├── remote/              # NEW: Remote device management
│   │   │   ├── armitage-vllm-setup.yml
│   │   │   └── windows-workstation.yml
│   │   └── common/              # Shared task files
│   └── roles/
│       ├── docker/              # NEW: From motoko-devops
│       ├── vllm/                # NEW: Unified vLLM role
│       ├── litellm_proxy/       # ✅ Existing
│       ├── monitoring/          # ✅ Existing
│       └── common/              # ✅ Existing
├── devices/
│   ├── inventory.yaml           # Documentation only
│   ├── motoko/
│   │   ├── config.yml           # Expand with full config
│   │   └── services/            # Service-specific configs
│   ├── armitage/                # ✅ Existing
│   └── wintermute/              # ✅ Existing
├── scripts/
│   ├── bootstrap/               # Bootstrap scripts
│   ├── operations/              # NEW: Operational scripts from motoko-devops
│   │   ├── backup/
│   │   ├── maintenance/
│   │   └── health-checks/
│   └── deployment/              # Deployment wrappers
├── docker-compose/              # NEW: Service definitions
│   ├── motoko/
│   │   ├── litellm.yml
│   │   ├── vllm-embeddings.yml
│   │   └── textgen-webui.yml    # If migrated
│   └── README.md
├── tools/
│   ├── monitoring/              # ✅ Existing
│   │   ├── prometheus.yml
│   │   ├── alerts/
│   │   └── grafana/
│   └── cli/                     # ✅ Existing
└── docs/
    ├── architecture/
    ├── runbooks/
    └── migration/               # NEW: motoko-devops migration docs
```

### 2.4 Migration Checklist

**Phase 1: Assessment**
- [ ] Audit motoko-devops repository structure
- [ ] Categorize all scripts (A-E)
- [ ] Identify dependencies between scripts
- [ ] Document any hardcoded paths or assumptions

**Phase 2: Migration**
- [ ] Convert Category A scripts to Ansible roles
- [ ] Move Category B scripts to `scripts/operations/`
- [ ] Migrate Category C to `docker-compose/`
- [ ] Consolidate Category D into `tools/monitoring/`
- [ ] Deprecate Category E scripts

**Phase 3: Testing**
- [ ] Test all migrated playbooks/roles
- [ ] Verify script functionality
- [ ] Update documentation
- [ ] Create migration runbook

**Phase 4: Cleanup**
- [ ] Update README references
- [ ] Remove motoko-devops references
- [ ] Archive motoko-devops (read-only)
- [ ] Update CI/CD if applicable

---

## 3. Performance & Observability Improvements

### 3.1 Ansible Performance Optimizations

#### **Current Configuration Analysis**

**✅ Good:**
- `gathering = smart` - Reduces fact collection overhead
- `fact_caching = jsonfile` - Caches facts for 1 hour
- WinRM timeouts configured (600s)

**⚠️ Missing:**
- SSH pipelining (reduces SSH overhead by ~50%)
- SSH ControlPersist (reuses SSH connections)
- Fork optimization (parallel execution)
- ARA integration (Ansible Run Analysis)

#### **Recommended ansible.cfg Updates**

```ini
[defaults]
# Existing settings...
inventory = inventory/hosts.yml
vault_password_file = /home/mdt/miket-infra-devices/scripts/ansible-vault-password.sh
stdout_callback = yaml
display_skipped_hosts = True
display_ok_hosts = True
show_task_path_on_failure = True
retry_files_enabled = False
host_key_checking = False
timeout = 600
command_timeout = 600

# Performance optimizations
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_facts
fact_caching_timeout = 3600

# NEW: SSH Performance
[ssh_connection]
# Enable pipelining (reduces SSH round-trips)
pipelining = True
# Reuse SSH connections (ControlPersist)
control_path_dir = ~/.ansible/cp
# Increase SSH timeout for slow connections
timeout = 30
# Use persistent connections
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o ServerAliveInterval=30

# NEW: Parallel execution
[defaults]
# Increase forks for parallel execution (adjust based on system resources)
forks = 10
# Use linear strategy for better output, or free for maximum parallelism
strategy = free

# WinRM settings (existing)
[winrm]
read_timeout = 600
operation_timeout = 600
connection_timeout = 60

# Logging (existing)
[logging]
log_path = /tmp/ansible.log
```

**Performance Impact:**
- **Pipelining:** ~50% reduction in SSH overhead
- **ControlPersist:** ~30% faster on subsequent runs
- **Forks:** 2-5x faster for multi-host playbooks
- **Combined:** 3-5x overall speedup for typical playbooks

### 3.2 Observability Enhancements

#### **Current State:**
- Basic callback: `yaml` (structured output)
- Logging to `/tmp/ansible.log`
- Prometheus/Grafana assets exist but not integrated with Ansible runs

#### **Recommended Additions:**

**A. ARA (Ansible Run Analysis) Integration**

ARA provides a web UI for Ansible playbook runs, showing:
- Playbook execution history
- Task timing and failures
- Host facts and variables
- Playbook comparisons

**Installation (on Motoko):**
```bash
# Install ARA server
pip3 install ara[server]
ara-manage migrate

# Configure Ansible callback
pip3 install ara[server]
```

**ansible.cfg addition:**
```ini
[defaults]
callback_plugins = /usr/local/lib/python3.10/site-packages/ara/plugins/callbacks
action_plugins = /usr/local/lib/python3.10/site-packages/ara/plugins/actions
```

**B. Prometheus Ansible Exporter**

Export Ansible run metrics to Prometheus:
- Playbook execution duration
- Task success/failure rates
- Host reachability

**C. Enhanced Callback Plugins**

```ini
[defaults]
# Use timer callback for better timing visibility
stdout_callback = timer
# Or use community.general.profile_tasks for detailed timing
# Requires: ansible-galaxy collection install community.general
```

**D. Grafana Dashboard for Ansible**

Create dashboard showing:
- Playbook execution trends
- Task failure rates by host
- Average execution times
- Success rate over time

**Location:** `tools/monitoring/grafana/dashboards/ansible.json`

### 3.3 Monitoring Integration Points

**Current:** Prometheus config exists but needs:
1. **Ansible metrics exporter** - Track playbook runs
2. **vLLM metrics** - Already planned for Motoko
3. **Docker metrics** - Container health and resource usage
4. **System metrics** - Already configured (node_exporter)

**Recommendation:** Create unified monitoring playbook:
```yaml
# ansible/playbooks/monitoring/deploy-exporters.yml
- name: Deploy monitoring exporters
  hosts: all
  roles:
    - role: monitoring
      vars:
        exporters:
          - node_exporter      # Linux
          - windows_exporter   # Windows
          - dcgm_exporter      # GPU (Linux)
          - docker_exporter    # Docker (Motoko)
```

---

## 4. vLLM Setup on Motoko

### 4.1 Requirements

**Hardware:**
- GPU: NVIDIA GeForce RTX 2080 (8GB VRAM)
- Use case: Small reasoning/embedding models for knowledge graph building

**Models Recommended:**
1. **Reasoning:** Mistral-7B-Instruct-AWQ (~4GB VRAM) or Gemma-2-2B-IT (~2GB VRAM)
2. **Embeddings:** BGE-Base-en-v1.5 (~1GB VRAM) - Already deployed

**Constraints:**
- RTX 2080 has 8GB VRAM
- Need to share GPU between reasoning and embeddings
- Should leave headroom for other services

### 4.2 Deployment Strategy

#### **Option A: Single vLLM Container with Multiple Models** (Recommended)

**Pros:**
- Single container, easier management
- vLLM supports multiple models in one instance
- Better GPU memory sharing

**Cons:**
- Models loaded on-demand (slower first request)
- More complex configuration

**Implementation:**
```yaml
# docker-compose/motoko/vllm-reasoning.yml
version: '3.9'
services:
  vllm-reasoning:
    image: vllm/vllm-openai:latest
    container_name: vllm-reasoning-motoko
    command: >
      --model mistralai/Mistral-7B-Instruct-v0.2-AWQ
      --quantization awq
      --host 0.0.0.0
      --port 8001
      --max-model-len 4096
      --gpu-memory-utilization 0.50
      --tensor-parallel-size 1
    ports:
      - "8001:8001"
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
    restart: unless-stopped
    networks:
      - default
```

#### **Option B: Separate Containers** (Simpler, More Resource-Heavy)

**Pros:**
- Simpler configuration
- Independent scaling/restarts
- Clear separation

**Cons:**
- Two containers competing for GPU
- Need careful GPU memory allocation

**Implementation:**
```yaml
# docker-compose/motoko/vllm-services.yml
version: '3.9'
services:
  vllm-reasoning:
    image: vllm/vllm-openai:latest
    container_name: vllm-reasoning-motoko
    command: >
      --model mistralai/Mistral-7B-Instruct-v0.2-AWQ
      --quantization awq
      --host 0.0.0.0
      --port 8001
      --gpu-memory-utilization 0.45
    ports:
      - "8001:8001"
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              device_ids: ['0']
              capabilities: [gpu]
    environment:
      - CUDA_VISIBLE_DEVICES=0
    restart: unless-stopped

  vllm-embeddings:
    image: vllm/vllm-openai:latest
    container_name: vllm-embeddings-motoko
    command: >
      --model BAAI/bge-base-en-v1.5
      --host 0.0.0.0
      --port 8200
      --gpu-memory-utilization 0.30
    ports:
      - "8200:8200"
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              device_ids: ['0']
              capabilities: [gpu]
    environment:
      - CUDA_VISIBLE_DEVICES=0
    restart: unless-stopped
```

**Recommendation:** Use **Option B** initially for simplicity, migrate to Option A if needed.

### 4.3 Ansible Role for vLLM on Motoko

**Create:** `ansible/roles/vllm-motoko/`

```yaml
# ansible/roles/vllm-motoko/defaults/main.yml
---
vllm_reasoning_enabled: true
vllm_reasoning_model: "mistralai/Mistral-7B-Instruct-v0.2-AWQ"
vllm_reasoning_port: 8001
vllm_reasoning_gpu_util: 0.45
vllm_reasoning_max_len: 4096

vllm_embeddings_enabled: true
vllm_embeddings_model: "BAAI/bge-base-en-v1.5"
vllm_embeddings_port: 8200
vllm_embeddings_gpu_util: 0.30
```

**Playbook:**
```yaml
# ansible/playbooks/motoko/deploy-vllm.yml
---
- name: Deploy vLLM services on Motoko
  hosts: motoko
  become: true
  roles:
    - role: vllm-motoko
```

### 4.4 LiteLLM Integration

**Update:** `ansible/group_vars/motoko.yml`

```yaml
# Add Motoko reasoning model to LiteLLM config
motoko_reasoning_base_url: "http://motoko:8001/v1"
motoko_reasoning_model_name: "local/reasoning"
motoko_reasoning_model_display: "openai/mistral-7b-instruct-awq"

# Embeddings already configured
motoko_embed_base_url: "http://motoko:8200/v1"
```

**Update LiteLLM config template** to include Motoko reasoning model.

### 4.5 Systemd Service (Alternative to Docker Compose)

If preferred over Docker Compose:

```ini
# /etc/systemd/system/vllm-reasoning@motoko.service
[Unit]
Description=vLLM Reasoning Service (%i)
After=network-online.target docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/docker run -d \
  --name vllm-reasoning-motoko \
  --gpus all \
  -p 8001:8001 \
  vllm/vllm-openai:latest \
  python -m vllm.entrypoints.openai.api_server \
  --model mistralai/Mistral-7B-Instruct-v0.2-AWQ \
  --quantization awq \
  --host 0.0.0.0 \
  --port 8001 \
  --gpu-memory-utilization 0.45
ExecStop=/usr/bin/docker stop vllm-reasoning-motoko
Restart=always
RestartSec=15

[Install]
WantedBy=multi-user.target
```

**Recommendation:** Use Docker Compose for easier management and configuration.

### 4.6 GPU Allocation Strategy

**Memory Budget (8GB RTX 2080):**
- Reasoning model (Mistral-7B-AWQ): ~3.5GB (45% util)
- Embeddings (BGE-Base): ~1GB (30% util)
- System overhead: ~1GB
- **Total:** ~5.5GB used, 2.5GB headroom

**Monitoring:**
- Use `nvidia-smi` or DCGM exporter
- Alert if GPU memory > 90%
- Track model load times

---

## 5. Recommended Directory Structure (Final)

### 5.1 Proposed Structure

```
miket-infra-devices/
├── ansible/
│   ├── ansible.cfg              # Enhanced with performance opts
│   ├── inventory/
│   │   └── hosts.yml            # Single source of truth
│   ├── group_vars/
│   │   ├── all/
│   │   │   └── vault.yml
│   │   ├── linux/
│   │   ├── windows/
│   │   └── motoko.yml           # Motoko-specific vars
│   ├── host_vars/
│   │   ├── motoko/
│   │   ├── armitage/
│   │   └── wintermute/
│   ├── playbooks/
│   │   ├── motoko/              # Self-management
│   │   │   ├── self-configure.yml
│   │   │   ├── deploy-vllm.yml
│   │   │   ├── deploy-services.yml
│   │   │   └── deploy-litellm.yml
│   │   ├── remote/              # Remote management
│   │   │   ├── armitage-vllm-setup.yml
│   │   │   ├── wintermute-vllm-setup.yml
│   │   │   └── windows-workstation.yml
│   │   └── common/              # Shared tasks
│   └── roles/
│       ├── vllm-motoko/         # NEW: Motoko vLLM role
│       ├── vllm/                # Unified vLLM role (refactor)
│       ├── litellm_proxy/       # Existing
│       ├── monitoring/          # Existing
│       ├── docker/              # NEW: From motoko-devops
│       └── common/              # Existing
├── devices/
│   ├── inventory.yaml           # Documentation
│   ├── motoko/
│   │   ├── config.yml          # Expanded config
│   │   └── services/           # Service configs
│   ├── armitage/               # Existing
│   └── wintermute/             # Existing
├── scripts/
│   ├── bootstrap/              # Bootstrap scripts
│   ├── operations/             # NEW: Operational scripts
│   │   ├── backup/
│   │   ├── maintenance/
│   │   └── health-checks/
│   └── deployment/             # Deployment wrappers
├── docker-compose/             # NEW: Service definitions
│   ├── motoko/
│   │   ├── litellm.yml
│   │   ├── vllm-reasoning.yml
│   │   ├── vllm-embeddings.yml
│   │   └── docker-compose.yml  # Main compose file
│   └── README.md
├── tools/
│   ├── monitoring/
│   │   ├── prometheus.yml
│   │   ├── alerts/
│   │   └── grafana/
│   │       └── dashboards/
│   │           ├── armitage.json
│   │           ├── motoko.json  # NEW
│   │           └── ansible.json # NEW
│   └── cli/
└── docs/
    ├── architecture/
    │   ├── ARCHITECTURE_REVIEW.md  # This document
    │   └── tailnet.md
    ├── runbooks/
    └── migration/              # NEW: motoko-devops migration
        ├── MIGRATION_PLAN.md
        └── SCRIPT_CATALOG.md
```

### 5.2 Files to Remove/Consolidate

**Remove:**
- `ansible/inventories/hosts.ini` (if unused)
- Duplicate playbook files (consolidate into `motoko/` or `remote/`)

**Consolidate:**
- `ansible/deploy-litellm.yml` → `ansible/playbooks/motoko/deploy-litellm.yml`
- `ansible/playbooks/deploy-motoko-embeddings.yml` → `ansible/playbooks/motoko/deploy-vllm.yml` (combine)

---

## 6. Implementation Priority

### Phase 1: Immediate (Week 1-2)
1. ✅ Enhance `ansible.cfg` with performance optimizations
2. ✅ Create `ansible/playbooks/motoko/` directory structure
3. ✅ Deploy vLLM reasoning on Motoko (Option B: Docker Compose)
4. ✅ Update LiteLLM config to include Motoko reasoning

### Phase 2: Short-term (Week 3-4)
1. ✅ Audit motoko-devops repository
2. ✅ Migrate Category A scripts to Ansible roles
3. ✅ Set up ARA for Ansible observability
4. ✅ Create Grafana dashboard for Ansible runs
5. ✅ Expand `devices/motoko/config.yml`

### Phase 3: Medium-term (Month 2)
1. ✅ Complete motoko-devops migration
2. ✅ Consolidate inventory files
3. ✅ Create unified monitoring playbook
4. ✅ Document all changes

### Phase 4: Long-term (Month 3+)
1. ✅ Optimize vLLM deployment (consider Option A)
2. ✅ Refine GPU allocation strategy
3. ✅ Add Prometheus Ansible exporter
4. ✅ Archive motoko-devops repository

---

## 7. Key Recommendations Summary

### ✅ Do:
1. **Separate self-management from remote management** - Clear playbook organization
2. **Enable SSH pipelining and ControlPersist** - Significant performance gains
3. **Deploy vLLM on Motoko** - Use Docker Compose with separate containers initially
4. **Integrate ARA** - Better Ansible run visibility
5. **Consolidate motoko-devops** - Migrate as Ansible roles where possible
6. **Expand Motoko config** - Match Armitage/Wintermute detail level

### ❌ Don't:
1. **Don't mix self-management and remote playbooks** - Keep separation clear
2. **Don't duplicate inventory files** - Single source of truth
3. **Don't over-allocate GPU memory** - Leave headroom for system
4. **Don't skip testing** - Test all migrations thoroughly
5. **Don't delete motoko-devops immediately** - Archive after migration period

### ⚠️ Considerations:
1. **GPU memory is limited** - Monitor usage closely
2. **Windows WinRM timeouts** - Already configured, but monitor
3. **Tailscale dependencies** - Ensure ACLs are deployed before Ansible runs
4. **Vault management** - Ensure age encryption is working correctly

---

## 8. Next Steps

1. **Review this document** with the team
2. **Audit motoko-devops** repository structure
3. **Create migration tickets** for each phase
4. **Begin Phase 1 implementation** (performance optimizations + vLLM)
5. **Set up ARA** for better observability
6. **Document progress** in migration runbook

---

## Appendix A: Performance Benchmarking

### Before Optimizations (Estimated)
- Playbook execution: ~5-10 minutes for 3 hosts
- SSH overhead: ~40% of total time
- Fact gathering: ~20% of total time

### After Optimizations (Expected)
- Playbook execution: ~2-3 minutes for 3 hosts
- SSH overhead: ~15% (pipelining + ControlPersist)
- Fact gathering: ~10% (caching)

**Expected improvement: 2-3x faster**

---

## Appendix B: vLLM Model Comparison

| Model | Size (AWQ) | VRAM | MMLU | Best For |
|-------|-----------|------|------|----------|
| Mistral-7B-Instruct-AWQ | ~4GB | 3.5GB | 60.1 | Reasoning, general tasks |
| Gemma-2-2B-IT-AWQ | ~2GB | 1.5GB | 42.3 | Light reasoning, fast |
| Gemma-2-9B-IT-AWQ | ~5GB | 4.5GB | 66.3 | Better reasoning (tight fit) |

**Recommendation:** Start with Mistral-7B-Instruct-AWQ for best balance.

---

**Document Version:** 1.0  
**Last Updated:** 2025-01-XX  
**Status:** Draft - Pending Review

