#!/usr/bin/env bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.
#
# Bootstrap Motoko After Fedora 43 Installation
# Installs RPM Fusion, Ansible, and runs fedora-base playbook
#
# Usage (from count-zero):
#   ssh mdt@motoko 'bash -s' < ./ansible/scripts/bootstrap-motoko-fedora.sh
#
# Or (on motoko):
#   ~/miket-infra-devices/ansible/scripts/bootstrap-motoko-fedora.sh

set -euo pipefail

echo "=========================================="
echo "Motoko Fedora 43 Bootstrap"
echo "=========================================="
echo ""

# 1. Enable RPM Fusion repositories
echo "[1/5] Enabling RPM Fusion repositories..."
if ! dnf repolist | grep -q rpmfusion; then
  sudo dnf install -y \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
  echo "  ✅ RPM Fusion enabled"
else
  echo "  ✅ RPM Fusion already enabled"
fi

# 2. Install Python and Ansible
echo ""
echo "[2/5] Installing Python and Ansible..."
sudo dnf install -y python3 python3-pip ansible-core
echo "  ✅ Ansible installed: $(ansible --version | head -1)"

# 3. Clone or update miket-infra-devices
echo ""
echo "[3/5] Cloning/updating miket-infra-devices repository..."
REPO_DIR="${HOME}/miket-infra-devices"

if [ ! -d "${REPO_DIR}" ]; then
  echo "  Cloning repository..."
  git clone git@github.com:miket-llc/miket-infra-devices.git "${REPO_DIR}" || \
  git clone https://github.com/miket-llc/miket-infra-devices.git "${REPO_DIR}"
  echo "  ✅ Repository cloned"
else
  echo "  Updating repository..."
  cd "${REPO_DIR}"
  git pull
  echo "  ✅ Repository updated"
fi

# 4. Run Ansible playbook for Fedora base configuration
echo ""
echo "[4/5] Running Ansible playbook: fedora-base.yml..."
cd "${REPO_DIR}/ansible"

if [ -f "playbooks/motoko/fedora-base.yml" ]; then
  ansible-playbook -i inventory/hosts.yml \
    playbooks/motoko/fedora-base.yml \
    --limit motoko \
    --connection=local
  echo "  ✅ Ansible playbook complete"
else
  echo "  ⚠️  playbooks/motoko/fedora-base.yml not found"
  echo "  Running fallback: verify-phc-services.yml"
  ansible-playbook -i inventory/hosts.yml \
    playbooks/motoko/verify-phc-services.yml \
    --limit motoko \
    --connection=local || true
fi

# 5. Verification
echo ""
echo "[5/5] Verifying bootstrap..."

# Check storage mounts
echo ""
echo "Storage mounts:"
df -h | grep -E '(space|flux|time)' || echo "  ⚠️  PHC storage not mounted yet"

# Check Docker
echo ""
echo "Docker:"
if command -v docker &>/dev/null; then
  docker --version
  systemctl is-active docker &>/dev/null && echo "  ✅ Docker running" || echo "  ⚠️  Docker not running"
else
  echo "  ⚠️  Docker not installed yet"
fi

# Check Tailscale
echo ""
echo "Tailscale:"
if command -v tailscale &>/dev/null; then
  tailscale status --self 2>/dev/null | head -5 || echo "  ⚠️  Tailscale not connected yet"
else
  echo "  ⚠️  Tailscale not installed yet"
fi

# Check NVIDIA
echo ""
echo "NVIDIA:"
if command -v nvidia-smi &>/dev/null; then
  nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader || echo "  ⚠️  NVIDIA driver needs reboot"
else
  echo "  ⚠️  NVIDIA drivers not installed yet (may need reboot)"
fi

echo ""
echo "=========================================="
echo "Bootstrap Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. If NVIDIA drivers were installed, reboot:"
echo "   sudo reboot"
echo ""
echo "2. After reboot, verify services:"
echo "   cd ~/miket-infra-devices/ansible"
echo "   ansible-playbook -i inventory/hosts.yml \\"
echo "     playbooks/motoko/verify-phc-services.yml \\"
echo "     --limit motoko --connection=local"
echo ""
echo "3. Deploy Docker services:"
echo "   ansible-playbook -i inventory/hosts.yml \\"
echo "     playbooks/motoko/deploy-vllm.yml \\"
echo "     --limit motoko --connection=local"
echo ""
echo "   ansible-playbook -i inventory/hosts.yml \\"
echo "     playbooks/motoko/deploy-litellm.yml \\"
echo "     --limit motoko --connection=local"
echo ""


