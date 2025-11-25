#!/bin/bash
# ONE-LINER DNS FIX - Copy and paste this entire command on motoko
# Run: sudo bash -c 'INTERFACE=$(ip route | grep default | awk "{print \$5}" | head -1); resolvectl dns $INTERFACE 1.1.1.1 1.0.0.1; resolvectl flush-caches; ping -c 1 google.com && echo "DNS works" || echo "DNS failed"; if ! command -v tailscale &> /dev/null; then curl -fsSL https://tailscale.com/install.sh | sh; fi; systemctl enable tailscaled 2>/dev/null; systemctl start tailscaled; sleep 3; tailscale up --advertise-tags=tag:server,tag:linux,tag:ansible --accept-dns --accept-routes --ssh --advertise-routes=192.168.1.0/24 --advertise-exit-node; sleep 3; resolvectl dns $INTERFACE 100.100.100.100 1.1.1.1 1.0.0.1; resolvectl flush-caches; echo "Done! Testing..."; ping -c 1 google.com && echo "✓ Regular DNS works" || echo "✗ Regular DNS failed"; ping -c 1 motoko.pangolin-vega.ts.net && echo "✓ MagicDNS works" || echo "⚠ MagicDNS may need a moment"; tailscale status | head -5'


