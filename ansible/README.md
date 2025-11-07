# Ansible Automation

This directory houses inventories, playbooks, and reusable roles for automating configuration across the fleet. Keep environment-specific variables separated so production and lab assets can be targeted safely.

## Inventory group conventions

The shared inventory (`inventory/hosts.yml`) defines host operating-system families along with capability-oriented groups that make targeting GPU or Wake-on-LAN ready systems straightforward:

| Group | Purpose | Typical usage |
| ----- | ------- | ------------- |
| `gpu_8gb` | Linux and Windows nodes with ~8 GB of dedicated GPU VRAM | `ansible-playbook playbooks/gpu-driver.yml -l gpu_8gb` |
| `gpu_12gb` | Windows nodes with 12 GB+ VRAM suitable for heavier ML jobs | `ansible-playbook playbooks/vllm.yml -l gpu_12gb` |
| `wol_enabled` | Devices that can be powered on remotely via Wake-on-LAN | `ansible-playbook playbooks/power/wol.yml -l wol_enabled` |

When adding a new host, place it under the appropriate OS family and opt in to any capability groupings it supports. This keeps playbooks focused on the features they configure rather than specific device names.
