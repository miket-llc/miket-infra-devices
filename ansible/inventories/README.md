# Inventory Files

## Primary Inventory

**`ansible/inventory/hosts.yml`** - This is the primary, authoritative inventory file used by Ansible.

## Legacy Inventory

**`ansible/inventories/hosts.ini`** - This is a legacy INI-format inventory file that is **not currently used**.

### Status: Deprecated

This file exists for historical reference but should not be used. All inventory management should use `ansible/inventory/hosts.yml`.

### Migration

If you need to reference hosts from the INI file, they should be added to `ansible/inventory/hosts.yml` instead.

### Removal

This file can be safely removed after verifying all hosts are in `ansible/inventory/hosts.yml`.

