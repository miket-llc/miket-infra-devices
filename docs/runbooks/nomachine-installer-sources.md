# NoMachine Installer Sources and Caching Strategy

**Date:** 2025-11-25  
**Status:** Active  
**Applies to:** All Linux hosts running NoMachine

## Problem

The official NoMachine download server (`download.nomachine.com`, `downloads.nomachine.com`) is unreliable from Tailscale networks:
- Connection timeouts
- 404 errors on direct .deb/.run URLs
- JavaScript redirects that break `wget`/`curl`

## Solution

Use the Austrian academic mirror `apt.iteas.at` as the primary source, with local caching as fallback.

## Primary Source: apt.iteas.at Mirror

**Base URL:** https://apt.iteas.at/iteas/pool/main/n/nomachine/

**Current stable version (as of Nov 2025):**
- **Version:** 9.2.18-3
- **Architecture:** amd64 (x86_64)
- **Direct link:** https://apt.iteas.at/iteas/pool/main/n/nomachine/nomachine_9.2.18_3_amd64.deb

**Download and verify:**
```bash
wget https://apt.iteas.at/iteas/pool/main/n/nomachine/nomachine_9.2.18_3_amd64.deb
dpkg-deb -I nomachine_9.2.18_3_amd64.deb | head -15
```

Expected output:
```
Package: nomachine
Version: 9.2.18-3
Architecture: amd64
Maintainer: NoMachine S.a.r.l. <info@nomachine.com>
```

## Fallback: Local Cache (/space/installers/)

Per PHC storage invariants, installers are cached in `/space/installers/` for offline availability and faster re-installs.

**Cache location:** `/space/installers/nomachine_9.2.18_3_amd64.deb`

**Manual cache update:**
```bash
# 1. Download on any machine with internet access
wget https://apt.iteas.at/iteas/pool/main/n/nomachine/nomachine_9.2.18_3_amd64.deb

# 2. Copy to target host's /space/installers/
# Via SMB:
cp nomachine_9.2.18_3_amd64.deb /mnt/motoko/space/installers/

# Via SCP:
scp nomachine_9.2.18_3_amd64.deb motoko:/tmp/
ssh motoko "sudo mv /tmp/nomachine_9.2.18_3_amd64.deb /space/installers/"
```

## Ansible Implementation

The `remote_server_linux_nomachine` role automatically:
1. Checks `/space/installers/` for cached .deb
2. Uses cached version if available
3. Downloads from `apt.iteas.at` if not cached
4. Installs via `dpkg`
5. Fixes dependencies with `apt -f install`

See: `ansible/roles/remote_server_linux_nomachine/tasks/main.yml`

## Alternative Sources (Emergency)

If `apt.iteas.at` is down:

### Option 1: Arch AUR Source (tar.gz)
```bash
wget https://download.nomachine.com/download/9.2/Linux/nomachine_9.2.18_3_x86_64.tar.gz
sudo tar zxf nomachine_9.2.18_3_x86_64.tar.gz -C /usr
sudo /usr/NX/nxserver --install
```

### Option 2: Official Site (with User-Agent)
```bash
curl -L --fail \
  -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36' \
  -o nomachine_9.2.18_3_amd64.deb \
  "https://www.nomachine.com/download/download&id=114"
```

### Option 3: Temporarily Disable Tailscale
```bash
# If Tailscale routing is causing the block:
sudo tailscale down
wget https://download.nomachine.com/download/9.2/Linux/nomachine_9.2.18_3_x86_64.tar.gz
sudo tailscale up
```

## Version Update Procedure

When updating NoMachine version:

1. **Test download availability:**
   ```bash
   curl -I https://apt.iteas.at/iteas/pool/main/n/nomachine/nomachine_<VERSION>_3_amd64.deb
   ```

2. **Update role defaults:**
   ```yaml
   # ansible/roles/remote_server_linux_nomachine/defaults/main.yml
   nomachine_version: "<NEW_VERSION>"
   ```

3. **Update host-specific overrides if needed:**
   ```yaml
   # ansible/host_vars/motoko.yml
   nomachine_version: "<NEW_VERSION>"
   ```

4. **Update cache:**
   ```bash
   wget https://apt.iteas.at/iteas/pool/main/n/nomachine/nomachine_<VERSION>_3_amd64.deb
   sudo cp nomachine_<VERSION>_3_amd64.deb /space/installers/
   ```

5. **Run playbook:**
   ```bash
   ansible-playbook -i inventory/hosts.yml playbooks/remote_server.yml --limit motoko
   ```

## References

- **iteas.at mirror:** https://apt.iteas.at/iteas/pool/main/n/nomachine/
- **NoMachine official:** https://www.nomachine.com/download
- **Arch AUR package:** https://aur.archlinux.org/packages/nomachine
- **PHC Storage Invariants:** `/space/installers/` for cached installers

## Changelog

- **2025-11-25:** Migrated from `download.nomachine.com` to `apt.iteas.at` mirror due to connectivity issues
- **2025-11-25:** Upgraded from version 8.11.3 to 9.2.18
- **2025-11-25:** Implemented `/space/installers/` caching strategy


