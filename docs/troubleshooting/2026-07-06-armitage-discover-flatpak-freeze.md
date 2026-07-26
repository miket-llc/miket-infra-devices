# Armitage — KDE Discover Freezes on "Fetching Updates"

**Date:** 2026-07-06
**Device:** armitage (Fedora 44 KDE)
**Issue:** KDE Discover shows an update badge (e.g. "16"), spins on *Fetching updates…*, then freezes without ever rendering the pending update list.
**Status:** ✅ Resolved

## Executive Summary

Discover's freeze was **not** a backend or network fault — every package backend
(flatpak, dnf/PackageKit, snap, fwupd) applied updates fine from the CLI, and the
frozen `plasma-discover` process was sitting **idle in its Qt event loop**
(`QCoreApplication::exec → ppoll`), not deadlocked or mid-download.

The real cause was Discover's Flatpak updates model choking on **end-of-life (EOL)
runtime entries** in the pending set — specifically `org.freedesktop.Platform` **23.08**
and its `GL.default` / `VAAPI` extensions. That dead runtime was kept installed because
the **WezTerm flatpak was pinned to the EOL 23.08 runtime**. Discover's updates view is
known to hang/blank-list when an EOL runtime is present.

A secondary contributor was a stale **`fedora-testing`** OCI Flatpak remote (disabled at
the flatpak level but re-added by Discover to its source list on every launch), which
stalled the earlier *fetch* stage.

## Root Cause

1. **EOL runtime in the update set (primary).** `org.freedesktop.Platform//23.08` is EOL
   ("no longer receiving fixes and security updates"). WezTerm's flatpak
   (`org.wezfurlong.wezterm`, last stable `20240203`) still targets 23.08, so flatpak kept
   the dead runtime + `GL.default`/`VAAPI` 23.08 extensions installed and dragged their
   updates into every cycle. Those EOL entries jam Discover's list render.
2. **Phantom `fedora-testing` remote (secondary).** A `system,disabled,oci` remote
   (`oci+https://registry.fedoraproject.org#testing`). Editing `~/.config/discoverrc`
   didn't stick — Discover rewrites it on exit and re-adds the source.

## How to Diagnose

```bash
# 1. Prove the backends are actually healthy (all should return quickly):
timeout 30 flatpak remote-ls --updates          # flatpak
pkcon get-updates                                # dnf/PackageKit
snap refresh --list                              # snap
fwupdmgr get-updates                             # firmware

# 2. Confirm Discover itself is idle, not deadlocked (run while it's "frozen"):
PID=$(pgrep -x plasma-discover | head -1)
eu-stack -p "$PID" | head -20                    # main thread in QCoreApplication::exec = idle
ss -tnp | grep "$PID"                            # check for stuck sockets (empty queues = fine)

# 3. Find EOL runtimes and the app pinning them:
flatpak list --columns=application,branch | grep -E '23\.08'
flatpak list --app --columns=name,application,runtime | grep '23.08'

# 4. Find phantom/disabled remotes Discover keeps re-adding:
flatpak remotes --show-disabled --columns=name,options,url
```

## The Fix

```bash
# a. Delete the phantom disabled remote so Discover can't re-add it:
sudo flatpak remote-delete --force fedora-testing
printf '[FlatpakSources]\nSources=fedora,flathub\n' > ~/.config/discoverrc
rm -rf ~/.cache/discover                          # force a clean rebuild

# b. Apply all pending flatpak updates from the CLI (bypasses the buggy UI):
flatpak update -y

# c. Replace the WezTerm flatpak (the thing pinning EOL 23.08) with a native package —
#    see "WezTerm: flatpak → native" below. Uninstalling it drops the 23.08 stack.

# d. Refresh the notifier so the stale badge count clears:
systemctl --user restart app-org.kde.discover.notifier@autostart.service
```

## WezTerm: flatpak → native (armitage)

