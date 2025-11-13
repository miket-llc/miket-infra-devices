# Setup Count-Zero for Remote Management

## Quick Setup (On Count-Zero)

Run this script locally on count-zero to enable full remote management:

```bash
cd ~/miket-infra-devices
./devices/count-zero/setup-remote-management.sh
```

This will:
1. ✅ Enable Remote Login (SSH)
2. ✅ Configure Tailscale with SSH + MagicDNS
3. ✅ Set up SSH keys
4. ✅ Verify connectivity

## Add SSH Key from Motoko

After running the setup script on count-zero, add motoko's public key:

**On count-zero:**
```bash
# Get motoko's public key (you'll see it output from motoko)
echo "PASTE_MOTOKO_PUBLIC_KEY_HERE" >> ~/.ssh/authorized_keys
```

**From motoko, get the public key:**
```bash
cat ~/.ssh/id_*.pub
# Copy this and paste it on count-zero
```

Or use a one-liner (if Tailscale SSH works first):
```bash
# From motoko, after Tailscale SSH is enabled
ssh-copy-id -i ~/.ssh/id_rsa.pub mdt@count-zero.pangolin-vega.ts.net
```

## Verify from Motoko

Once setup is complete on count-zero:

```bash
cd /home/mdt/miket-infra-devices

# Test Tailscale SSH
tailscale ssh mdt@count-zero hostname

# Test regular SSH
ssh mdt@count-zero.pangolin-vega.ts.net hostname

# Test Ansible
ansible -i ansible/inventory/hosts.yml count-zero -m ping
ansible -i ansible/inventory/hosts.yml count-zero -m shell -a "uname -a"
```

## What Gets Enabled

### SSH Access
- Remote Login enabled via System Preferences
- SSH daemon running on port 22
- Accessible via Tailscale network only

### Tailscale SSH
- Uses Tailscale identity for authentication
- No password needed
- Automatically encrypted
- Command: `tailscale ssh mdt@count-zero`

### MagicDNS
- Hostname resolution working
- Can ping other devices by name
- No need for IP addresses

### Ansible Management
- Full Ansible playbook support
- Can deploy configurations remotely
- Managed alongside other devices

## Optional: Enable VNC (Screen Sharing)

If you want remote desktop access to count-zero:

```bash
# On count-zero
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart \
  -activate -configure -access -on -restart -agent -privs -all

# Set VNC password
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart \
  -configure -clientopts -setvnclegacy -vnclegacy yes -setvncpw -vncpw YOUR_PASSWORD
```

Then connect from motoko:
```bash
# Forward VNC through SSH tunnel
ssh -L 5900:localhost:5900 mdt@count-zero.pangolin-vega.ts.net
# Then connect VNC client to localhost:5900
```

## Benefits

After setup, you'll be able to:
- ✅ SSH into count-zero from motoko
- ✅ Run Ansible playbooks on count-zero
- ✅ Deploy configurations remotely
- ✅ Manage count-zero like other devices
- ✅ Use hostname resolution everywhere
- ✅ No manual configuration needed for future changes

## See Also
- Full documentation: `devices/count-zero/ENABLE_REMOTE_MANAGEMENT.md`
- Setup script: `devices/count-zero/setup-remote-management.sh`


