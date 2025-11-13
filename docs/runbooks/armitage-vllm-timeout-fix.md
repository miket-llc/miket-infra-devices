# Armitage vLLM Deployment - WinRM Timeout Fix

## Problem
WinRM timeouts were occurring during the Armitage vLLM deployment, particularly during the Docker wait task which runs asynchronously for up to 5 minutes. Default WinRM timeouts (30-60 seconds) were too short for long-running operations.

## Solution (IaC/CaC Compliant)

All changes follow Infrastructure as Code (IaC) and Configuration as Code (CaC) principles:

### 1. WinRM Timeout Configuration
**File:** `ansible/ansible.cfg` (NEW)
- WinRM timeout settings configured in `[winrm]` section (not as inventory variables)
- `read_timeout = 600` (10 minutes)
- `operation_timeout = 600` (10 minutes)
- `connection_timeout = 60` (1 minute)
- Note: These settings must be in `ansible.cfg`, not in inventory variables, as pywinrm doesn't support `ansible_winrm_*` inventory variables

### 2. Enhanced Playbook Observability
**File:** `ansible/playbooks/armitage-vllm-setup.yml`
- Improved Docker wait task with:
  - Better progress indicators (percentage, remaining time)
  - Timestamped output for each check
  - Clear success/failure messages
- Added deployment duration tracking
- Enhanced async task configuration (360s async, 15s poll interval)
- Added explicit timeout to prevent hanging

### 3. Ansible Configuration
**File:** `ansible/ansible.cfg` (NEW)
- Global timeout settings
- WinRM defaults
- Better output formatting
- Logging enabled for troubleshooting

### 4. Deployment Script
**File:** `scripts/deploy-armitage-vllm.sh` (NEW)
- Convenient wrapper script with enhanced observability
- Shows start/end times
- Verbose output by default
- Proper error handling

### 5. Documentation Updates
**File:** `docs/runbooks/armitage-vllm.md`
- Added WinRM timeout troubleshooting section
- Updated deployment instructions
- Added verification steps

## Usage

### Quick Start (Recommended)
```bash
./scripts/deploy-armitage-vllm.sh
```

### Manual Deployment
```bash
cd ansible
ansible-playbook -i inventory/hosts.yml \
  playbooks/armitage-vllm-setup.yml \
  --limit armitage \
  --ask-vault-pass \
  -v
```

## Verification

### Check WinRM Timeout Settings
```bash
# WinRM timeout settings are configured in ansible.cfg [winrm] section
# Verify by checking ansible.cfg:
grep -A 5 "^\[winrm\]" ansible/ansible.cfg
```

### Test WinRM Connection
```bash
ansible armitage -i ansible/inventory/hosts.yml -m win_ping -vvv
```

## What Changed

1. **WinRM timeouts increased** from default (30-60s) to 600s (10 minutes)
2. **Async task polling** improved (15s intervals instead of 10s)
3. **Progress visibility** enhanced with timestamps and percentages
4. **Deployment tracking** added (start time, duration)
5. **Error handling** improved with better timeout management

## Expected Behavior

- **Before:** Playbook would timeout after 30-60 seconds during Docker wait
- **After:** Playbook can handle operations up to 10 minutes without timing out
- **Observability:** Real-time progress updates every 15 seconds during Docker wait
- **Duration:** Full deployment typically completes in 5-10 minutes (depending on Docker initialization)

## Files Modified/Created

- ✅ `ansible/ansible.cfg` (NEW) - WinRM timeout settings configured here
- ✅ `ansible/group_vars/windows/main.yml` (MODIFIED) - Removed unsupported WinRM timeout variables
- ✅ `ansible/playbooks/armitage-vllm-setup.yml` (MODIFIED)
- ✅ `scripts/deploy-armitage-vllm.sh` (NEW)
- ✅ `docs/runbooks/armitage-vllm.md` (MODIFIED)

All changes are committed to version control and follow IaC/CaC principles.


