# How to Disable Desktop Reset Script on Motoko

## Finding the Script

The script that resets your desktop could be running from several places. Check these locations:

### 1. Check Autostart Applications

```bash
# Check user autostart directory
ls -la ~/.config/autostart/

# Check system autostart directory
ls -la /etc/xdg/autostart/ | grep -i restore
```

### 2. Check Systemd User Services

```bash
# List all user services
systemctl --user list-units --type=service --all | grep -i restore

# Check for services that run on login
systemctl --user list-unit-files | grep -i restore
```

### 3. Check Systemd System Services

```bash
# Check system services
systemctl list-units --type=service --all | grep -i restore

# Check enabled services
systemctl list-unit-files | grep -i restore
```

### 4. Check Shell Startup Scripts

```bash
# Check profile scripts
grep -r "restore\|ansible.*restore" ~/.profile ~/.bashrc ~/.bash_profile ~/.xprofile 2>/dev/null

# Check system profile
grep -r "restore\|ansible.*restore" /etc/profile /etc/profile.d/ 2>/dev/null
```

### 5. Check Cron Jobs

```bash
# Check user crontab
crontab -l | grep -i restore

# Check system crontabs
sudo grep -r "restore\|ansible.*restore" /etc/cron* 2>/dev/null
```

### 6. Check GNOME Startup Applications

```bash
# List GNOME autostart applications
gsettings get org.gnome.shell enabled-extensions
gnome-extensions list --enabled | grep -i restore
```

## Common Locations to Check

### If it's an autostart .desktop file:

```bash
# Disable it
mv ~/.config/autostart/restore-popos-desktop.desktop ~/.config/autostart/restore-popos-desktop.desktop.disabled

# Or delete it
rm ~/.config/autostart/restore-popos-desktop.desktop
```

### If it's a systemd user service:

```bash
# Find the service
systemctl --user list-unit-files | grep restore

# Disable it
systemctl --user disable restore-popos-desktop.service

# Stop it if running
systemctl --user stop restore-popos-desktop.service

# Check status
systemctl --user status restore-popos-desktop.service
```

### If it's a systemd system service:

```bash
# Find the service
systemctl list-unit-files | grep restore

# Disable it
sudo systemctl disable restore-popos-desktop.service

# Stop it
sudo systemctl stop restore-popos-desktop.service
```

### If it's in a shell script:

```bash
# Check common locations
cat ~/.profile | grep -i restore
cat ~/.bashrc | grep -i restore
cat ~/.xprofile | grep -i restore

# Comment out or remove the line
nano ~/.profile  # or whichever file contains it
```

## Quick Search Command

Run this to find all potential locations:

```bash
# Search for restore-popos references
sudo find /etc /home/mdt -type f \( -name "*.service" -o -name "*.desktop" -o -name "*.sh" -o -name "*.conf" \) -exec grep -l "restore-popos\|restore.*desktop" {} \; 2>/dev/null

# Search for ansible restore commands
sudo find /etc /home/mdt -type f \( -name "*.service" -o -name "*.desktop" -o -name "*.sh" \) -exec grep -l "ansible.*restore\|restore-popos-desktop.yml" {} \; 2>/dev/null
```

## Most Likely Location

Based on the codebase, if there's an automatic restore script, it's most likely:

1. **A systemd user service** in `~/.config/systemd/user/` that runs the Ansible playbook
2. **An autostart .desktop file** in `~/.config/autostart/` that runs a script
3. **A script in ~/.profile or ~/.xprofile** that runs on login

## Once You Find It

1. **Disable the service/autostart:**
   ```bash
   # For systemd user service
   systemctl --user disable <service-name>.service
   systemctl --user stop <service-name>.service
   
   # For autostart file
   mv ~/.config/autostart/<file>.desktop ~/.config/autostart/<file>.desktop.disabled
   ```

2. **Reload systemd (if service):**
   ```bash
   systemctl --user daemon-reload
   ```

3. **Reboot or log out/in to verify it's disabled**

## If You Can't Find It

The script might be running from:
- A systemd timer (check with `systemctl list-timers`)
- A GNOME extension
- A custom script in `/usr/local/bin/` or `/opt/`
- A systemd path unit that watches for login events

Run this comprehensive search:

```bash
# Search everything
sudo grep -r "restore-popos-desktop\|ansible.*restore" /etc/systemd/ /home/mdt/.config/systemd/ /home/mdt/.config/autostart/ 2>/dev/null
```


