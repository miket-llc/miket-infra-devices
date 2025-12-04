# Manual Step Required: Remove Autofs on count-zero

## Context

We're in Phase 2 of the "unfuck & polish" process. The server (motoko) has been updated with macOS optimizations, and now we need to remove autofs from count-zero. 

Due to Tailscale SSH limitations and count-zero's sudo password requirement, this step needs to be performed **interactively** on count-zero itself.

---

## Instructions

### On count-zero (macOS laptop), run:

```bash
# Copy the script from motoko
scp miket@motoko.pangolin-vega.ts.net:/tmp/remove-autofs-count-zero.sh /tmp/

# Or download directly (script content below)
```

### Script Content

Save this as `/tmp/remove-autofs-count-zero.sh` on count-zero:

```bash
#!/bin/bash
# Remove autofs configuration for PHC mounts on count-zero
# Run with sudo

set -e

echo "=== Removing autofs configuration for PHC mounts ==="
echo ""

# Backup files
DATE=$(date +%Y%m%d)
echo "[1/6] Creating backups..."
if [ -f /etc/auto.motoko ]; then
    cp /etc/auto.motoko "/etc/auto.motoko.backup-$DATE"
    echo "  ✓ Backed up /etc/auto.motoko"
fi
cp /etc/auto_master "/etc/auto_master.backup-$DATE"
echo "  ✓ Backed up /etc/auto_master"
echo ""

# Remove autofs map file
echo "[2/6] Removing autofs map file..."
if [ -f /etc/auto.motoko ]; then
    rm -f /etc/auto.motoko
    echo "  ✓ Removed /etc/auto.motoko"
else
    echo "  - /etc/auto.motoko not found (already removed)"
fi
echo ""

# Remove entry from auto_master
echo "[3/6] Removing entry from /etc/auto_master..."
sed -i.bak '/^\/Volumes\/motoko/d' /etc/auto_master
echo "  ✓ Removed /Volumes/motoko entry"
echo ""

# Reload automounter
echo "[4/6] Reloading automounter..."
automount -vc
echo "  ✓ Automounter reloaded"
echo ""

# Unmount shares
echo "[5/6] Unmounting autofs shares..."
umount /Volumes/motoko/space 2>/dev/null && echo "  ✓ Unmounted space" || echo "  - space not mounted"
umount /Volumes/motoko/flux 2>/dev/null && echo "  ✓ Unmounted flux" || echo "  - flux not mounted"
umount /Volumes/motoko 2>/dev/null && echo "  ✓ Unmounted /Volumes/motoko" || echo "  - /Volumes/motoko not mounted"
echo ""

# Remove old symlinks
echo "[6/6] Removing old root-owned symlinks..."
rm -f /Users/miket/flux /Users/miket/space /Users/miket/time
echo "  ✓ Removed old symlinks"
echo ""

echo "=== Autofs removal complete ==="
echo ""
echo "Backups:"
echo "  - /etc/auto_master.backup-$DATE"
echo "  - /etc/auto.motoko.backup-$DATE (if existed)"
echo ""
echo "Next steps:"
echo "  1. Verify mounts are gone: mount | grep autofs"
echo "  2. Continue with Phase 3 from motoko"
```

### Run the script:

```bash
chmod +x /tmp/remove-autofs-count-zero.sh
sudo /tmp/remove-autofs-count-zero.sh
```

You'll be prompted for your sudo password. Enter it and the script will complete.

### Verify completion:

```bash
# Should show NO autofs mounts for motoko
mount | grep -E 'autofs.*motoko|smbfs.*motoko'

# Should show empty or no output for old symlinks
ls -la ~/flux ~/space ~/time 2>&1
```

---

## Alternative: Passwordless Sudo (Optional)

If you want to enable Ansible automation without password prompts in the future, you can configure passwordless sudo for specific commands:

```bash
# On count-zero
sudo visudo -f /etc/sudoers.d/ansible-nopasswd

# Add this line:
miket ALL=(ALL) NOPASSWD: /usr/sbin/automount, /sbin/mount_smbfs, /sbin/umount, /bin/rm, /usr/bin/sed, /bin/mkdir, /bin/ln
```

But for now, just run the script manually and we'll continue.

---

## After Completion

Once you've run the script successfully, signal completion by running from motoko:

```bash
ssh miket@count-zero.pangolin-vega.ts.net "mount | grep -c autofs || echo 'Autofs removed successfully'"
```

If it shows "Autofs removed successfully" or returns 0, proceed to Phase 3.

