# Device Onboarding Runbook

This runbook walks a new operator through preparing a workstation or server for day-to-day fleet management.

## 1. Join the tailnet
1. Install the Tailscale client appropriate for the platform.
2. Authenticate with your organization SSO account and approve the device from the admin console if prompted.
3. Tag the device with the correct ACL roles (for example `workstation`, `automation`) so it inherits the expected access.
4. Confirm connectivity by pinging an existing node: `tailscale ping motoko`.

## 2. Enable Wake-on-LAN (WOL)
1. Ensure the device has a wired Ethernet connection configured for wake events.
2. In firmware settings, enable Wake-on-LAN or Power On By PCI-E.
3. Inside the operating system, enable wake packets:
   - **Linux** – `nmcli connection modify <name> 802-3-ethernet.wake-on-lan magic`
   - **Windows** – Enable *Wake on Magic Packet* in the adapter power management properties.
4. Update `ansible/inventory/hosts.yml` so the host is listed under the `wol_enabled` group.
5. Test from a management node using the `tools/cli/wol` helper (see below).

## 3. Use the CLI and UI toolchains
- **CLI helpers** – Install Python requirements, then run commands such as `poetry run wol send --host armitage`. The CLI assumes tailnet DNS resolution.
- **UI bundle** – The `tools/ui` package provides a dashboard for device health and wake operations. Launch with `npm install` followed by `npm run dev` and connect via your tailnet address.
- **Automation** – Target capability groups when running playbooks, e.g., `ansible-playbook playbooks/gpu-driver.yml -l gpu_8gb`.

## 4. Troubleshooting
- **Tailnet join issues** – Verify the device time is correct and rerun `tailscale up --reset` if auth errors persist.
- **WOL failures** – Check switch configuration for blocked broadcast packets and confirm the NIC supports wake events while suspended.
- **Exporter visibility** – Prometheus scrapes expect the ports defined in `tools/monitoring/prometheus.yml`. Ensure firewalls allow inbound connections from the monitoring node.
- **Inventory drift** – If a device changes hardware (for example, GPU upgrade), update both the device profile under `devices/<hostname>/config.yml` and the matching inventory groups.
