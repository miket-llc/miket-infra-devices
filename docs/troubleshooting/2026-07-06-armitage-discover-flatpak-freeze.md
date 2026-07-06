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

## Related Documentation

- `CLAUDE.md` (chezmoi dotfiles repo) — WezTerm config lives at `~/.config/wezterm/`
- ADR-004 — KDE Plasma is the standard Linux desktop
