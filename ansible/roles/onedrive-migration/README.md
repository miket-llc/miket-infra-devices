# onedrive-migration Ansible Role

Deploys and executes migration of OneDrive for Business content to `/space` drive on motoko.

## Requirements

- Rclone configured with M365 remote (e.g., `m365-<account>`)
- Sufficient disk space on `/space` partition
- Ansible access to motoko

## Role Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `onedrive_migration_account` | (required) | OneDrive account name (e.g., 'mike') |
| `onedrive_migration_dest` | (required) | Destination directory in /space (e.g., '/space/mike') |
| `onedrive_migration_conflict_resolution` | `rename` | How to handle conflicts: `rename`, `skip`, or `overwrite` |
| `onedrive_migration_transfers` | `8` | Number of parallel transfers |
| `onedrive_migration_dry_run` | `false` | Perform dry run without copying files |
| `onedrive_migration_owner` | `mdt` | Owner of destination directory |
| `onedrive_migration_group` | `mdt` | Group of destination directory |

## Example Playbook

```yaml
- hosts: motoko
  roles:
    - role: onedrive-migration
      vars:
        onedrive_migration_account: mike
        onedrive_migration_dest: /space/mike
        onedrive_migration_dry_run: true
```

## Usage

### Dry Run

```bash
ansible-playbook ansible/playbooks/motoko/migrate-onedrive-to-space.yml \
    --limit motoko \
    --extra-vars "onedrive_migration_account=mike onedrive_migration_dest=/space/mike onedrive_migration_dry_run=true"
```

### Production Migration

```bash
ansible-playbook ansible/playbooks/motoko/migrate-onedrive-to-space.yml \
    --limit motoko \
    --extra-vars "onedrive_migration_account=mike onedrive_migration_dest=/space/mike"
```

## Dependencies

None

## License

MIT

## Author Information

Codex-CA-001 (Chief Architect)


