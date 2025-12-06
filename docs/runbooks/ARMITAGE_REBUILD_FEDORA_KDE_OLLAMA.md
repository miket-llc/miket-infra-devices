# Armitage Rebuild: Fedora KDE + Ollama LLM Node

**Last Updated:** 2025-12-06  
**Scope:** Rebuild armitage from bare metal to fully working Fedora KDE workstation with Ollama LLM capabilities.

## Architecture References

- **ADR-004:** KDE Plasma is the standard desktop for all Linux UI nodes
- **ADR-005:** Workstations use LLAMA/Ollama pattern; servers use vLLM
- **AI_FABRIC_SERVICE.md:** Dual-pattern LLM architecture
- **AI_FABRIC_PLATFORM_CONTRACT.md:** Node topology, ports 11434/8000

## Prerequisites

- Fedora 41 KDE Spin installation media
- Network connectivity (Ethernet recommended for initial setup)
- Tailscale account access for joining tailnet
- Azure Key Vault access (for secrets sync)

## Phase 1: Fedora KDE Installation

### 1.1 Download Fedora KDE Spin

```bash
# Download from https://fedoraproject.org/spins/kde/download
# SHA256 verify the ISO
```

### 1.2 Install Fedora

1. Boot from USB installer
2. Select language: English (US)
3. Installation destination:
   - Choose the primary NVMe SSD (2TB)
   - Use automatic partitioning (Btrfs recommended)
   - **IMPORTANT:** Leave small Windows partition untouched if present (Dell support)
4. Create user accounts:
   - `mdt` - automation account (sudo access, no password login)
   - `miket` - interactive user account
5. Complete installation and reboot

### 1.3 First Boot Configuration

```bash
# Login as miket, open Konsole

# Update system
sudo dnf upgrade -y

# Install essential tools
sudo dnf install -y git curl wget vim

# Clone infrastructure repo
git clone https://github.com/miket-infra/miket-infra-devices.git ~/dev/miket-infra-devices
```

## Phase 2: Tailscale Join and Tag Application

### 2.1 Install Tailscale

```bash
# Add Tailscale repo
curl -fsSL https://tailscale.com/install.sh | sh

# Start and enable service
sudo systemctl enable --now tailscaled

# Authenticate and apply tags
sudo tailscale up --advertise-tags=tag:linux,tag:gpu,tag:llm_node
```

### 2.2 Verify Tailnet Connectivity

```bash
# Check status
tailscale status

# Verify hostname
tailscale status --self

# Expected output should show:
# armitage   100.x.x.x   linux   gpu   llm_node

# Test connectivity to motoko
ping motoko.pangolin-vega.ts.net
```

## Phase 3: Ansible Playbook Execution

### 3.1 Prerequisites on motoko (Ansible control node)

```bash
# SSH to motoko
ssh mdt@motoko.pangolin-vega.ts.net

# Update inventory
cd ~/dev/miket-infra-devices

# Verify armitage is reachable
ansible armitage -i ansible/inventory/hosts.yml -m ping
```

### 3.2 Run Full Deployment Playbook

```bash
# Check mode first (dry run)
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/workstations/armitage-fedora-kde-ollama.yml \
  --check

# Full deployment
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/workstations/armitage-fedora-kde-ollama.yml

# Expected phases:
# 1. linux_desktop_base     - Common packages, fonts, time sync
# 2. linux_desktop_kde      - KDE Plasma desktop
# 3. firewalld_tailnet      - Host firewall
# 4. secrets_sync           - AKV → .env files
# 5. llm_workstation_ollama - Ollama LLM runtime
# 6. common_dev_tools       - Development tools
# 7. podman_standard_linux  - Container runtime
# 8. workstation_gui_tools  - GUI applications
```

### 3.3 Individual Role Execution (if needed)

```bash
# Desktop only
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/workstations/armitage-fedora-kde-ollama.yml \
  --tags desktop

# LLM only
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/workstations/armitage-fedora-kde-ollama.yml \
  --tags llm

# Firewall only
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/workstations/armitage-fedora-kde-ollama.yml \
  --tags firewall
```

## Phase 4: Validation

### 4.1 KDE Desktop Validation

```bash
# Verify SDDM is default display manager
sudo systemctl status sddm

# Check default target
systemctl get-default
# Expected: graphical.target

# Reboot and verify KDE session starts
sudo systemctl reboot
```

### 4.2 Ollama LLM Validation

```bash
# Check Ollama service
sudo systemctl status ollama

# Test local API
curl http://localhost:11434/api/tags

# Expected response: {"models":[{"name":"qwen2.5:7b",...}]}

# Run a test generation
curl http://localhost:11434/api/generate -d '{
  "model": "qwen2.5:7b",
  "prompt": "Hello, world!",
  "stream": false
}'
```

### 4.3 Tailnet Connectivity Validation

From another tailnet device (e.g., count-zero):

```bash
# Test Ollama API over tailnet
curl http://armitage.pangolin-vega.ts.net:11434/api/tags

# Test SSH over tailnet
ssh mdt@armitage.pangolin-vega.ts.net

# Gateway port (if enabled)
curl http://armitage.pangolin-vega.ts.net:8000/health
```

### 4.4 Firewall Validation

```bash
# On armitage - verify firewall zones
sudo firewall-cmd --list-all-zones

# Expected: tailnet zone with ports 11434, 8000, 4000, ssh
# Expected: public zone with NO ssh, NO LLM ports

# From non-tailnet network (temporarily disconnect Tailscale)
# LLM ports should be BLOCKED
```

## Phase 5: Idempotency Check

```bash
# Run playbook again - should show 0 changes
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/workstations/armitage-fedora-kde-ollama.yml

# Expected: "changed=0" for all tasks
```

## Filesystem Layout (Flux/Space/Time)

After deployment, the filesystem should be organized as:

```
/flux/
├── apps/
│   └── ollama/           # Ollama binary and config
│       └── bin/
│           └── ollama-health.sh
└── runtime/
    └── secrets/          # .env files from AKV
        ├── ai-fabric.env
        └── tailscale.env

/space/
└── llm/
    └── ollama/
        ├── models/       # Model weights (multi-GB)
        └── data/         # Runtime data

/time/
└── (backups only - not used for active data)
```

## Windows Partition Note

If a Windows partition exists, it is:
- ❌ **NOT** on tailnet
- ❌ **NOT** managed by Ansible
- ❌ **NOT** used for any workloads

It exists solely for Dell support, diagnostics, and firmware updates.

## Troubleshooting

### Ollama Not Starting

```bash
# Check logs
sudo journalctl -u ollama -f

# Common issues:
# - GPU drivers not installed: Run nvidia_gpu_fedora role
# - Permission issues: Check ollama user exists
# - Port conflict: Verify nothing else on 11434
```

### KDE Session Not Starting

```bash
# Check SDDM status
sudo systemctl status sddm

# Force graphical target
sudo systemctl set-default graphical.target
sudo systemctl isolate graphical.target
```

### Tailnet Connectivity Issues

```bash
# Check Tailscale status
tailscale status

# Check firewall
sudo firewall-cmd --zone=tailnet --list-all

# Verify DNS resolution
nslookup motoko.pangolin-vega.ts.net
```

## Related Runbooks

- [LLM Workstation Usage and Troubleshooting](./LLM_WORKSTATION_USAGE_AND_TROUBLESHOOTING.md)
- [Tailscale Device Setup](./TAILSCALE_DEVICE_SETUP.md)
- [Device Health Check](./device-health-check.md)

