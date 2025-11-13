# Windows vLLM Management Playbooks

This directory contains generic playbooks for managing Windows workstations with WSL2, Docker Desktop, NVIDIA GPUs, and vLLM AI models.

## Overview

These playbooks are designed to work with any Windows host that has:
- WSL2 (Ubuntu or similar)
- Docker Desktop
- NVIDIA GPU with drivers
- vLLM container serving an AI model

They automatically detect host-specific configurations from `host_vars/{hostname}.yml`:
- Container name: `vllm-{hostname}` (e.g., `vllm-armitage`, `vllm-wintermute`)
- Model name: Defined in `vllm.served_model_name`
- Port: Defaults to 8000, can be overridden in `vllm.port`

## Playbooks

### `windows-vllm-test.yml`

Comprehensive test playbook that verifies:
- Docker Desktop service status
- Docker CLI availability
- vLLM container status and health
- NVIDIA Container Toolkit installation
- NVIDIA repository configuration
- GPU access from Docker
- Port accessibility
- AI model functionality via LiteLLM proxy

**Usage:**
```bash
# Test all Windows workstations
ansible-playbook -i inventory/hosts.yml playbooks/windows-vllm-test.yml --limit windows_workstations

# Test specific host
ansible-playbook -i inventory/hosts.yml playbooks/windows-vllm-test.yml --limit armitage
ansible-playbook -i inventory/hosts.yml playbooks/windows-vllm-test.yml --limit wintermute
```

### `fix-nvidia-repo-windows.yml`

Fixes broken NVIDIA Container Toolkit repository configurations:
- Detects HTML error pages (404 errors)
- Detects placeholder variables (`$(ARCH)`)
- Removes invalid repository files
- Reconfigures repository with proper architecture detection
- Verifies configuration works

**Usage:**
```bash
# Fix all Windows workstations
ansible-playbook -i inventory/hosts.yml playbooks/fix-nvidia-repo-windows.yml --limit windows_workstations

# Fix specific host
ansible-playbook -i inventory/hosts.yml playbooks/fix-nvidia-repo-windows.yml --limit armitage
```

## Host Configuration

Each Windows workstation should have `host_vars/{hostname}.yml` with:

```yaml
vllm:
  enabled: true
  model: "Qwen/Qwen2.5-7B-Instruct-AWQ"  # HuggingFace model ID
  served_model_name: "qwen2.5-7b-armitage"  # Model name in LiteLLM
  port: 8000
  container_name: "vllm-armitage"  # Docker container name
  image: "vllm/vllm-openai:latest"
  # ... other vLLM configuration options
```

## Shared Scripts

### `scripts/shared/Install-NvidiaContainerToolkit.sh`

Shared script for installing NVIDIA Container Toolkit in WSL2. Used by:
- Generic fix playbook
- Host-specific installation scripts (as reference)

## Legacy Playbooks

The following playbooks are host-specific and kept for backward compatibility:
- `test-armitage-docker-ai.yml` - Use `windows-vllm-test.yml` instead
- `fix-nvidia-repo-armitage.yml` - Use `fix-nvidia-repo-windows.yml` instead
- `check-armitage-vllm.yml` - Use `windows-vllm-test.yml` instead

## Adding New Windows Workstations

1. Add host to `inventory/hosts.yml` under `windows_workstations`
2. Create `host_vars/{hostname}.yml` with vLLM configuration
3. Add password to `group_vars/windows/vault.yml`
4. Run test playbook to verify configuration:
   ```bash
   ansible-playbook -i inventory/hosts.yml playbooks/windows-vllm-test.yml --limit {hostname}
   ```

## Role: `windows-vllm-test`

The `windows-vllm-test` role provides reusable testing tasks. It can be included in other playbooks:

```yaml
roles:
  - windows-vllm-test
```

Variables:
- `vllm_container_name`: Container name (defaults to `vllm-{hostname}`)
- `vllm_port`: vLLM port (defaults to 8000)
- `wsl_distro`: WSL distribution name (defaults to Ubuntu)

