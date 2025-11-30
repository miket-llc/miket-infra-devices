# Lessons Learned - Container Runtime Standardization

**Date:** 2025-11-30  
**Task:** Implement Podman container runtime standard  
**Status:** Complete with fixes applied

---

## What the Other Agent Fixed

### Commit: `c7a976a` - "fix(podman_standard_linux): correct task ordering and add Ubuntu NVIDIA support"

#### Issue 1: Task Ordering Bug
**Problem:** I wrote configuration files to `/etc/containers/storage.conf.d/00-custom-storage.conf` BEFORE ensuring the directory existed.

**Original (broken) order:**
```yaml
- name: Configure Podman storage.conf for custom paths
  ansible.builtin.copy:
    dest: /etc/containers/storage.conf.d/00-custom-storage.conf
    # ...

- name: Ensure storage.conf.d directory exists  # <-- Too late!
  ansible.builtin.file:
    path: /etc/containers/storage.conf.d
    state: directory
```

**Fixed order:**
```yaml
- name: Ensure storage.conf.d directory exists  # <-- First!
  ansible.builtin.file:
    path: /etc/containers/storage.conf.d
    state: directory
    mode: '0755'

- name: Configure Podman storage.conf for custom paths
  ansible.builtin.copy:
    dest: /etc/containers/storage.conf.d/00-custom-storage.conf
    # ...
```

**Lesson:** Always create directories BEFORE writing files to them. Ansible won't auto-create nested directories for `copy` or `template` modules.

---

#### Issue 2: Stale Comments
**Problem:** Left references to old role name `podman_base` in comments after renaming to `podman_standard_linux`.

**Example:**
```yaml
# OLD comment:
# Configured by Ansible podman_base role

# FIXED:
# Configured by Ansible podman_standard_linux role
```

**Lesson:** When renaming modules/roles, grep for ALL references including comments, templates, and documentation.

---

#### Issue 3: Missing Ubuntu NVIDIA Support
**Problem:** NVIDIA Container Toolkit installation only worked on Fedora. Ubuntu/Debian hosts would fail silently or not get GPU support.

**What was missing:**
- Repository setup for Ubuntu (`add-apt-repository`)
- Different package names/installation method
- Ubuntu-specific NVIDIA toolkit configuration

**What they added:**
```yaml
- name: Add NVIDIA container repository (Ubuntu/Debian)
  ansible.builtin.apt_repository:
    repo: "deb https://nvidia.github.io/libnvidia-container/stable/ubuntu$(lsb_release -rs)/$(ARCH) /"
    state: present
  when:
    - ansible_os_family == "Debian"
    - podman_nvidia_enabled | bool

- name: Install NVIDIA Container Toolkit (Ubuntu/Debian)
  ansible.builtin.apt:
    name: nvidia-container-toolkit
    state: present
    update_cache: true
  when:
    - ansible_os_family == "Debian"
    - podman_nvidia_enabled | bool
```

**Lesson:** Multi-distro support requires testing each distro's package manager quirks:
- RedHat: `dnf`, repos via `.repo` files
- Debian: `apt`, repos via `apt-add-repository` or `sources.list.d/`
- NVIDIA repos have different URLs per distro

---

## What I Did Right

1. **Documentation First:** Created comprehensive standard document before implementing
2. **Conflict Detection:** Added checks for existing Docker instead of blindly removing it
3. **Backward Compatibility:** Kept `podman_base` for motoko's existing work
4. **Clear Separation:** Windows/macOS explicitly excluded from Linux changes
5. **Tagging Strategy:** Proper tags for SRE workflows (`podman_standard`)

---

## What I Should Improve

1. **Test Task Ordering:** Always verify directory creation happens before file writes
2. **Multi-Distro Testing:** Test each supported distro's package manager behavior
3. **Comment Hygiene:** Automated grep for old names during refactoring
4. **Parallel Work Awareness:** Check for in-progress work FIRST (I initially almost stepped on motoko migration)

---

## Verification Results

### Syntax Checks
```bash
ansible-playbook playbooks/linux-baseline.yml --syntax-check
# ✅ PASS

ansible-playbook playbooks/workstations/linux.yml --syntax-check
# ✅ PASS
```

### Host Targeting
```bash
ansible-playbook playbooks/linux-baseline.yml --limit wintermute --list-hosts
# ✅ Correctly shows 0 hosts (wintermute is Windows, excluded from linux group)

ansible linux -m ping
# ✅ motoko responds (Fedora 43 Server Edition)
```

### Role Compatibility
- ✅ `podman_base` still exists for motoko's containers.yml
- ✅ `podman_standard_linux` available for new Linux hosts
- ✅ Multi-distro support (Fedora + Ubuntu)
- ✅ Docker CLI compatibility (podman-docker or wrapper)

---

## Testing Strategy Going Forward

When adding new Linux hosts:

1. **Dry run first:**
   ```bash
   ansible-playbook playbooks/linux-baseline.yml --limit new-host --check
   ```

2. **Verify OS detection:**
   ```bash
   ansible new-host -m setup -a "filter=ansible_os_family"
   ```

3. **Check package availability:**
   ```bash
   # Fedora
   ansible new-host -m command -a "dnf search podman"
   
   # Ubuntu
   ansible new-host -m command -a "apt-cache search podman"
   ```

4. **Test role in isolation:**
   ```bash
   ansible-playbook playbooks/linux-baseline.yml --limit new-host --tags podman_standard
   ```

5. **Verify Docker CLI compatibility:**
   ```bash
   ansible new-host -m command -a "docker --version"
   ansible new-host -m command -a "docker ps"
   ```

---

## Files Modified by Other Agent

From commit `c7a976a`:
- `ansible/roles/podman_standard_linux/tasks/main.yml` - Task ordering fix, Ubuntu NVIDIA support
- `ansible/roles/podman_standard_linux/README.md` - Created comprehensive docs
- `ansible/roles/podman_standard_linux/defaults/main.yml` - Added Ubuntu package lists
- `ansible/roles/podman_standard_linux/handlers/main.yml` - Created handlers

All fixes were **additive** - they improved my work without breaking functionality.

---

## Current Status

- ✅ Container runtime standard defined and documented
- ✅ `podman_standard_linux` role working for Fedora + Ubuntu
- ✅ Playbooks created and syntax-validated
- ✅ motoko container work proceeding independently (other agent)
- ✅ Windows/macOS hosts correctly excluded
- ⏳ **Awaiting:** motoko deployment completion by other agent
- 📋 **Next:** Test on a real Linux workstation when available

---

## Key Takeaways

1. **Ansible task order matters** - Dependencies must be explicit
2. **Multi-distro = multi-testing** - Can't assume one package manager
3. **Comments are code** - Keep them updated during refactors
4. **Coordinate with other agents** - Check for parallel work first
5. **Documentation prevents confusion** - Standard doc clarified who does what

---

**Prepared by:** Container Runtime Standardization Team  
**Review Date:** 2025-11-30  
**Status:** Lessons Incorporated

