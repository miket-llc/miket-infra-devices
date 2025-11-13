# Remote Device Management Playbooks

This directory contains playbooks for managing remote devices (Armitage, Wintermute, etc.).

## Playbooks

- **armitage-vllm-setup.yml** - Deploy vLLM on Armitage
- **wintermute-vllm-deploy-scripts.yml** - Deploy vLLM scripts on Wintermute (includes Docker Desktop reconfiguration)
- **windows-workstation.yml** - Configure Windows workstations
- **standardize-users.yml** - Standardize users across devices

## Rebuilding Windows Workstations

After account migration or Docker issues, rebuild with:

```bash
# 1. Configure WSL2 (removes Ubuntu 22.04, ensures 24.04, configures Docker)
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/configure-wsl2-windows.yml \
  --limit wintermute \
  --ask-vault-pass

# 2. Deploy vLLM scripts (reconfigures Docker Desktop, deploys scripts)
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/remote/wintermute-vllm-deploy-scripts.yml \
  --limit wintermute \
  --ask-vault-pass
```

## Usage

From the repository root:

```bash
# Deploy vLLM on Armitage
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/remote/armitage-vllm-setup.yml \
  --limit armitage \
  --ask-vault-pass

# Deploy vLLM scripts on Wintermute
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/remote/wintermute-vllm-deploy-scripts.yml \
  --limit wintermute \
  --ask-vault-pass

# Configure Windows workstation
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/remote/windows-workstation.yml \
  --limit windows_workstations \
  --ask-vault-pass
```

