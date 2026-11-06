# DualSense Edge Relay (armitage)

armitage drives a **DualSense Edge** (`054c:0df2`). The in-tree `hid-playstation`
driver handles the pad natively — sticks, buttons, triggers, gyro, touchpad,
rumble and battery all work with no setup. What it does **not** expose are the
Edge-only controls: the two back paddles (`LB`/`RB`) and the two Fn buttons
under the sticks (`LFN`/`RFN`). They reach no evdev node, so no game can bind
them.

`ds5-edge-relay` solves this. It reads the physical Edge over `hidraw`, rewrites
the HID report to turn paddle presses into ordinary face buttons, and publishes
the result as a **virtual standard DualSense** (`054c:0ce6`) through `/dev/uhid`.
Games see a normal DualSense whose face buttons happen to fire when you squeeze a
paddle.

This is a manual, non-Ansible install — it is not RPM-owned and not part of any
playbook. See [[project-ds5-edge-relay-vs-dstx]] for why this tool was chosen
over DSTX.

## Installation

Built from source (Qt6, C++23) and installed outside the package manager:

```bash
git clone https://github.com/Follen22/ds5-edge-relay
cd ds5-edge-relay
cmake -B build -GNinja -DCMAKE_BUILD_TYPE=Release
ninja -C build
sudo install -Dm755 build/ds5-edge-relay /usr/local/bin/ds5-edge-relay
sudo install -Dm644 ds5-edge-relay.desktop /usr/share/applications/ds5-edge-relay.desktop
```

Upstream defines no `install` target, so `ninja install` fails — place the files
by hand as above. Build dependency is `qt6-qtbase-devel`.

Rebuild and smoke-test after every Fedora major upgrade (Qt6/GCC ABI) or
`hid-playstation` change. Breakage comes from this side; upstream is dormant.

## udev: the rule that makes it work

```bash
sudo tee /etc/udev/rules.d/99-ds5-edge-relay.rules <<'RULE'
SUBSYSTEM=="hidraw", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0df2", OWNER="mdt", GROUP="input", MODE="0660", TAG+="uaccess"
SUBSYSTEM=="input",  ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0df2", OWNER="mdt", GROUP="input", MODE="0660", TAG+="uaccess"
SUBSYSTEM=="misc", KERNEL=="uhid", GROUP="input", MODE="0660", TAG+="uaccess"
RULE
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=hidraw --subsystem-match=input
```

**`OWNER="mdt"` is load-bearing and is the single most important line in this
runbook.** The relay hides the physical pad from Steam by calling `chmod(0000)`
on its `hidraw` node (`relayworker.cpp:231`, `evdev_grabber.cpp:161`), because
Steam and SDL both read controllers through `hidraw`. `chmod` requires
*ownership* of the file. With the upstream rule's stock `root:input`
permissions the call fails with `EPERM`, the relay prints a single line to
stderr that nobody sees, and Steam happily grabs the physical Edge — where the
paddles are meaningless Edge-private bits. Every symptom of "the relay is
running but my mappings do nothing" traces back to this.

`/dev/uhid` is a statically-created kmod node, so udev cannot apply permissions
to it until the module is actually loaded. Force it once and make it permanent:

```bash
sudo modprobe uhid
echo uhid | sudo tee /etc/modules-load.d/uhid.conf
```

The desktop user must also be in the `input` group (`sudo usermod -aG input mdt`),
which takes effect on next login.

## Operating sequence

Order is not optional. Doing these out of order is the cause of nearly every
failure, and the UI gives no indication anything is wrong.

1. **Tick "Use bindings" first.** Before pressing Start.
2. **Click Start.**
3. **Then start or restart Steam.**

### Why order matters

**Bindings reach the relay at exactly one moment.** `MainWindow::on_start_clicked()`
calls `worker_->set_bindings(bind_editor_->activeBindings())` (`mainwindow.cpp:457`).
`activeBindings()` returns an empty vector when the checkbox is unticked
(`bindeditorwidget.cpp:303`). Ticking the box *after* Start does not help:
`on_use_bindings_toggled()` only animates the panel and **never emits
`bindingsChanged`**, so nothing propagates to the running worker. The checkbox
appears ticked, the list shows every binding, and the relay applies none of them.

**The checkbox is never persisted.** Only `background` and `lang_ru` are saved
(`mainwindow.cpp:563`). The checkbox is constructed unticked, so **every launch
starts with bindings disabled** — including the autostart entry that launches
the relay at login.

