# GNOME Shell Quick Recovery Guide

**For:** Emergency recovery of frozen GNOME UI on motoko  
**Last Updated:** November 21, 2025

---

## 🚨 Emergency: UI Completely Frozen

If the mouse moves but nothing else works:

```bash
# Run the recovery script
bash ~/miket-infra-devices/devices/motoko/scripts/gnome-shell-recovery.sh
```

**OR manually:**

```bash
# 1. Remove stuck file
rm -f /run/user/1000/gnome-shell-disable-extensions

# 2. Restart gnome-shell
killall -9 gnome-shell

# 3. Wait 5 seconds for auto-restart
```

---

## 📊 Check System Health

```bash
# Check gnome-shell status
ps aux | grep gnome-shell | grep -v grep

# Check CPU usage (should be < 20%)
top -b -n 1 | grep gnome-shell

# Check for stuck files
ls -la /run/user/1000/gnome-shell-disable-extensions

# Check system load (should be < 2.0)
uptime
```

---

## 🔧 Prevention

Run the health monitor in background:

```bash
# Start monitoring
bash ~/miket-infra-devices/devices/motoko/scripts/gnome-health-monitor.sh &

# Check monitor logs
tail -f /var/log/gnome-health-monitor.log
```

---

## 📋 Common Issues

### Issue: Mouse moves but UI frozen
**Cause:** GNOME Shell crash loop  
**Fix:** Run recovery script above

### Issue: High CPU (>80%)
**Cause:** Extension misbehaving or GPU contention  
**Fix:** Disable blur-my-shell extension:
```bash
gnome-extensions disable blur-my-shell@aunetx
```

### Issue: Repeated crashes
**Cause:** Extension compatibility or GPU memory exhaustion  
**Fix:** 
1. Check GPU memory: `nvidia-smi`
2. Disable extensions one by one
3. Consider switching to Wayland

---

## 🔍 Diagnostic Commands

```bash
# Check recent GNOME errors
journalctl -b --no-pager | grep -i "gnome-shell.*error" | tail -20

# Check extension status
gnome-extensions list --enabled

# Check GPU memory
nvidia-smi

# Check system resources
htop
```

---

## 📞 Escalation

If recovery script fails:

```bash
# Restart GDM (will log out)
sudo systemctl restart gdm
```

If GDM restart fails:

```bash
# Full reboot (last resort)
sudo reboot
```

---

## 📚 Full Documentation

See: `devices/motoko/GNOME_UI_FREEZE_INCIDENT_REPORT.md`