The WezTerm flatpak had not shipped a new stable since `20240203` and stayed on the EOL
23.08 runtime. Replaced with the **official upstream COPR** (`wezfurlong/wezterm-nightly`),
which is WezTerm's recommended native path on Fedora and stays current (F44 build was
one day old). Config at `~/.config/wezterm/wezterm.lua` is the same path natively — it
carried over with zero changes.

```bash
sudo dnf -y copr enable wezfurlong/wezterm-nightly
sudo dnf -y install wezterm
wezterm --version                                 # confirm native /usr/bin/wezterm

# Validate the existing config parses under native before removing the flatpak:
wezterm --config-file ~/.config/wezterm/wezterm.lua show-keys

# Remove the flatpak (this also uninstalls the EOL 23.08 runtime it was holding):
flatpak uninstall -y org.wezfurlong.wezterm
sudo update-desktop-database /usr/share/applications   # menu entry → native
```

WezTerm now updates via `dnf` alongside the rest of the system, instead of dragging a
dead flatpak runtime.

### Post-migration regression: titlebar + border + flicker (Wayland backend)

After the native switch and a reboot, WezTerm suddenly showed a **titlebar and border**
(despite `window_decorations = "RESIZE"`) and **flickered**. The flatpak build had been
running under XWayland; the native build defaulted to WezTerm's **native Wayland backend**
(`config.enable_wayland = true`), which exposes two known KWin (Plasma 6) bugs:

1. **Flicker.** WezTerm's Wayland surface presentation fights KWin's compositor
   (frame-callback/damage timing), aggravated by `window_background_opacity = 0.75`
   transparency and armitage's **hybrid Meteor Lake Arc + NVIDIA** present path.
2. **Titlebar.** KWin also draws a titlebar the config never asked for (see the
   decorations note below) — a separate KWin quirk, not fixed by the Wayland switch.

**Fix (flicker)** — force XWayland in `~/.config/wezterm/wezterm.lua` (chezmoi dotfiles repo):

```lua
config.enable_wayland = false   -- startup-time setting: fully quit + relaunch WezTerm
```

Trade-off: slightly softer text at fractional scale (eDP-1 is 1.25×), since XWayland
upscales a 1.0 buffer. Confirm it took effect:

```bash
xlsclients -l 2>/dev/null | grep -i wezterm   # listed = now an X client (XWayland) ✓
```

Escalation if flicker survives XWayland (hybrid-GPU wildcard): add
`config.front_end = "OpenGL"` (WezTerm may default to WebGpu and bind the NVIDIA adapter).
If instead the softer text is the bigger annoyance, stay native-Wayland and set
`window_background_opacity = 1.0` — that kills most flicker but does **not** fix the titlebar.

**Fix (titlebar)** — `window_decorations = "RESIZE"` does **not** produce a borderless
window on KWin. WezTerm's `RESIZE` sets `_MOTIF_WM_HINTS` decorations to `0x2`
(BORDER only, TITLE bit off), but **KWin only honors motif hints when *zero* decorations
are requested** and ignores the partial "border, no title" hint — so it draws a full
titlebar anyway (`_NET_FRAME_EXTENTS = 0, 0, 35, 0`, a 35px top frame). Use `"NONE"`,
which requests zero decorations and KWin respects:

```lua
if not is_macos then
	config.window_decorations = "NONE"   -- KWin ignores partial MWM hints; NONE = truly borderless
end
```

`NONE` leaves no titlebar to grab — move/resize with `Meta`+drag / `Meta`+right-drag
(KDE defaults). Verify the frame is gone:

```bash
WID=$(wmctrl -lx | grep -i wez | awk '{print $1}')
xprop -id "$WID" _NET_FRAME_EXTENTS         # expect 0, 0, 0, 0 (was 0, 0, 35, 0)
```

## Gotchas / Lessons

