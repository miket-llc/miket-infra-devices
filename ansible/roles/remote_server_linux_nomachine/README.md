# NoMachine Server Role (Linux)

## Overview

Installs and configures NoMachine server on Linux hosts to provide remote desktop access via Tailscale.

## Features

- Installs NoMachine 9.2.18 from reliable mirror source
- Configures session sharing to attach to existing desktop sessions
- Restricts access to Tailscale subnet (100.64.0.0/10)
- Removes conflicting VNC services
- Configures firewall rules (UFW/firewalld)

## Installation Source

### Primary: apt.iteas.at Mirror

NoMachine packages are downloaded from the Austrian mirror `apt.iteas.at`, which hosts official NoMachine .deb packages.

**Mirror URL:** https://apt.iteas.at/iteas/pool/main/n/nomachine/

**Current version:** 9.2.18-3 (amd64)

**Why this mirror?**
- Official NoMachine download.nomachine.com has connectivity issues from some Tailscale networks
- The iteas.at mirror is stable, fast, and doesn't use JavaScript redirects
- Maintained by the Austrian academic network

### Fallback: Local Cache

The role checks `/space/installers/` for cached .deb files before downloading. This adheres to PHC storage invariants.

**Manual cache update:**
```bash
# On any machine with internet access:
wget https://apt.iteas.at/iteas/pool/main/n/nomachine/nomachine_9.2.18_3_amd64.deb

# Copy to target host:
sudo cp nomachine_9.2.18_3_amd64.deb /space/installers/
```

### Alternative Sources (if mirror is down)

1. **Arch AUR source** (tar.gz):
   ```bash
   wget https://download.nomachine.com/download/9.2/Linux/nomachine_9.2.18_3_x86_64.tar.gz
   ```

2. **Other Debian mirrors** (check availability):
   - http://ftp.debian.org/debian/pool/non-free/
   - Various university mirrors

3. **Direct from NoMachine** (requires User-Agent header):
   ```bash
   curl -L --fail \
     -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36' \
     -o nomachine.deb \
     "https://www.nomachine.com/download/download&id=114"
   ```

## Variables

- `nomachine_version`: Version to install (default: "9.2.18")
- `nomachine_port`: Port for NX protocol (default: 4000)
- `session_sharing`: Enable console session sharing (default: true)

## Session Sharing Configuration

The role configures NoMachine to attach to the existing desktop session (e.g., mdt kiosk mode) rather than creating a new virtual session:

```
EnableNewSession 1
EnableConsoleSessionSharing 1
EnableSessionSharing 1
EnableNXDisplayOutput 1
```

This ensures remote users see the same desktop as the physical console.

## Usage

```yaml
# host_vars/motoko.yml
nomachine_version: "9.2.18"
nomachine_port: 4000
session_sharing: true
```

Run the playbook:
```bash
ansible-playbook -i inventory/hosts.yml playbooks/remote_server.yml --limit motoko
```

## Troubleshooting

### Connection Refused
- Check firewall: `sudo ufw status | grep 4000`
- Check service: `sudo systemctl status nxserver`
- Check port: `sudo netstat -tulpn | grep 4000`

### Session Not Visible
- Verify session sharing is enabled: `grep EnableConsoleSessionSharing /usr/NX/etc/server.cfg`
- Check display: `echo $DISPLAY`
- Restart service: `sudo systemctl restart nxserver`

### Download Fails
1. Check if cached: `ls -lh /space/installers/nomachine_9.2.18_3_amd64.deb`
2. Test mirror: `curl -I https://apt.iteas.at/iteas/pool/main/n/nomachine/nomachine_9.2.18_3_amd64.deb`
3. Manual download and cache (see above)

## References

- NoMachine official: https://www.nomachine.com
- iteas.at mirror: https://apt.iteas.at/iteas/pool/main/n/nomachine/
- Arch AUR PKGBUILD: https://aur.archlinux.org/packages/nomachine


