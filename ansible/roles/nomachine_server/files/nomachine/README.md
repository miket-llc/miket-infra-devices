# NoMachine Binary Distribution

This directory contains NoMachine installer binaries for all supported platforms.

## Why Local Binaries?

NoMachine's download servers block automated/scripted downloads, making reliable IaC deployment impossible. Additionally, downloading large binaries over Tailnet from internet sources is unreliable.

**Solution:** Store versioned binaries in the repo and deploy via Ansible `copy` module.

## Directory Structure

```
ansible/roles/nomachine_server/files/nomachine/
├── CHECKSUMS.sha256      # SHA256 checksums for verification
├── README.md             # This file
├── linux/
│   └── nomachine_9.2.18_3_x86_64.rpm
├── macos/
│   └── nomachine_9.2.18_1.dmg
└── windows/
    └── nomachine_9.2.18_1_x64.exe
```

## Filename Convention

```
nomachine_<version>_<build>_<arch>.<ext>
```

- **version**: Major.minor.patch (e.g., 9.2.18)
- **build**: Build number from NoMachine (e.g., 1, 3)
- **arch**: Architecture (x86_64, arm64, x64)
- **ext**: Platform extension (rpm, deb, dmg, exe)

## Update Workflow

When new NoMachine versions are released:

1. **Download** new installers manually from https://www.nomachine.com/download
2. **Verify** downloads are complete (not HTML error pages)
3. **Move** to appropriate platform directories
4. **Update** `CHECKSUMS.sha256`:
   ```bash
   cd ansible/files/nomachine
   sha256sum linux/*.rpm macos/*.dmg windows/*.exe > CHECKSUMS.sha256
   ```
5. **Update** `ansible/roles/nomachine_server/defaults/main.yml`:
   - `nomachine_version`
   - `nomachine_*_filename` variables
6. **Commit** with message: `chore(nomachine): update to version X.Y.Z`
7. **Deploy** to devices: `ansible-playbook playbooks/deploy-nomachine.yml`

## Verification

```bash
# Verify checksums before deployment
cd ansible/roles/nomachine_server/files/nomachine
sha256sum -c CHECKSUMS.sha256
```

## Git LFS Consideration

These binaries are ~80-100MB each. If repo size becomes problematic, consider:
- Using Git LFS for `ansible/files/nomachine/`
- Storing in `/space/software/nomachine/` and symlinking

Current decision: Keep in repo for simplicity and IaC compliance.

## Related

- Role: `ansible/roles/nomachine_server/`
- Playbook: `ansible/playbooks/deploy-nomachine.yml`
- Architecture: `docs/architecture/components/REMOTE_DESKTOP_ARCHITECTURE.md`