- **Only `23.08` was EOL, not `24.08`.** `org.kde.Platform//6.9` (used by ProtonUp-Qt,
  `net.davidotek.pupgui2`) is layered on freedesktop **24.08**, so its
  `GL.default`/`VAAPI` **24.08** extensions are legitimately in use. Do **not** force-remove
  24.08 — `flatpak uninstall --unused` correctly leaves them. If you over-prune them,
  restore with:
  ```bash
  sudo flatpak install -y flathub \
    org.freedesktop.Platform.GL.default//24.08 \
    org.freedesktop.Platform.GL.default//24.08extra \
    org.freedesktop.Platform.VAAPI.Intel//24.08
  ```
- **Editing `~/.config/discoverrc` alone doesn't stick** — Discover rewrites it on exit.
  Delete the underlying flatpak remote instead.
- **`pkill -f plasma-discover` self-matches** the shell running the command (the string is
  in its own argv) and kills your own command. Use `pkill -x plasma-discover`.
- **General rule:** if Discover hangs on "Fetching updates" but the CLI backends are
  healthy, suspect an **EOL runtime** in the pending set. Apply updates via
  `flatpak update` and get the offending app off the dead runtime.

## Recurrence 2026-07-14 — different root cause: the snap backend

Discover hung on *Fetching updates…* again (badge showed 21, then 31 after a cache
refresh, but the list never rendered and Update All stayed grey). This time **neither**
prior cause was present: no EOL runtime (only 24.08/25.08 remained) and no phantom remote
(`discoverrc` clean, only `fedora` + `flathub`).

**Root cause: the `snap` backend.** `plasma-discover-snap` started a fetch and never
signalled completion. Discover's *Fetching updates…* spinner is tied to the **global**
`isFetching` state aggregated across **all** backends, so one stuck backend pins the whole
Updates page even though PackageKit/Flatpak/fwupd already had their updates ready. No snaps
were even installed and `snapd.service` was inactive (socket-activated only) — the plugin
was pure dead weight.

**Isolation method (definitive).** Load backends selectively and screenshot each run:
```bash
plasma-discover --listbackends        # fwupd, flatpak, snap, packagekit, kns
# renders fine:
plasma-discover --backends packagekit-backend,flatpak-backend,fwupd-backend --mode update
# re-hangs the moment snap is added back:
plasma-discover --backends packagekit-backend,flatpak-backend,fwupd-backend,snap-backend --mode update
```
`kns` was NOT guilty (the "Application Addons" category loads fine).

**Fix (as applied 2026-07-14, but see the durable-fix update below):**
```bash
sudo dnf remove -y plasma-discover-snap   # 1 package, no cascade; snap-backend.so gone
```
Confirmed a normal `plasma-discover --mode update` (no flags) then renders with Update All
enabled: 2 flatpaks (Chrome, Freedesktop SDK) + fwupd (Microsoft UEFI dbx) + PackageKit
system upgrade (28 pkgs), total 3.6 GiB.

**Red herrings ruled out this round:**
- `rpmfusion-nonfree-steam` 404s on refresh — stale local metadata pointing at a rotated
  `primary.xml.gz` checksum. Cleared by `sudo dnf clean all && sudo dnf makecache`. Not the
  Discover cause (PackageKit still returned updates fine).
- IPv6 tether hijack — not active (no v6 default route; `ip_resolve=4` holding; v4 to
  mirrors HTTP 200 in 0.4s).
- Process was idle in its Qt event loop (`eu-stack` showed all threads in `ppoll`/waits),
  not deadlocked on any socket — consistent with "a backend never emitted done."

**Screenshot verification on this Wayland box** (no `xdotool`/`qdotool`/`qdbus` installed):
```bash
# activate a specific window via KWin scripting over dbus-send, then capture active window
printf 'workspace.windowList().forEach(function(w){if(w.resourceClass&&String(w.resourceClass).toLowerCase().indexOf("discover")>=0){w.minimized=false;workspace.activeWindow=w;}});' > /tmp/act.js
ID=$(dbus-send --session --print-reply --dest=org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript string:/tmp/act.js | awk '/int32/{print $2}')
dbus-send --session --dest=org.kde.KWin /Scripting/Script$ID org.kde.kwin.Script.run
spectacle -b -n -a -o /tmp/shot.png
```

