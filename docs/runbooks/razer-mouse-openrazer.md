# Razer Mouse Configuration (armitage)

armitage uses a **Razer Basilisk V3** (`1532:0099`). The generic kernel HID
driver gives full pointing, buttons and wheel with no setup, but no access to
Razer-specific settings — DPI, DPI stages, polling rate or Chroma lighting.
**OpenRazer** provides those.

This is a manual, non-Ansible install.

## Why not libratbag/Piper

libratbag — the userspace, no-kernel-module option normally preferred for gaming
mice — **supports no Razer hardware at all**. Razer's EULA forbids reverse
engineering the protocol, so libratbag will not implement it. `piper` and
`libratbag-ratbagd` are in the Fedora repos and will install cleanly, but they
will never see this mouse. OpenRazer is the only working path.

## Installation

```bash
sudo dnf config-manager addrepo \
  --from-repofile=https://download.opensuse.org/repositories/hardware:/razer/Fedora_44/hardware:razer.repo
sudo rpm --import https://download.opensuse.org/repositories/hardware:/razer/Fedora_44/repodata/repomd.xml.key
sudo dnf install -y openrazer-meta polychromatic
sudo gpasswd -a mdt plugdev
```

Import the key explicitly as above rather than letting `-y` accept whatever
appears during the transaction.

**Log out and back in.** `plugdev` only activates in a new session, and the
OpenRazer daemon runs as the desktop user — without the group it sees no
devices, even though the driver is loaded and working. Polychromatic showing an
empty device list (or a `?` device icon) is almost always this, and the daemon
says so plainly:

```
journalctl --user -u openrazer-daemon -n 20
# CRITICAL | User is not a member of the plugdev group
```

The daemon's own message says to reboot. A logout is sufficient **provided user
lingering is off** (`loginctl show-user mdt -p Linger` reports `Linger=no`, the
default here): the per-user systemd manager that spawns the daemon is torn down
at logout and rebuilt with the new group set. With lingering enabled that
manager survives logout and keeps the stale groups, and a reboot — or
`loginctl terminate-user mdt` — is genuinely required. Confirm which groups the
live session actually has rather than trusting `id`, which reads the group
database instead of the running process:

```bash
grep '^Groups:' /proc/$(pgrep -x plasmashell | head -1)/status
```

Then launch **Polychromatic** for DPI, DPI stages, polling rate and lighting.

## Kernel module maintenance

OpenRazer ships as a **DKMS** module (upstream provides no `akmod`, the
Fedora-native equivalent — tracked as openrazer issue #1747). DKMS rebuilds
automatically whenever a kernel is installed, so there is no manual build step.

Two things worth knowing:

- **Secure Boot is disabled on armitage**, which removes the main recurring
  chore. DKMS still auto-generates a self-signed MOK (`/var/lib/dkms/mok.key`)
  and signs the modules, but nothing enforces it. If Secure Boot is ever
  enabled, that key must be enrolled once with `mokutil` or the module will
  silently fail to load.
- Fedora moves kernels quickly. If a kernel change breaks the build, **the mouse
  keeps working normally** and only the configuration layer is lost until
  upstream ships a fix. DPI stages live in the mouse's onboard memory, so
  whatever is already set stays set — OpenRazer is only needed to *change*
  settings, not to use them.

Check module health after a kernel update:

```bash
dkms status openrazer-driver
lsmod | grep razer
```

## Verification

```bash
for d in /sys/bus/hid/drivers/razermouse/0003:1532:0099.*; do
  [ -e "$d/dpi" ] || continue
  echo "device:    $(sudo cat $d/device_type)"
  echo "firmware:  $(sudo cat $d/firmware_version)"
  echo "dpi:       $(sudo cat $d/dpi)"
  echo "poll_rate: $(sudo cat $d/poll_rate)"
done
```

Healthy output names the device, e.g. `Razer Basilisk V3`, firmware `v1.2`, with
`dpi` as an `X:Y` pair. Reading these requires root until the `plugdev` re-login
has happened; the daemon uses the group rather than sudo.

Only the first of the four `hidraw` interfaces the mouse exposes carries the
control attributes — the loop above skips the rest.
