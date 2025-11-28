# Motoko Headless Laptop Configuration

## Problem
Motoko is a laptop running Ubuntu 24.04.2 LTS that needs to operate headless (lid closed) with:
- External HDMI monitor as primary display (fallback to eDP if HDMI unplugged)
- Autologin to desktop on boot
- NoMachine remote desktop access
- Wake-on-LAN support
- No suspend/sleep when lid is closed

## Solution Components

### 1. Lid Switch Configuration
Disable lid switch actions in logind:

```bash
# /etc/systemd/logind.conf
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
```

Restart logind:
```bash
sudo systemctl restart systemd-logind
```

### 2. Kernel Parameters
Add kernel parameter to treat lid as always open:

```bash
sudo kernelstub -a 'button.lid_init_state=open'
```

### 3. GDM Autologin
Configure autologin in GDM config:

```bash
# /etc/pop-os/gdm3/custom.conf
[daemon]
WaylandEnable=false
AutomaticLoginEnable=true
AutomaticLogin=mdt
```

### 4. Force GDM Start on Boot
Create systemd service to force GDM to start (lid-closed prevents normal startup):

```bash
# /etc/systemd/system/force-gdm-start.service
[Unit]
Description=Force GDM to start
After=multi-user.target
Wants=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/systemctl start gdm3
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

Enable:
```bash
sudo systemctl enable force-gdm-start.service
```

### 5. GDM Service Override
Override GDM to restart on failure:

```bash
# /etc/systemd/system/gdm.service.d/override.conf
[Unit]
ConditionPathExists=
ConditionPathExists=/usr/sbin/gdm3

[Service]
Restart=always
RestartSec=5
```

### 6. Display Configuration
Display configuration is handled automatically via the `display_configuration` Ansible role, which:
- Configures Xorg to prefer HDMI as primary display
- Sets up a systemd service that runs early (before user session) to configure displays
- Provides udev rules for HDMI hotplug detection
- Falls back to eDP if HDMI is not connected

The configuration works before X-windows starts, ensuring proper display setup on boot.

### 7. Power Management
Power management is handled by the display configuration script, which disables screen blanking and DPMS.

### 8. NoMachine Configuration
NoMachine is the sole remote desktop solution (VNC has been architecturally retired). NoMachine automatically attaches to the existing X session (`:0`) and will see the configured display (HDMI or eDP).

**Connection:**
- **Host**: `motoko.pangolin-vega.ts.net:4000`
- **Protocol**: NoMachine NX
- **Session**: Shares existing KDE Plasma desktop session

See [NoMachine Client Installation](nomachine-client-installation.md) for client setup.

## Boot Sequence
1. System boots with lid closed (or wakes via WOL)
2. Kernel treats lid as open (`button.lid_init_state=open`)
3. Multi-user target reaches
4. `force-gdm-start.service` starts GDM
5. Xorg reads `/etc/X11/xorg.conf.d/10-hdmi-primary.conf` (HDMI preferred)
6. `display-setup.service` runs after GDM, before user session
7. Display switch script detects HDMI/eDP and configures primary display
8. GDM autologins mdt user
9. X session starts on :0 with configured display
10. NoMachine server shares the existing session

## Connection Info
- **NoMachine Host**: `motoko.pangolin-vega.ts.net:4000`
- **Protocol**: NoMachine NX
- **Physical Display**: HDMI-1 (primary when connected) or eDP-1 (fallback)

## Troubleshooting

### GDM not starting
```bash
sudo systemctl status force-gdm-start.service
sudo systemctl start gdm3
```

### NoMachine not working
```bash
sudo systemctl status nxserver
sudo systemctl restart nxserver
```

### Display configuration not applied
```bash
# Manual display configuration (if needed)
sudo /usr/local/bin/display-switch.sh

# Or manually configure
DISPLAY=:0 xrandr --output HDMI-1 --primary --auto --output eDP-1 --off
# Or if HDMI not connected:
DISPLAY=:0 xrandr --output eDP-1 --primary --auto
```

### Monitor blanking
```bash
DISPLAY=:0 xset s off
DISPLAY=:0 xset -dpms
DISPLAY=:0 xset s noblank
```

## Why This is Necessary
Laptops with closed lids trigger hardware/firmware level suspend/sleep behavior that prevents normal graphical.target startup. The kernel parameter, logind configuration, and force-start service work together to override this behavior and ensure the system boots fully with the external display active.