**Caveat:** Discover is effectively single-instance. Removing `plasma-discover-snap` only
takes effect for a **freshly started** Discover — an already-open window keeps the plugin
loaded and stays wedged, and clicking the icon may just re-focus the stale window. Fully
quit all `plasma-discover` processes (`pkill -x plasma-discover`; note `-f` self-matches the
shell) before relaunching.

## Recurrence 2026-07-25 — the snap-backend removal did NOT stick (weak-dep auto-repull)

Discover wedged on *Fetching updates…* **again**, same idle-in-`ppoll` event-loop signature
(a live `plasma-discover --mode update` PID sitting flat at ~3% CPU, `eu-stack` showing only
`QCoreApplication::exec → ppoll` — fetched nothing, never emitted done). Root cause: **the
snap backend was back.** `plasma-discover-snap` had been reinstalled on **2026-07-19** by a
routine `dnf update -y` (history tx 94, logged as *"Weak Dependency updates"*), even though
tx 91 removed it on 2026-07-14.

**Why `dnf remove` doesn't hold.** `plasma-discover-snap` ships:
```
Supplements: (plasma-discover and snapd)
```
Both `plasma-discover` and `snapd` are installed, so with the default `install_weak_deps=True`,
**every full `dnf update` re-adds the snap backend automatically.** On this fleet that means
`make update-all` silently re-wedges Discover on armitage roughly weekly. Removing the package
is necessary but not sufficient — you must also break the weak-dep re-pull.

**Durable fix.** Add a permanent dnf exclude, *then* remove the package:
```bash
# 1. Permanent exclude so weak-dep resolution can never re-add it (survives dnf update):
sudo sed -i '/^\[main\]/a excludepkgs=plasma-discover-snap' /etc/dnf/dnf.conf

# 2. Remove it. NOTE: on dnf5 (F44) the exclude also blocks `dnf remove`
#    ("matches only excluded packages"), and `--disableexcludes` is not a remove option.
#    It's a leaf (nothing requires it), so remove via rpm directly:
sudo rpm -e plasma-discover-snap

# 3. Verify the exclude blocks a future re-pull:
sudo dnf install plasma-discover-snap   # -> "Argument ... matches only excluded packages"
```
Verified: `plasma-discover --listbackends` now shows only `fwupd, flatpak, packagekit, kns`.
A fresh `plasma-discover --mode update` ramps CPU to ~95% (actually fetching), decays smoothly
to idle, and settles in the event loop — versus the wedged instance that sat flat from launch.

**What was actually done on armitage (2026-07-25): both.** After the exclude + `rpm -e` above,
snapd was also pulled since snap capability isn't wanted on this box:
```bash
sudo systemctl stop snapd.socket snapd.service
sudo dnf remove -y snapd snapd-selinux snap-confine snapd-glib snapd-qt   # all orphans
sudo rm -rf /var/lib/snapd    # snapd's uninstall clears most state; this is the residual
```
Removing `snapd` eliminates the other half of `Supplements:(plasma-discover and snapd)`, so
the snap backend can never be re-pulled regardless of the exclude — the two fixes are now
redundant guarantees (the `excludepkgs=` line is left in place as belt-and-braces). Nothing
hard-required snapd (`rpm -q --whatrequires snapd` → none); the snapd-glib/snapd-qt libs were
orphaned once `plasma-discover-snap` was gone.

**Fleet takeaway:** any Discover backend you remove that carries a `Supplements:` on installed
packages will be resurrected by `dnf update`. Pair the removal with an `excludepkgs=` line.

## Related Documentation

- `CLAUDE.md` (chezmoi dotfiles repo) — WezTerm config lives at `~/.config/wezterm/`
- ADR-004 — KDE Plasma is the standard Linux desktop
