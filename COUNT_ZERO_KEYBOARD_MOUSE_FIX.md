# Count-Zero External Keyboard & Mouse Not Responding - Troubleshooting

## Issue
External keyboard and mouse are no longer responding on count-zero (macOS).

## Quick Fixes (Try These First)

### 1. Unplug and Replug USB Devices
- Physically disconnect the keyboard and mouse
- Wait 5 seconds
- Reconnect them
- Try different USB ports if available

### 2. Reset USB Ports (Software)
Run this command on count-zero:
```bash
# Reset USB ports (requires admin)
sudo killall -9 AppleUSBTCKeyboard
sudo killall -9 AppleUSBTCKeyEventDriver
```

### 3. Restart USB Subsystem
```bash
# Restart IOKit (USB subsystem)
sudo killall -9 IOHIDSystem
# Note: This will log you out - you'll need to log back in
```

### 4. Check System Settings
1. Go to **System Settings > Privacy & Security > Accessibility**
2. Ensure your applications have proper permissions
3. Go to **System Settings > Bluetooth** (if wireless)
4. Check if devices are connected

### 5. Reset NVRAM/PRAM
```bash
# Shut down the Mac
# Then hold Option + Command + P + R while starting up
# Hold until you hear the startup sound twice
```

## Diagnostic Commands

### Check USB Device Status
```bash
# List all USB devices
system_profiler SPUSBDataType

# Check HID devices
ioreg -p IOUSB -l -w 0 | grep -i "keyboard\|mouse\|hid"

# Check system logs for USB errors
log show --predicate 'process == "kernel"' --last 10m --style syslog | grep -i "usb\|hid\|keyboard\|mouse"
```

### Check Power Management
```bash
# Check if USB ports are being powered down
pmset -g
```

## Common Causes

1. **USB Power Management**: macOS may have put USB ports to sleep
2. **Driver Issues**: HID drivers may need to be reloaded
3. **Permission Issues**: Accessibility permissions may have been revoked
4. **Hardware Failure**: USB ports or devices may have failed
5. **System Update**: Recent macOS update may have broken compatibility

## Advanced Troubleshooting

### Reset USB Controller
```bash
# This requires physical access or SSH
sudo kextunload -b com.apple.iokit.IOUSBHostFamily
sudo kextload -b com.apple.iokit.IOUSBHostFamily
```

### Check for Conflicting Software
```bash
# Check if any software is blocking input
ps aux | grep -i "keyboard\|mouse\|input\|hid"
```

### Safe Mode
1. Shut down the Mac
2. Hold Shift while starting up
3. This loads minimal drivers and can help identify software conflicts

## If Nothing Works

1. **Use Built-in Keyboard/Trackpad**: If available, use the MacBook's built-in keyboard and trackpad
2. **SSH Access**: Use SSH from another machine (like motoko) to access count-zero
3. **System Restart**: Full system restart often resolves USB issues
4. **Check Hardware**: Try the keyboard/mouse on another computer to verify they work

## Prevention

- Keep macOS updated
- Avoid unplugging USB devices while the system is sleeping
- Use USB hubs with external power for multiple devices
- Check System Settings after macOS updates for permission changes

## Current System Status

From diagnostics:
- USB HID devices are being detected by the kernel
- System is seeing device open/close events
- Warning: "Matching has vendor DeviceUsagePage : ff00 bundleIdentifier none ioclass none but transport and vendorID is missing"
- This suggests devices are detected but not properly matched to drivers

## Next Steps

1. Try the quick fixes above (unplug/replug, restart USB subsystem)
2. If still not working, check System Settings for permissions
3. If wireless devices, check Bluetooth connection
4. Consider system restart if all else fails





