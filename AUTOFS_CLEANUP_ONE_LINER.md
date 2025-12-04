# Autofs Cleanup - One Command Solution

## Copy/Paste This on count-zero

```bash
sudo bash -c '
DATE=$(date +%Y%m%d-%H%M%S)
echo "=== Autofs Cleanup Starting ==="
[ -f /etc/auto.motoko ] && cp /etc/auto.motoko /etc/auto.motoko.backup-$DATE && echo "✓ Backed up auto.motoko"
cp /etc/auto_master /etc/auto_master.backup-$DATE && echo "✓ Backed up auto_master"
rm -f /etc/auto.motoko && echo "✓ Removed /etc/auto.motoko"
sed -i.cleanup "/^\/Volumes\/motoko/d" /etc/auto_master && echo "✓ Removed motoko from auto_master"
automount -vc && echo "✓ Reloaded automounter"
umount /Volumes/motoko 2>/dev/null && echo "✓ Unmounted /Volumes/motoko" || echo "- /Volumes/motoko not mounted"
echo "=== Cleanup Complete ==="
echo "Backups: /etc/auto_master.backup-$DATE"
mount | grep motoko | grep -v "\.mkt" && echo "WARNING: Unexpected mounts found" || echo "✓ Verified: Only ~/.mkt mounts remain"
'
```

## What This Does

1. ✅ Backs up /etc/auto.motoko and /etc/auto_master
2. ✅ Removes /etc/auto.motoko
3. ✅ Removes /Volumes/motoko entry from /etc/auto_master  
4. ✅ Reloads automounter
5. ✅ Unmounts /Volumes/motoko autofs base
6. ✅ Verifies only ~/.mkt mounts remain

## After Running

Paste the output here or run from motoko:
```bash
ssh miket@count-zero.pangolin-vega.ts.net "mount | grep motoko"
```

Should show ONLY these three:
```
//mdt@motoko/flux on /Users/miket/.mkt/flux (smbfs...)
//mdt@motoko/space on /Users/miket/.mkt/space (smbfs...)
//mdt@motoko/time on /Users/miket/.mkt/time (smbfs...)
```

NO `/Volumes/motoko` should appear.

