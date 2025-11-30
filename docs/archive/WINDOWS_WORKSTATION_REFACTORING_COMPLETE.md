# Windows Workstation Refactoring - Complete

Date: $(date '+%Y-%m-%d %H:%M:%S')

## Summary

Successfully refactored and deployed consistent configuration across all Windows workstations (armitage and wintermute) with Docker Desktop.

## Changes Made

### 1. Inventory Structure
**File:** `ansible/inventory/hosts.yml`
- Created `windows_workstations` group under `windows`
- Both armitage and wintermute now grouped together
- Allows targeting all Windows workstations with a single group

### 2. Shared Configuration
**File:** `ansible/group_vars/windows_workstations/main.yml`
- Created shared configuration for all Windows workstations
- Defines consistent paths, Docker settings, vLLM defaults
- User account: `mdt` (local account only)
- Docker credential store: disabled
- vLLM paths and settings standardized

### 3. Role Updates
**File:** `ansible/roles/windows-vllm-deploy/defaults/main.yml`
- Updated to use hardcoded `mdt` user in paths
- Added config_dest variable
- Consistent path structure: `C:\Users\mdt\dev\{hostname}\scripts\`

### 4. Playbook Updates
**Files:**
- `ansible/playbooks/configure-windows-rdp.yml` - Now targets `windows_workstations`
- `ansible/playbooks/windows-vllm-deploy.yml` - Defaults to `windows_workstations`

Both playbooks now work consistently for all Windows workstations.

### 5. Documentation Updates
**Files:**
- `docs/reference/account-architecture.md` - Removed Microsoft account references
- `docs/runbooks/armitage-docker-nvidia-debug.md` - Updated paths to use `mdt` user
- `docs/WINDOWS_WORKSTATION_CONSISTENCY.md` - New comprehensive guide
- `docs/armitage-connectivity-troubleshooting.md` - Troubleshooting guide

### 6. User Account Simplification
- **Old:** Mixed use of `mdt` and `mdt_@msn.com` Microsoft accounts
- **New:** Consistent use of `mdt` local account only
- **Benefit:** No Docker credential helper issues, simpler automation

## Deployment Results

### Armitage
✅ RDP: Configured with Group Policy
✅ Docker: Config deployed to mdt user
✅ vLLM: Scripts deployed to C:\Users\mdt\dev\armitage\scripts\
✅ Container: vllm-armitage running
✅ Scheduled Task: Armitage Auto Mode Switcher created

### Wintermute
✅ RDP: Configured with Group Policy  
✅ Docker: Config deployed to mdt user
✅ vLLM: Scripts deployed to C:\Users\mdt\dev\wintermute\scripts\
✅ Container: vllm-wintermute running (was already running, updated config)
✅ Scheduled Task: Wintermute Auto Mode Switcher created

## Consistency Verification

Both workstations now have:
- Same user account structure (`mdt`)
- Same path patterns (`C:\Users\mdt\dev\{hostname}\`)
- Same Docker configuration
- Same RDP settings
- Same PowerShell scripts
- Same scheduled task configuration

## Configuration Hierarchy

1. **Group Variables** (`group_vars/windows_workstations/main.yml`)
   - Shared settings for all Windows workstations
   - User paths, Docker config, vLLM defaults

2. **Host Variables** (`host_vars/{hostname}.yml`)
   - Hardware specifications
   - Roles
   - Remote desktop settings

3. **Device Configuration** (`devices/{hostname}/config.yml`)
   - Device-specific vLLM settings
   - Model selection (based on GPU VRAM)
   - Performance tuning

This hierarchy allows:
- Shared configuration to be defined once
- Device-specific overrides where needed
- Easy addition of new Windows workstations

## Deployment Commands

### Deploy to all Windows workstations:
```bash
# RDP configuration
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/configure-windows-rdp.yml

# Docker and vLLM
ansible-playbook -i inventory/hosts.yml playbooks/windows-vllm-deploy.yml
```

### Deploy to specific workstation:
```bash
# RDP
ansible-playbook -i inventory/hosts.yml playbooks/configure-windows-rdp.yml --limit armitage

# Docker and vLLM
ansible-playbook -i inventory/hosts.yml playbooks/windows-vllm-deploy.yml -e "target_hosts=armitage"
```

## Benefits

1. **Simplified user management** - One local account per machine
2. **Consistent configuration** - Same structure across all Windows workstations
3. **Easier maintenance** - Changes apply to all machines via group_vars
4. **No Docker auth issues** - Credential store disabled for all
5. **Scalable** - Easy to add new Windows workstations
6. **Clear separation** - Shared vs device-specific configuration

## API Endpoints

- Armitage: http://armitage.pangolin-vega.ts.net:8000/v1
- Wintermute: http://wintermute.pangolin-vega.ts.net:8000/v1

## RDP Connections

- Armitage: armitage.pangolin-vega.ts.net:3389
- Wintermute: wintermute.pangolin-vega.ts.net:3389

## Files Modified

1. `ansible/inventory/hosts.yml` - Added windows_workstations group
2. `ansible/group_vars/windows_workstations/main.yml` - Created shared config
3. `ansible/playbooks/configure-windows-rdp.yml` - Updated to target windows_workstations
4. `ansible/playbooks/windows-vllm-deploy.yml` - Updated default target
5. `ansible/roles/windows-vllm-deploy/defaults/main.yml` - Hardcoded mdt user
6. `docs/reference/account-architecture.md` - Removed Microsoft account references
7. `docs/runbooks/armitage-docker-nvidia-debug.md` - Updated paths
8. `docs/WINDOWS_WORKSTATION_CONSISTENCY.md` - Created consistency guide

## Migration Notes

When migrating from Microsoft account to local mdt account:
1. Delete Microsoft account from Windows (e.g., mdt_@msn.com)
2. Ensure local `mdt` account exists and is administrator
3. Run deployments via Ansible (automatically uses correct paths)
4. All paths automatically use `C:\Users\mdt\` 

## Conclusion

All Windows workstations are now consistently configured using IaC/CaC principles through Ansible. The configuration is maintainable, scalable, and follows best practices for infrastructure as code.



