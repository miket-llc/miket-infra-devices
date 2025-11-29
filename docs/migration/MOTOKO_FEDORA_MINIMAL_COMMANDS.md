# Motoko Fedora Post-Install: Minimal Commands

**USE THIS:** Copy-paste these commands on motoko's console after Fedora installation.

---

## Option 1: With Enrollment Key (Recommended)

```bash
sudo dnf install -y openssh-server tailscale && sudo systemctl enable --now sshd && curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up --auth-key=<ENROLLMENT_KEY> --advertise-tags=tag:server,tag:linux,tag:ansible --ssh --accept-dns --accept-routes --advertise-routes=192.168.1.0/24
```

**Replace `<ENROLLMENT_KEY>` with:**
- Get from miket-infra: `cd ~/miket-infra/infra/tailscale/entra-prod && terraform output -raw enrollment_key`
- Or use manual login (see Option 2)

---

## Option 2: Manual Login (If No Key Available)

```bash
sudo dnf install -y openssh-server tailscale && sudo systemctl enable --now sshd && curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up --advertise-tags=tag:server,tag:linux,tag:ansible --ssh --accept-dns --accept-routes --advertise-routes=192.168.1.0/24
```

**Then:** Open the URL shown in browser on another device to authenticate.

---

## Verify Connection

```bash
tailscale status
```

**Expected output:** Shows motoko connected with SSH enabled.

---

## Team Test (From count-zero)

```bash
tailscale ssh mdt@motoko "hostname"
```

**Should output:** `motoko`

---

**That's it!** Once connected, team will complete configuration via Ansible.


