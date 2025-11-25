# Warp Terminal Role

**Author:** MikeT LLC (Codex-PD-002)  
**Created:** 2025-11-25  
**Status:** Active  

## Overview

This Ansible role installs [Warp Terminal](https://www.warp.dev/), a modern Rust-based terminal with AI-powered features, on PHC endpoints.

## Supported Platforms

| Platform | Status | Notes |
|----------|--------|-------|
| Ubuntu/Debian (Linux) | ✅ Full | Primary target (motoko) |
| macOS | ✅ Full | Via Homebrew Cask |
| Windows | ⚠️ Beta | Manual installation recommended |

## Requirements

### Linux (Debian/Ubuntu)
- `wget` and `gpg` for repository setup
- apt package manager

### macOS
- Homebrew must be installed

### Windows
- Manual installation from warp.dev (beta)

## Role Variables

```yaml
# defaults/main.yml
warp_terminal_enabled: true
warp_apt_key_url: "https://releases.warp.dev/linux/keys/warp.asc"
warp_apt_repo: "deb [arch=amd64 signed-by=/usr/share/keyrings/warp-keyring.gpg] https://releases.warp.dev/linux/deb stable main"
warp_package_name: "warp-terminal"
```

## Usage

### Deploy to specific host

```bash
ansible-playbook -i inventory/hosts.yml playbooks/deploy-warp-terminal.yml --limit motoko
```

### Deploy to all Linux servers

```bash
ansible-playbook -i inventory/hosts.yml playbooks/deploy-warp-terminal.yml --limit linux
```

### As part of base deployment

Include in your deployment playbook:

```yaml
- hosts: linux_servers
  roles:
    - role: warp_terminal
      tags:
        - warp
        - terminal
```

## Post-Installation

1. Launch Warp Terminal: `warp-terminal` (Linux) or open Warp.app (macOS)
2. Sign in with your Warp account (free tier available)
3. Configure settings as needed

## PHC Integration

- Warp Terminal integrates with the existing terminal workflow
- Works seamlessly with Tailscale SSH connections
- AI features can be used for command assistance

## Dependencies

This role has no dependencies on other PHC roles.

## License

Copyright (c) 2025 MikeT LLC. All rights reserved.

