# 🚨 MagicDNS Quick Fix - Immediate Action Required

**Status:** Scripts fixed ✅ | Devices need remediation ⚠️

## Quick Fix Commands

### Armitage (Windows)
```powershell
# Run PowerShell as Administrator
cd C:\path\to\miket-infra-devices
.\devices\armitage\scripts\Fix-MagicDNS.ps1
```

### Wintermute (Windows)
```powershell
# Run PowerShell as Administrator
cd C:\path\to\miket-infra-devices
.\devices\wintermute\scripts\Fix-MagicDNS.ps1
```

### Motoko (Linux)
```bash
cd ~/miket-infra-devices
sudo ./devices/motoko/fix-magicdns.sh
```

### Count-Zero (macOS)
```bash
cd ~/miket-infra-devices
./devices/count-zero/fix-magicdns.sh
```

## Verification

After running the fix script, verify it worked:

```bash
# Check DNS is configured
tailscale status --json | jq '.Self.DNS'  # Linux/macOS
tailscale status --json | ConvertFrom-Json | Select-Object -ExpandProperty Self | Select-Object DNS  # Windows

# Test hostname resolution
ping motoko
ping armitage
```

## What Was Fixed

- ✅ `scripts/setup-tailscale.sh` - Added `--accept-dns` flag
- ✅ `scripts/Setup-Tailscale.ps1` - Added `--accept-dns` flag
- ✅ Device-specific quick-fix scripts created for all devices

## Full Documentation

See `docs/runbooks/FIX_MAGICDNS_BROKEN.md` for complete details.

