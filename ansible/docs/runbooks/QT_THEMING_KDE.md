# Qt Theming on KDE Plasma

> **Last Updated:** 2025-12-07  
> **Managed By:** `workstation_gui_tools` role, `linux_desktop_kde` role  
> **Affected Hosts:** All `desktop_environment: kde` hosts (akira, armitage)

## Overview

This document describes how Qt application theming works on KDE Plasma workstations
and how to troubleshoot Qt Quick applications that don't follow the system color scheme.

The most common symptom is **white-on-white text** in Qt Quick application settings
windows (like cool-retro-term) when using dark Plasma themes like Breeze Dark.

## How Qt Theming Works on KDE

KDE Plasma uses a layered approach to theming:

| Layer | Controls | Key Package |
|-------|----------|-------------|
| Qt Widgets | Buttons, menus, dialogs in traditional Qt apps | `breeze` (style), `plasma-integration` (platform theme) |
| Qt Quick Controls 2 | Modern QML-based UIs | `qqc2-desktop-style` (provides `org.kde.desktop` style) |
| Color Scheme | Actual colors used | Managed via `kdeglobals` and System Settings |

### How It Works Automatically

1. KDE sets `QT_QPA_PLATFORMTHEME=kde` automatically via session startup
2. The `plasma-integration` package provides the `kde` platform theme plugin
3. Qt Widgets apps pick up Breeze style and Plasma colors automatically
4. Qt Quick apps need `qqc2-desktop-style` to provide the `org.kde.desktop` style

### Common Failure Modes

| Problem | Symptom | Cause |
|---------|---------|-------|
| Missing `qqc2-desktop-style` | Qt Quick apps have white/default backgrounds | No KDE-aware QQC2 style available |
| `qt5ct`/`qt6ct` installed | Apps ignore Plasma theme | These override `kde` platform theme |
| `QT_QPA_PLATFORMTHEME` set globally | Apps don't use Plasma integration | Overrides automatic KDE detection |
| Wrong `QT_QUICK_CONTROLS_STYLE` | Qt Quick apps use wrong style | Forces non-native style |

## Required Packages

These **MUST** be installed on all KDE hosts:

```bash
# Install required packages
sudo dnf install qqc2-desktop-style plasma-integration breeze
```

These **MUST NOT** be installed (they conflict with KDE theming):

```bash
# Remove conflicting packages
sudo dnf remove qt5ct qt6ct
```

## Configuration Files

| Path | Purpose | Managed By |
|------|---------|------------|
| `/usr/local/bin/cool-retro-term-wrapper` | Wrapper script setting `QT_QUICK_CONTROLS_STYLE` | Ansible (`workstation_gui_tools`) |
| `/usr/local/share/applications/cool-retro-term.desktop` | Desktop entry using wrapper | Ansible (`workstation_gui_tools`) |
| `~/.config/kdeglobals` | KDE global settings including color scheme | User/System Settings |

### Environment Variables

**Do NOT set these globally** (let KDE handle them automatically):

- `QT_QPA_PLATFORMTHEME` — Set by Plasma session
- `QT_STYLE_OVERRIDE` — Affects Qt Widgets only, let users control via System Settings
- `QT_QUICK_CONTROLS_STYLE` — Should default to `org.kde.desktop` when `qqc2-desktop-style` installed

**Per-app overrides** (only for genuinely broken apps):

- `QT_QUICK_CONTROLS_STYLE=org.kde.desktop` — Forces KDE-native Qt Quick style

## Troubleshooting

### Problem: Qt Quick app has white background with dark theme

**Diagnosis:**

```bash
# Check if qqc2-desktop-style is installed
rpm -q qqc2-desktop-style

# Check for conflicting packages
rpm -qa | grep -E 'qt5ct|qt6ct'

# Check environment variables in current session
printenv | grep -E '^QT_'

# Check for system-wide overrides
grep -rE 'QT_QPA_PLATFORMTHEME|QT_STYLE_OVERRIDE|QT_QUICK_CONTROLS_STYLE' \
  /etc/profile.d/ 2>/dev/null

# Check user environment overrides
grep -E 'QT_' ~/.bashrc ~/.profile ~/.config/plasma-workspace/env/*.sh 2>/dev/null
```

**Solution:**

```bash
# Ensure correct packages
sudo dnf install qqc2-desktop-style plasma-integration
sudo dnf remove qt5ct qt6ct

# Re-run Ansible to deploy correct configuration
cd ~/dev/miket-infra-devices/ansible
ansible-playbook -i inventory/hosts.yml playbooks/workstations/akira-fedora-kde.yml \
  --tags qt-theming,cool-retro-term
```

