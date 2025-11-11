# Quick Setup Guide: Motoko as Ansible Control Node

## One-Command Setup

From motoko, run:

```bash
curl -fsSL https://raw.githubusercontent.com/miket-llc/miket-infra-devices/main/scripts/bootstrap-motoko.sh | bash
```

Or if you've already cloned the repo:

```bash
cd ~/miket-infra-devices
./scripts/bootstrap-motoko.sh
```

## What This Does

1. **Clones miket-infra-devices** (if not already present)
2. **Configures Tailscale** with tags: `tag:server,tag:linux,tag:ansible`
3. **Installs Ansible** and required dependencies (pywinrm for Windows)
4. **Tests connectivity** to all devices
5. **Verifies setup** is complete

## Manual Setup (Alternative)

If you prefer manual setup:

```bash
# 1. Clone repository
git clone https://github.com/miket-llc/miket-infra-devices.git ~/miket-infra-devices
cd ~/miket-infra-devices

# 2. Configure Tailscale
./scripts/setup-tailscale.sh motoko

# 3. Install Ansible
sudo apt update
sudo apt install -y ansible python3-pip python3-jmespath
pip3 install pywinrm

# 4. Test connectivity
ansible all -i ansible/inventory/hosts.yml -m ping
```

## Verify Setup

After setup, verify everything works:

```bash
cd ~/miket-infra-devices

# Check Tailscale tags
tailscale status --json | jq '.Self.Tags'

# Test SSH to other devices
tailscale ssh mdt@count-zero.pangolin-vega.ts.net "hostname"

# Test Ansible connectivity
ansible all -i ansible/inventory/hosts.yml -m ping
```

## Next Steps

Once motoko is set up, you can:

1. **Set up armitage** - Follow `docs/runbooks/armitage.md`
2. **Run playbooks** - See `docs/runbooks/motoko-ansible-setup.md`
3. **Manage devices** - Use Ansible from motoko to configure all devices

## Troubleshooting

### Tailscale not connecting
- Ensure you have an enrollment key from miket-infra
- Check ACLs are deployed: `cd ~/miket-infra/infra/tailscale/entra-prod && terraform plan`

### Ansible can't reach devices
- Verify devices are online: `tailscale status`
- Check tags are correct: `tailscale status --json | jq '.Self.Tags'`
- For Windows devices, ensure WinRM is enabled

See `docs/runbooks/motoko-ansible-setup.md` for detailed troubleshooting.

