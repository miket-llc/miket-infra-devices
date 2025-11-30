# TODO

## Known Issues

### armitage→wintermute SSH fails (Windows→Windows)

**Status**: Unresolved  
**Priority**: Low (workaround exists)  
**Date**: 2025-11-30

**Symptom**: SSH from armitage to wintermute fails with "Permission denied" despite correct keys.

**Error in Windows Event Log**:
```
sshd: ssh_dispatch_run_fatal: Connection from authenticating user mdt 100.72.64.90 port XXXXX: Unknown error [preauth]
```

**What works**:
- wintermute→armitage ✅
- All other 11/12 SSH routes ✅

**Debugging done**:
- Key fingerprints match ✅
- File permissions identical ✅
- sshd_config identical ✅
- Same Windows build (26200) ✅
- Same OpenSSH version (9.5p2) ✅
- Service account both LocalSystem ✅
- Network direct (no DERP relay) ✅
- Firewall allows Tailscale range ✅
- Regenerated keys multiple times ✅
- Cleaned authorized_keys file ✅

**Suspected cause**: Unknown Windows OpenSSH bug or corrupted installation on wintermute.

**Potential fix**: Reinstall OpenSSH Server on wintermute:
```powershell
Remove-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Restart-Computer
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
```

**Workaround**: Route through motoko:
```bash
ssh motoko
ssh wintermute
```

---

## Backlog

### Remove stale host entry from Tailscale ACL

**Location**: `miket-infra/infra/tailscale/entra-prod/main.tf` line ~239

```hcl
hosts = {
  "motoko" = "100.94.209.28"  # STALE - should be removed
}
```

MagicDNS handles this automatically - the `hosts` block can be removed.

