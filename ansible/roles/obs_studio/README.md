# OBS Studio Role

Cross-platform Ansible role for installing OBS Studio on PHC devices.

## Supported Platforms

- **Linux** (Debian/Ubuntu): Installs via PPA for latest version
- **Windows**: Installs via winget (fallback: Chocolatey)
- **macOS**: Installs via Homebrew cask

## Requirements

### Linux
- apt package manager
- Debian/Ubuntu-based distribution

### Windows
- Windows 10/11
- winget or Chocolatey installed

### macOS
- macOS 10.15+
- Homebrew installed

## Role Variables

```yaml
# Enable/disable OBS installation
obs_studio_enabled: true  # default: true

# Linux: Use PPA for latest version
obs_use_ppa: true  # default: true

# Windows: Installation method
obs_windows_install_method: winget  # default: winget

# macOS: Homebrew cask name
obs_macos_cask: obs  # default: obs
```

## Example Playbook

```yaml
- name: Deploy OBS Studio to all devices
  hosts: all
  roles:
    - obs_studio
```

## Features Installed

### Linux
- OBS Studio (latest from PPA)
- ffmpeg (video processing)
- v4l2loopback (virtual camera support)

### Windows
- OBS Studio 64-bit
- Virtual camera available via Tools menu

### macOS
- OBS Studio application
- Virtual camera available via Tools menu

## Post-Installation

### macOS
Grant screen recording permission:
1. System Preferences > Security & Privacy > Privacy
2. Select "Screen Recording"
3. Add OBS to the list

### All Platforms
Configure OBS for first use:
1. Launch OBS Studio
2. Run the Auto-Configuration Wizard
3. Add sources (display capture, window capture, etc.)

## License

Copyright (c) 2025 MikeT LLC. All rights reserved.

