# Armitage End-to-End Test Notes

**Last Updated:** 2025-12-06  
**Purpose:** Document validation steps for armitage as Fedora KDE + Ollama LLM node.

## Test Environment

- **Device:** armitage (Alienware Gaming Laptop)
- **OS:** Fedora 41 KDE
- **GPU:** NVIDIA GeForce RTX 4070 (8GB VRAM)
- **Tailnet:** pangolin-vega.ts.net
- **Tags:** linux, gpu, llm_node

## Test Categories

### 1. Automation Account Tests

#### standardize-users Playbook
```bash
# Run from motoko
ansible-playbook -i inventory/hosts.yml playbooks/remote/standardize-users.yml --limit armitage
```

**Expected Results:**
- [ ] mdt user exists
- [ ] mdt has sudo/NOPASSWD
- [ ] SSH works over tailnet: `ssh mdt@armitage.pangolin-vega.ts.net`

### 2. Desktop Playbook Tests

#### KDE Installation
```bash
ansible-playbook -i inventory/hosts.yml playbooks/workstations/armitage-fedora-kde-ollama.yml --tags desktop
```

**Expected Results:**
- [ ] KDE Plasma packages installed
- [ ] SDDM enabled as display manager
- [ ] Graphical target is default
- [ ] Second run shows `changed=0` (idempotent)

#### Idempotency Check
```bash
# Run twice, second run should be idempotent
ansible-playbook -i inventory/hosts.yml playbooks/workstations/armitage-fedora-kde-ollama.yml --tags desktop
ansible-playbook -i inventory/hosts.yml playbooks/workstations/armitage-fedora-kde-ollama.yml --tags desktop
```

**Expected Results:**
- [ ] First run: installs packages, configures SDDM
- [ ] Second run: `changed=0`

### 3. LLM/Ollama Playbook Tests

#### Ollama Installation
```bash
ansible-playbook -i inventory/hosts.yml playbooks/workstations/armitage-fedora-kde-ollama.yml --tags llm
```

**Expected Results:**
- [ ] Ollama binary installed at `/usr/local/bin/ollama`
- [ ] Ollama systemd service created and running
- [ ] ollama user/group created
- [ ] Model directories created under /flux and /space
- [ ] Health check script deployed
- [ ] Second run shows `changed=0` (idempotent)

### 4. Secrets Sync Tests

```bash
ansible-playbook -i inventory/hosts.yml playbooks/secrets-sync.yml --limit armitage
```

**Expected Results:**
- [ ] /flux/runtime/secrets/ai-fabric.env created
- [ ] /flux/runtime/secrets/tailscale.env created
- [ ] Permissions are 0600/0640
- [ ] Second run shows `changed=0` (idempotent)

### 5. Functional Tests

#### KDE Session
1. [ ] Reboot armitage
2. [ ] SDDM login screen appears
3. [ ] Login as interactive user (miket)
4. [ ] KDE Plasma desktop loads
5. [ ] Konsole opens
6. [ ] Dolphin file manager works
7. [ ] Basic apps launch (Kate, Spectacle)

#### Ollama API (Local)
```bash
# On armitage
curl http://localhost:11434/api/tags
```

**Expected Results:**
- [ ] Returns JSON with model list
- [ ] Models include qwen2.5:7b and/or llama3.2:3b

#### Ollama API (Tailnet)
```bash
# From count-zero or another tailnet device
curl http://armitage.pangolin-vega.ts.net:11434/api/tags
```

**Expected Results:**
- [ ] Returns JSON with model list
- [ ] Connection is fast and stable

#### SSH via Tailnet
```bash
# From count-zero or motoko
ssh mdt@armitage.pangolin-vega.ts.net
```

**Expected Results:**
- [ ] SSH connection succeeds
- [ ] No password prompt (key auth)
- [ ] sudo works without password

#### Model Inference
```bash
# Test local inference
curl http://localhost:11434/api/generate -d '{
  "model": "qwen2.5:7b",
  "prompt": "What is 2+2?",
  "stream": false
}'
```

**Expected Results:**
- [ ] Response within reasonable time (5-10 seconds)
- [ ] GPU acceleration visible in nvidia-smi
- [ ] Coherent response

### 6. Firewall Validation

#### From Tailnet Device
```bash
# Should SUCCEED
curl http://armitage.pangolin-vega.ts.net:11434/api/tags
curl http://armitage.pangolin-vega.ts.net:8000/health  # If gateway enabled
ssh mdt@armitage.pangolin-vega.ts.net
```

**Expected Results:**
- [ ] Port 11434 accessible
- [ ] Port 8000 accessible (if enabled)
- [ ] SSH accessible

#### From Non-Tailnet (if possible to test)
```bash
# Should FAIL (ports blocked)
curl http://[armitage-local-ip]:11434/api/tags
```

**Expected Results:**
- [ ] Connection refused or timeout
- [ ] LLM ports not accessible from non-tailnet

### 7. GPU Validation

```bash
# On armitage
nvidia-smi
```

**Expected Results:**
- [ ] NVIDIA driver loaded
- [ ] RTX 4070 detected
- [ ] 8GB VRAM shown
- [ ] No errors

```bash
# During inference
watch -n 1 nvidia-smi
```

**Expected Results:**
- [ ] GPU utilization spikes during inference
- [ ] VRAM usage shows model loaded
- [ ] Temperature reasonable (<80°C)

## Test Log

### [DATE] - [Tester Initials]

| Test | Result | Notes |
|------|--------|-------|
| mdt user exists | ☐ | |
| SSH via tailnet | ☐ | |
| KDE session works | ☐ | |
| Ollama API local | ☐ | |
| Ollama API tailnet | ☐ | |
| Firewall blocks non-tailnet | ☐ | |
| Playbook idempotent | ☐ | |

### Issues Found

(Document any issues encountered during testing)

### Resolution

(Document how issues were resolved)

## Definition of Done Checklist

Based on the acceptance criteria:

- [ ] armitage appears only as Fedora KDE Linux workstation + gpu + llm_node in inventory
- [ ] Windows partition documented as out-of-band (never on tailnet)
- [ ] KDE Plasma fully managed by Ansible, ready for akira rollout
- [ ] Ollama LLM stack deployed and working:
  - [ ] Follows Flux/Space conventions
  - [ ] Respects AI Fabric contract (ports, env vars, secrets)
  - [ ] Reachable over tailnet per llm_node ACLs
  - [ ] Protected by host firewall
- [ ] akira's vLLM stack untouched and still working
- [ ] All "armitage on Windows" references removed from live docs
- [ ] Runbooks exist for rebuilding and troubleshooting
- [ ] This E2E test note is checked in

## Sign-off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Tester | | | |
| Reviewer | | | |


