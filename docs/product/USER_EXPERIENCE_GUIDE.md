# User Experience Guide: The Miket Filesystem

**Welcome to the Grid.**
This guide explains how to use the standardized storage architecture across all your devices.

## The Golden Rule
**Use `~/space` (or `S:`) for everything.**
It is backed up, archived, and available everywhere.

## 1. The Three Pillars

| Name | Path (Mac/Linux) | Path (Windows) | What goes here? |
|:--- |:--- |:--- |:--- |
| **SPACE** | `~/space` | `S:` | **Projects, Documents, Media.** Your primary workspace. Infinite storage. |
| **FLUX** | `~/flux` | `X:` | **Active Dev, Scratch.** Temporary, fast, hot-swappable. |
| **TIME** | `~/time` | `T:` | **Backups.** Time Machine history. Read-only mostly. |

## 2. Device-Specific Instructions

### macOS
- **Login:** Mounts appear automatically.
- **Finder:** Look for `flux`, `space`, `time` in your Home folder.
- **Terminal:** `cd ~/space` works exactly as you expect.
- **Note:** Do NOT modify `~/.mkt/`. That is the engine room.

### Windows
- **Login:** Drives `S:`, `X:`, `T:` map automatically.
- **Explorer:** Pinned to Quick Access.
- **PowerShell:** `cd S:` works.

### Linux
- **Login:** `~/space` symlink is ready.
- **Terminal:** `cd ~/space`.

## 3. Cloud Integration (iCloud / OneDrive)

**DO:**
- Use iCloud / OneDrive for phone sync, scanning docs, or "light" files.
- Let the **OS Cloud Sync** agent move them to `/space/devices` nightly.

**DO NOT:**
- 🛑 **Do not put `~/space` or `~/flux` inside iCloud or OneDrive.**
- 🛑 **Do not point iCloud/OneDrive to sync `S:` or `X:`.**
- This creates an infinite loop and will destroy the universe (or just fill the disk).

## 4. Where is my stuff from other devices?

Go to: `~/space/devices/` (or `S:\devices\`)

You will see:
- `count-zero/` (MacBook)
- `armitage/` (PC)
- `wintermute/` (Workstation)

Inside each, you'll find their mirrored iCloud/OneDrive content.
**This is Read-Only.** Treat it as a backup. To edit, copy it to `~/space/projects`.


