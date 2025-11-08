# Remote Device Management Playbooks

This directory contains playbooks for managing remote devices (Armitage, Wintermute, etc.).

## Playbooks

- **armitage-vllm-setup.yml** - Deploy vLLM on Armitage
- **wintermute-vllm-deploy-scripts.yml** - Deploy vLLM scripts on Wintermute
- **windows-workstation.yml** - Configure Windows workstations
- **standardize-users.yml** - Standardize users across devices

## Usage

From the repository root:

```bash
# Deploy vLLM on Armitage
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/armitage-vllm-setup.yml \
  --limit armitage

# Configure Windows workstation
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/windows-workstation.yml \
  --limit windows
```

