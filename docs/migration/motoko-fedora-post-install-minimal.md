# Motoko Fedora Post-Install: Minimal Remote Access Setup

**Purpose:** After Fedora 43 installation, enable remote access via Tailscale SSH with minimal keystrokes.

**Context:** Team needs to connect from count-zero to complete Ansible-driven configuration.

---

## Minimal Command Set (Copy-Paste Ready)

Execute these commands on motoko's local console after Fedora installation:

```bash
# 1. Install SSH server and Tailscale
sudo dnf install -y openssh-server tailscale

# 2. Enable and start SSH (fallback if Tailscale not ready)
sudo systemctl enable --now sshd

# 3. Install Tailscale (if not in repos, use official installer)
if ! command -v tailscale &>/dev/null; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi

# 4. Connect Tailscale with SSH enabled
# NOTE: Replace <ENROLLMENT_KEY> with key from miket-infra or use manual login
sudo tailscale up \
  --auth-key=<ENROLLMENT_KEY> \
  --advertise-tags=tag:server,tag:linux,tag:ansible \
  --ssh \
  --accept-dns \
  --accept-routes \
  --advertise-routes=192.168.1.0/24
```

**If you don't have enrollment key yet**, use manual login:

```bash
# This will show a URL - open it in browser on another device
sudo tailscale up \
  --advertise-tags=tag:server,tag:linux,tag:ansible \
  --ssh \
  --accept-dns \
  --accept-routes \
  --advertise-routes=192.168.1.0/24
```

---

## One-Liner Version (Absolute Minimum)

If you have the enrollment key ready:

```bash
sudo dnf install -y openssh-server tailscale && sudo systemctl enable --now sshd && curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up --auth-key=<KEY> --advertise-tags=tag:server,tag:linux,tag:ansible --ssh --accept-dns --accept-routes --advertise-routes=192.168.1.0/24
```

---

## Verification

After running the commands, verify Tailscale is connected:

```bash
# Check Tailscale status
tailscale status

# Check SSH is enabled (should show SSH in output)
tailscale status --json | jq '.Self.Capabilities'

# Get Tailscale IP
tailscale ip -4
```

---

## Team Connection Test

From count-zero (or any device on tailnet), test connection:

```bash
# Test Tailscale SSH
tailscale ssh mdt@motoko "hostname"

# Should output: motoko
```

---

## Troubleshooting

### Tailscale not connecting
- Check network connectivity: `ping 8.8.8.8`
- Verify enrollment key is valid (24h expiry)
- Check if device needs approval in Tailscale admin console

### SSH not working
- Verify SSH service: `sudo systemctl status sshd`
- Check Tailscale SSH enabled: `tailscale status --json | jq '.Self.Capabilities'`
- Test local SSH: `ssh mdt@localhost`

### Can't get enrollment key
- Get from miket-infra: `cd ~/miket-infra/infra/tailscale/entra-prod && terraform output -raw enrollment_key`
- Or use manual login (browser-based)

---

## Next Steps (After Team Connects)

Once team can connect via Tailscale SSH, they will:

1. Run bootstrap script: `ansible/scripts/bootstrap-motoko-fedora.sh`
2. Execute Ansible playbooks to complete configuration
3. Deploy PHC services (Docker, vLLM, LiteLLM, etc.)

---

**Last Updated:** 2025-01-XX  
**Status:** Ready for use


