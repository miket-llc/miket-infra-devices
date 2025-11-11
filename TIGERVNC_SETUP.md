# TigerVNC Setup Summary for motoko

## ✅ What's Been Fixed

1. **TigerVNC Server Configuration**
   - Updated Ansible role to properly configure TigerVNC (not x11vnc)
   - Sets password to `motoko123` automatically
   - Configures to share GNOME session on display :0
   - Listens on all interfaces (not just localhost)

2. **Client Scripts Updated**
   - Linux: Updated `vnc` script with password info
   - Windows: Updated `vnc.bat` with password info  
   - macOS: Updated `vnc` script with password info

3. **Setup Script Created**
   - `scripts/setup-tigervnc-motoko.sh` - Run directly on motoko to set up TigerVNC

## 🚀 Deployment Steps

### Step 1: Setup TigerVNC Server on motoko

**Option A: Run setup script directly on motoko**
```bash
# Copy script to motoko and run:
./scripts/setup-tigervnc-motoko.sh
```

**Option B: Use Ansible (if SSH access works)**
```bash
cd /home/mdt/miket-infra-devices
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/remote_server.yml -l motoko --tags remote:server
```

### Step 2: Deploy VNC Clients to All Devices

**Linux (wintermute, armitage if they have Linux):**
```bash
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/remote_clients.yml -l linux
```

**Windows (wintermute, armitage):**
```bash
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/remote_clients.yml -l windows
```

**macOS (count-zero):**
```bash
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/remote_clients.yml -l macos
```

## 📋 Connection Instructions

### From Linux:
```bash
vnc motoko
# Password: motoko123
```

Or:
```bash
remmina -c vnc://motoko.pangolin-vega.ts.net:5900
# Password: motoko123
```

### From Windows:
```cmd
vnc motoko
# Password: motoko123 (will be prompted)
```

Or launch TigerVNC Viewer manually and connect to:
```
motoko.pangolin-vega.ts.net:5900
Password: motoko123
```

### From macOS:
```bash
vnc motoko
# Password: motoko123
```

Or:
```bash
open vnc://motoko.pangolin-vega.ts.net:5900
# Password: motoko123
```

## 🔑 Connection Details

- **Host**: motoko.pangolin-vega.ts.net
- **Port**: 5900
- **Password**: motoko123
- **Protocol**: VNC (TigerVNC)
- **Session**: Shares existing GNOME desktop session

## ✅ Verification

After setup, verify it works:
```bash
# From any device:
nc -zv motoko.pangolin-vega.ts.net 5900
# Should show: Connection succeeded

# Check service on motoko:
sudo systemctl status tigervnc
```

## 📝 Files Changed

1. `ansible/roles/remote_server_linux_vnc/tasks/main.yml` - Fixed to use TigerVNC with password
2. `ansible/roles/remote_server_linux_vnc/templates/tigervnc.service.j2` - Fixed display to :0
3. `ansible/roles/remote_client_linux/templates/vnc_connect.sh.j2` - Added password info
4. `ansible/roles/remote_client_windows/tasks/main.yml` - Added password comment
5. `ansible/roles/remote_client_macos/templates/vnc_connect.sh.j2` - Added password info
6. `scripts/setup-tigervnc-motoko.sh` - New setup script
7. `docs/VNC_CONNECTION_INSTRUCTIONS.md` - Detailed connection guide

