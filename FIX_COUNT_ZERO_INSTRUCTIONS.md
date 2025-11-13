# Fix Count-Zero MagicDNS

Count-Zero needs to be fixed locally since SSH is not enabled.

## Run this command on count-zero (local terminal):

```bash
tailscale up --accept-dns --advertise-tags=tag:workstation,tag:macos --ssh
```

## Verify:
```bash
tailscale status --json | jq '.Self.DNS'
ping motoko
```

## Note:
Since you're running Cursor on count-zero and SSH'd into motoko, you need to run this in a LOCAL terminal on count-zero (not in the Cursor terminal which is connected to motoko).


