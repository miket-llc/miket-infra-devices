# Motoko Headless Laptop Configuration

## Problem
Motoko is a laptop running Pop!_OS that needs to operate headless (lid closed) with:
- External HDMI monitor as the only display
- Autologin to desktop on boot
- TigerVNC access to the desktop session
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
Autostart script to disable laptop display and enable HDMI only:

```bash
# ~/.config/autostart/disable-laptop-display.desktop
[Desktop Entry]
Type=Application
Name=Disable Laptop Display
Exec=sh -c "sleep 5 && DISPLAY=:0 xrandr --output eDP-1 --off --output HDMI-1-0 --auto --primary && DISPLAY=:0 xset s off && DISPLAY=:0 xset -dpms && DISPLAY=:0 xset s noblank"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
```

### 7. Power Management
Disable screensaver and screen blanking via GNOME settings:

```bash
gsettings set org.gnome.desktop.screensaver idle-activation-enabled false
gsettings set org.gnome.desktop.screensaver lock-enabled false
gsettings set org.gnome.settings-daemon.plugins.power idle-dim false
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
```

### 8. TigerVNC Configuration
System service for TigerVNC x0vncserver (shares existing X session):

```bash
# /etc/systemd/system/tigervnc.service
[Unit]
Description=TigerVNC x0vncserver (Display Sharing - GNOME Session)
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=simple
User=mdt
Group=mdt
WorkingDirectory=/home/mdt
Environment="HOME=/home/mdt"
Environment="DISPLAY=:0"
Environment="XAUTHORITY=/run/user/1000/gdm/Xauthority"
ExecStartPre=/bin/sh -c 'DISPLAY=:0 XAUTHORITY=/run/user/1000/gdm/Xauthority xset q &>/dev/null || sleep 2'
ExecStart=/usr/bin/x0vncserver -display :0 -rfbport 5900 -PasswordFile /home/mdt/.vnc/tigervnc-passwd -SecurityTypes VncAuth -AlwaysShared -localhost no -fg
Restart=on-failure
RestartSec=10
TimeoutStartSec=30

[Install]
WantedBy=default.target
```

VNC password file:
```bash
mkdir -p ~/.vnc
echo -e "motoko123\nmotoko123\nn" | vncpasswd ~/.vnc/tigervnc-passwd
chmod 600 ~/.vnc/tigervnc-passwd
```

Enable:
```bash
sudo systemctl enable tigervnc.service
```

## Boot Sequence
1. System boots with lid closed
2. Kernel treats lid as open (`button.lid_init_state=open`)
3. Multi-user target reaches
4. `force-gdm-start.service` starts GDM
5. GDM autologins mdt user
6. X session starts on :0
7. Autostart script disables laptop display, enables HDMI-1-0
8. Autostart script disables power management
9. TigerVNC service starts and shares :0 display

## Connection Info
- **VNC Host**: `100.92.23.71:5900` (Tailscale IP) or `motoko.pangolin-vega.ts.net:5900`
- **VNC Password**: `motoko123`
- **Physical Display**: HDMI-1-0 (laptop display eDP-1 disabled)

## Troubleshooting

### GDM not starting
```bash
sudo systemctl status force-gdm-start.service
sudo systemctl start gdm3
```

### TigerVNC not working
```bash
sudo systemctl status tigervnc
sudo systemctl restart tigervnc
```

### Display configuration not applied
```bash
DISPLAY=:0 xrandr --output eDP-1 --off --output HDMI-1-0 --auto --primary
```

### Monitor blanking
```bash
DISPLAY=:0 xset s off
DISPLAY=:0 xset -dpms
DISPLAY=:0 xset s noblank
```

## Why This is Necessary
Laptops with closed lids trigger hardware/firmware level suspend/sleep behavior that prevents normal graphical.target startup. The kernel parameter, logind configuration, and force-start service work together to override this behavior and ensure the system boots fully with the external display active.
