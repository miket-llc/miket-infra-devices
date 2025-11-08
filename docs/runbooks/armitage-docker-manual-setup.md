# Armitage Docker Desktop Setup - Manual Steps

These are one-time setup steps that need to be done interactively on Armitage.

## Prerequisites on Armitage (as Administrator)

### 1. Set up Ubuntu WSL (first time only)

```powershell
# Start Ubuntu for first-time setup
wsl -d Ubuntu

# This will prompt for:
# - Unix username (suggest: mdt)
# - Unix password

# Exit after setup
exit
```

### 2. Start Docker Desktop

```powershell
# Start Docker Desktop
& "C:\Program Files\Docker\Docker\Docker Desktop.exe"

# Wait for it to fully initialize (check system tray icon)
# First startup can take 5-10 minutes
```

### 3. Verify Docker is working

```powershell
docker version
# Should show both Client and Server versions

docker ps
# Should return empty list (no error)
```

## Then Deploy vLLM Scripts via Ansible

From motoko:

```bash
cd /home/mdt/miket-infra-devices
ansible-playbook \
  -i ansible/inventory/hosts.yml \
  ansible/playbooks/armitage-vllm-deploy-scripts.yml \
  --limit armitage \
  --vault-password-file ~/.ansible/vault_pass.txt \
  -e "ansible_password=MonkeyB0y" \
  -v
```

This takes ~30 seconds and just deploys the scripts/config.

## Why Manual Setup?

- WSL Ubuntu requires interactive username/password setup
- Docker Desktop needs to initialize properly (can take 5-10 min first time)
- Trying to automate this leads to 10+ minute playbooks with unclear errors
- Manual setup is faster and you can see what's happening

## One-Time vs Every Time

**One time (manual):**
- Ubuntu WSL setup
- Docker Desktop installation
- Verify Docker works

**Every time (automated via Ansible):**
- Deploy/update vLLM scripts
- Update configuration
- Manage scheduled tasks

This follows IaC/CaC for the things that change, manual for the complex one-time setup.

