---
document_title: "Nextcloud Client Usage Guide"
author: "Codex-UX-010"
last_updated: 2025-11-28
status: Published
related_initiatives:
  - initiatives/nextcloud-deployment
linked_communications:
  - docs/communications/COMMUNICATION_LOG.md
---

# Nextcloud Client Usage Guide

**Status:** Published  
**Purpose:** End-user guide for Nextcloud desktop client  
**Audience:** All PHC device users

---

## Overview

Nextcloud provides file sync between your devices and `/space` on motoko. This guide covers:

- Client installation
- Initial setup
- Recommended sync folders
- What NOT to sync

### Pure Façade Architecture

Nextcloud on motoko is configured as a **pure façade** over `/space`:

- **All your files live on `/space`** - the System of Record
- **Nextcloud provides access** - via external storage mounts
- **No internal storage used** - skeleton/welcome files are disabled
- **Stray file detection** - daily sweeper checks for misplaced files

This means the folders you see in Nextcloud (work, media, finance, etc.) are actually your `/space/mike` directories, not copies.

## Quick Start

### 1. Install Client

| Platform | Method |
|----------|--------|
| macOS | `brew install --cask nextcloud` |
| Windows | `choco install nextcloud-client` or [download](https://nextcloud.com/install/#install-clients) |
| Linux | `sudo apt install nextcloud-desktop` |

### 2. Connect to Server

1. Launch Nextcloud
2. Click **"Log in to your Nextcloud"**
3. Enter: `https://nextcloud.miket.io`
4. Authenticate via Cloudflare Access (use your Entra ID credentials)

### 3. Choose Sync Folder

Use the default: `~/Cloud`

**⚠️ DO NOT use:**
- Your home folder (`~`)
- iCloud Drive
- OneDrive folder
- Dropbox folder
- Any `/space` SMB mount

### 4. Select Folders to Sync

✅ **Recommended:**
- `work` - Work documents
- `media` - Photos, music
- `finance` - Financial documents
- `inbox` - General inbox
- `assets` - Design assets
- `camera` - Camera uploads

⚡ **Online-only (optional):**
- `ms365` - Large M365 ingestion folder

---

## Sync Root Safety

Your sync folder (`~/Cloud`) is a local cache of files from Nextcloud. It must be:

| ✅ Safe | ❌ Dangerous |
|---------|-------------|
| Local SSD | Home folder (`~`) |
| Fast storage | iCloud Drive |
| Not synced elsewhere | OneDrive |
| | Dropbox |
| | SMB mount to `/space` |

**Why?** Syncing to another sync service creates loops and conflicts.

---

## What NOT to Sync

### Never Put in Nextcloud

These file types cause sync issues, consume massive bandwidth, or corrupt projects:

#### 🎵 Audio Production (DAW Sessions)

| Type | Extensions | Why |
|------|------------|-----|
| Pro Tools | `.ptx`, `.ptf`, `.pts` | Session references break |
| Logic Pro | `.logicx` | Bundle contains thousands of files |
| Audition | `.sesx` | Binary session files |
| Ableton | `.als` | Project references break |

**Where to work:** Directly on `/space/mike/art` via SMB mount.

#### 🎬 Video Editing

| Type | Extensions | Why |
|------|------------|-----|
| Premiere | `.prproj` | Media cache issues |
| DaVinci Resolve | `.drp` | Database corruption |
| Final Cut Pro | `.fcpbundle` | Bundle sync issues |
| After Effects | `.aep`, `.aepx` | Very large files |

**Where to work:** Directly on `/space/mike/art` or `/space/projects` via SMB.

#### 📷 Photo Catalogs

| Type | Extensions | Why |
|------|------------|-----|
| Lightroom | `.lrcat`, `.lrdata` | Catalog corruption |
| Capture One | Session folders | Index corruption |

**Where to work:** Keep catalogs on local SSD with files on `/space/mike/camera`.

#### 💻 Development

| Type | Why |
|------|-----|
| `.git` directories | Breaks version control |
| `node_modules` | Millions of small files |
| `venv`, `.venv` | Python environments |
| `build`, `dist` | Regenerated artifacts |

**Where to work:** Use `/space/mike/code` or `/space/mike/dev` via SMB.

---

## Recommended Workflow

### For Documents

```
Local (~/Cloud/work) ←→ Nextcloud ←→ /space/mike/work
```

Work normally in `~/Cloud/work`. Changes sync automatically.

### For Media Projects

```
Local SSD (project cache) + /space/mike/art (storage via SMB)
```

1. Mount `/space` via SMB
2. Keep active project on local SSD
3. Archive to `/space/mike/art` when done

### For Code/Dev

```
/space/mike/code via SMB (or clone fresh)
```

Don't sync repos. Clone directly or access via SMB.

---

## Conflict Resolution

When the same file is edited on two devices:

1. Nextcloud creates a **conflict copy**: `file (conflict).ext`
2. Review both versions
3. Keep the correct one
4. Delete the conflict copy

**Prevention:**
- Avoid editing the same file on multiple devices simultaneously
- Use Nextcloud's online editing for collaborative docs

---

## Offline Access

By default, files are **online-only** on mobile and selective on desktop.

### Make Available Offline

- Right-click folder → **"Make available offline"**
- Or: Sync settings → Select folders to sync locally

### Check Sync Status

- Green checkmark: Synced
- Blue arrows: Syncing
- Gray cloud: Online-only
- Red X: Sync error

---

## Troubleshooting

### Files Not Syncing

1. Check Nextcloud icon in menu bar/system tray
2. Click to see sync status
3. If paused, click "Resume sync"

### Conflict Loops

If you see many conflict copies:

1. Pause sync
2. Identify the source of conflicts
3. Resolve manually
4. Resume sync

### Large Uploads Failing

For files >1GB:

1. Check network stability
2. Try wired connection
3. Upload via web interface as fallback

### Client Won't Connect

1. Verify `https://nextcloud.miket.io` is accessible
2. Check Cloudflare Access authentication
3. Try logging out and back in
4. Restart Nextcloud client

---

## Platform-Specific Notes

### macOS

- App location: `/Applications/Nextcloud.app`
- Config: `~/Library/Preferences/Nextcloud/`
- Auto-start: System Preferences → Users & Groups → Login Items

### Windows

- App location: `C:\Program Files\Nextcloud\`
- Config: `%APPDATA%\Nextcloud\`
- Auto-start: Settings → General → Launch on system startup

### Linux

- Binary: `nextcloud` or `nextcloud-cmd`
- Config: `~/.config/Nextcloud/`
- Auto-start: Desktop environment dependent

---

## Support

- **Internal docs:** This guide, [Nextcloud on Motoko](nextcloud_on_motoko.md)
- **Official docs:** [docs.nextcloud.com](https://docs.nextcloud.com/desktop/latest/)
- **Issues:** Contact IT or file in internal tracker

---

## Related Documentation

- [Nextcloud on Motoko](nextcloud_on_motoko.md)
- [M365 Sync Runbook](../runbooks/nextcloud_m365_sync.md)
- [User Experience Guide](../product/USER_EXPERIENCE_GUIDE.md)

