#!/bin/bash
# Bootstrap script to enable passwordless sudo for mdt on armitage
# This is a one-time bootstrap step before Ansible can fully manage the host

set -e

echo "==================================================="
echo "Armitage Bootstrap: Enable Passwordless Sudo"
echo "==================================================="

# Create sudoers.d file for mdt
echo "Creating /etc/sudoers.d/mdt with NOPASSWD..."

# This will prompt for the password once
sudo tee /etc/sudoers.d/mdt > /dev/null << 'EOF'
# Ansible automation account - passwordless sudo
mdt ALL=(ALL) NOPASSWD: ALL
EOF

sudo chmod 440 /etc/sudoers.d/mdt

echo ""
echo "Verifying passwordless sudo..."
sudo -n whoami

echo ""
echo "==================================================="
echo "✅ Bootstrap complete!"
echo ""
echo "You can now run Ansible playbooks from motoko:"
echo "  cd ~/dev/miket-infra-devices/ansible"
echo "  ansible-playbook -i inventory/hosts.yml playbooks/deploy-armitage-fedora-kde.yml"
echo "==================================================="