### Problem: All Qt apps ignore theme after manual tweaking

**Cause:** Someone set `QT_QPA_PLATFORMTHEME` or other Qt variables globally.

**Diagnosis:**

```bash
# Check for environment variable overrides
grep -rE 'QT_QPA_PLATFORMTHEME|QT_STYLE_OVERRIDE|QT_QUICK_CONTROLS_STYLE' \
  /etc/profile.d/ \
  ~/.bashrc \
  ~/.profile \
  ~/.zshrc \
  ~/.config/plasma-workspace/env/
```

**Solution:**

Remove any lines setting these variables globally. Only `cool-retro-term-wrapper`
should set `QT_QUICK_CONTROLS_STYLE`, and only for that one app.

### Problem: Theme works but cool-retro-term settings still broken

**Cause:** Wrapper script not being used.

**Diagnosis:**

```bash
# Check if wrapper exists
ls -la /usr/local/bin/cool-retro-term-wrapper

# Check what desktop entry points to
grep -r 'Exec.*cool-retro-term' \
  /usr/share/applications/ \
  /usr/local/share/applications/ \
  ~/.local/share/applications/ 2>/dev/null

# Test wrapper directly
/usr/local/bin/cool-retro-term-wrapper
```

**Solution:**

```bash
# Re-run Ansible to redeploy wrapper and desktop entry
ansible-playbook -i inventory/hosts.yml playbooks/workstations/akira-fedora-kde.yml \
  --tags cool-retro-term
```

## Reapplying Configuration

To fix a broken host or apply to a new host:

```bash
# From ansible control node
cd ~/dev/miket-infra-devices/ansible

# akira (Fedora 43 KDE)
ansible-playbook -i inventory/hosts.yml \
  playbooks/workstations/akira-fedora-kde.yml \
  --tags qt-theming,kde,cool-retro-term

# armitage (Fedora 41 KDE)
ansible-playbook -i inventory/hosts.yml \
  playbooks/workstations/armitage-fedora-kde-ollama.yml \
  --tags qt-theming,kde,cool-retro-term
```

### Validation

Run validation to check configuration:

```bash
ansible-playbook -i inventory/hosts.yml \
  playbooks/workstations/akira-fedora-kde.yml \
  --tags validate
```

## Per-App Wrapper Strategy

For apps with genuine theming bugs that aren't fixed by installing `qqc2-desktop-style`:

### 1. Create Wrapper Script

```bash
# /usr/local/bin/<app>-wrapper
#!/bin/bash
export QT_QUICK_CONTROLS_STYLE=org.kde.desktop
exec /usr/bin/<app> "$@"
```

### 2. Create Desktop Override

Deploy to `/usr/local/share/applications/<app>.desktop` (takes precedence over
`/usr/share/applications/`).

### 3. Add to Ansible

Add wrapper script and desktop entry to the `workstation_gui_tools` role with
appropriate tags.

### Currently Wrapped Apps

| App | Wrapper | Reason | Limitations |
|-----|---------|--------|-------------|
| cool-retro-term | `/usr/local/bin/cool-retro-term-wrapper` | Settings window doesn't inherit Plasma colors | Some labels still invisible due to hardcoded QML colors in app source |

**Note on cool-retro-term:** The Material Dark theme makes most of the settings UI readable,
but some labels remain invisible because the app hardcodes text colors in its QML source
(uses raw `Text` elements instead of themed `Label` components). This is an upstream bug
that can only be fixed by patching the application itself.

## Verification

After applying changes, verify theming works:

```bash
# Launch cool-retro-term and open settings
cool-retro-term
# Press F10 or use menu to open settings
# Settings window should have dark background matching your theme

# Check other Qt Quick apps
systemsettings    # KDE System Settings
discover          # KDE Discover software center
```

## Architecture References

- **ADR-004:** KDE Plasma is the standard desktop for Linux UI nodes
- **Role:** `linux_desktop_kde` — Installs KDE and required Qt theming packages
- **Role:** `workstation_gui_tools` — Deploys per-app theming fixes

## External References

- [KDE Qt Quick Controls 2 Style (qqc2-desktop-style)](https://invent.kde.org/frameworks/qqc2-desktop-style)
- [plasma-integration](https://invent.kde.org/plasma/plasma-integration)
- [Qt Quick Controls 2 Styles Documentation](https://doc.qt.io/qt-6/qtquickcontrols2-styles.html)