**Steam must start after the lock.** The `chmod(0000)` only blocks *new* opens.
Any Steam already running keeps its existing file descriptor on the physical
pad, and Steam Input then presents the game two controllers — one backed by the
physical Edge, where paddles do nothing. Two `Microsoft X-Box 360 pad` entries in
`/proc/bus/input/devices` is the signature of this state.

### Applying bindings without restarting

Stopping the relay destroys the virtual pad, which a running game may not
recover from. To push bindings into a live relay instead, toggle **any single
binding's own checkbox** off and back on. That path calls `save_binds()` →
`emit bindingsChanged()` → `update_bindings()` on the running worker
(`bindeditorwidget.cpp:231`, `mainwindow.cpp:352`) and takes effect on the next
HID report. Re-tick it — an unticked bind is saved to disk as disabled.

## Steam Input

Both modes work once the physical pad is properly hidden. Pick per game:

- **On** — Steam presents an emulated Xbox 360 pad, so games draw **A/B/X/Y**
  prompts. Costs adaptive triggers and native gyro, since an X360 target cannot
  carry them. Gyro can be re-mapped under Steam Input's own gyro settings.
- **Off** — Proton reads the virtual DualSense directly: native DualSense
  prompts, adaptive triggers, haptics and gyro all intact.

Either way the paddle remapping survives, because the relay rewrites the HID
report *before* anything downstream sees it. Steam Input never learns a paddle
was involved — it sees a plain Cross press.

If a game still picks up the wrong device, set a whitelist in that game's launch
options rather than a blacklist:

```
SDL_GAMECONTROLLER_IGNORE_DEVICES_EXCEPT=0x054C/0x0CE6 %command%
```

Use this **only with Steam Input off** — Steam's emulated pad is `0x28DE/0x11FF`
and the whitelist would block it, leaving the game with no controller at all.

## Bindings storage

Despite the README, bindings live at the Qt `AppConfigLocation` path:

```
~/.config/ds5-edge-relay/ds5-edge-relay/binds.json
```

Valid names: `Cross`, `Circle`, `Square`, `Triangle`, `L1`, `R1`, `L2`, `R2`,
`L3`, `R3`, `Options`, `Create`, `PS`, `Touchpad`, `DPadUp`, `DPadDown`,
`DPadLeft`, `DPadRight`, `LFN`, `RFN`, `LB`, `RB`. An unrecognised name is
silently skipped. Back this file up before editing it by hand.

## Verification

Confirm the lock engaged and nothing but the relay holds the physical pad:

```bash
for h in /dev/hidraw*; do d=/sys/class/hidraw/$(basename $h)/device
  id=$(grep -h HID_ID $d/uevent 2>/dev/null | cut -d= -f2)
  case "$id" in *054C*) echo "$(basename $h): $id $(ls -l $h | awk '{print $1}')";; esac
done
sudo lsof /dev/hidraw* 2>/dev/null | grep -E 'hidraw|COMMAND'
```

A healthy state shows the physical node as `c---------` held only by
`ds5-edge-relay`, with `steam`, `steamwebhelper` and `winedevice` all on the
virtual node. Run the relay from a terminal to watch it directly; the line
`[EvdevGrabber] hidraw locked: /dev/hidrawN (orig mode 0660)` confirms the lock,
and `chmod(0000) failed` confirms the `OWNER` rule is missing.

To prove remapping end to end, read both nodes at once and press a paddle. On
the physical, byte 10's upper nibble carries the Edge buttons
(`LFN 0x10`, `RFN 0x20`, `LB 0x40`, `RB 0x80`); on the virtual, byte 8's upper
nibble carries the face buttons (`Square 0x10`, `Cross 0x20`, `Circle 0x40`,
`Triangle 0x80`). A paddle press with no matching face button means the
bindings never reached the worker — see the ordering rules above. The relay
clears the Edge bits before forwarding (`relayworker.cpp:407`), so paddles can
*only* ever appear as their bound face button, never as themselves.

## Symptoms

| Symptom | Cause |
|---|---|
| Controller works, paddles and mappings do nothing | "Use bindings" ticked after Start, or never ticked |
| Mappings ignored, Steam sees the pad fine | `OWNER="mdt"` missing; lock failed; Steam is on the physical |
| Two `X-Box 360 pad` devices | Steam started before the relay locked; restart Steam |
| Game sees no controller at all | `..._EXCEPT` whitelist left on while Steam Input is enabled |
| Several tray icons | Multiple relay instances competing; keep exactly one |
| Paddles die after a replug | Relay re-locks on reconnect, but Steam may grab the pad in the gap; restart Steam |
