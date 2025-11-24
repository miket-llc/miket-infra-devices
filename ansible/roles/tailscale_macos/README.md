# tailscale_macos Role (DEPRECATED)

**This role is deprecated.** Use the unified `tailscale` role instead.

The unified `tailscale` role handles all platforms (Linux, macOS, Windows) and provides the same functionality.

## Migration

Replace:
```yaml
- name: tailscale_macos
```

With:
```yaml
- name: tailscale
```

Or use the unified playbook:
```bash
ansible-playbook -i inventory/hosts.yml playbooks/deploy-tailscale-and-codex.yml
```

