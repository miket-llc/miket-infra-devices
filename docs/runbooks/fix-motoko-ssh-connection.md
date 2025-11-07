# Fix: mdt@motoko SSH Connection

## Problem

When connecting from other nodes, `mdt@motoko` wasn't working because:

1. **SSH config on client had wrong IP**: `~/.ssh/config` on the connecting machine had the old Tailscale IP (`100.111.12.30`) instead of the current one (`100.92.23.71`)

2. **Hostname resolution**: `motoko` resolves to local network IP (`192.168.1.201`) via `/etc/hosts`, not the Tailscale IP

## Solutions

### Option 1: Use Tailscale SSH (Recommended)
```bash
tailscale ssh mdt@motoko
```
This works immediately - no SSH keys needed, uses Tailscale authentication.

### Option 2: Use MagicDNS
```bash
ssh mdt@motoko.tail2e55fe.ts.net
```
This resolves to the Tailscale IP automatically.

### Option 3: Fix SSH Config on Client Machine

On the **client machine** (the one connecting TO motoko), update `~/.ssh/config`:

```ssh
Host motoko
    Hostname 100.92.23.71  # Current Tailscale IP
    User mdt
    # For Tailscale SSH, no keys needed
    # For regular SSH, add: IdentityFile ~/.ssh/id_rsa
```

Or use MagicDNS:
```ssh
Host motoko motoko.tail2e55fe.ts.net
    Hostname motoko.tail2e55fe.ts.net
    User mdt
```

### Option 4: Add to /etc/hosts on Client

On the client machine, add:
```
100.92.23.71 motoko
```

But this is less ideal than using MagicDNS.

## Why Regular SSH Might Fail

Regular SSH (`ssh mdt@motoko`) requires:
- SSH keys set up between client and server
- Host key verification

Tailscale SSH (`tailscale ssh mdt@motoko`) works because:
- Uses Tailscale's built-in authentication
- No SSH keys needed
- Handles host key verification automatically

## Recommended Approach

**Use Tailscale SSH** - it's the simplest and most secure:
```bash
tailscale ssh mdt@motoko
```

This works from any node on the tailnet without any configuration.

