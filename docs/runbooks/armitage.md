# Armitage Workstation Runbook

This document explains how to operate the Armitage workstation when switching between productivity and gaming workloads, as well as the observability resources that are available for the device.

## Mode Switching Workflow

The `devices/armitage/scripts/mode_switcher.py` helper drives the transition between the two supported modes (`gaming` and `productivity`). The script enables or stops the relevant systemd units and records the current mode so that the monitoring stack can expose the device state.

### Prerequisites

* The workstation must be configured with the `gaming-mode` and `llm-serving` roles.
* The user running the script requires permissions to interact with `systemctl` for the managed units.

### Switch to Gaming Mode

```bash
sudo devices/armitage/scripts/mode_switcher.py switch gaming
```

This command performs the following actions:

1. Stops low-priority background targets (for example `llm-idle.target`).
2. Starts the `gaming-mode.target`, which applies service, firewall, and kernel tunings for latency-sensitive use cases.
3. Starts `vllm-container@armitage.service` if an LLM endpoint is needed for demos.
4. Persists the new state to `~/.local/share/armitage/mode_state.json` for reference by observability tooling.

### Switch Back to Productivity Mode

```bash
sudo devices/armitage/scripts/mode_switcher.py switch productivity
```

This reverses the previous changes by bringing background services back online and disabling the latency optimizations.

### Check the Current Mode

```bash
devices/armitage/scripts/mode_switcher.py status
```

Outputs the last stored mode without performing any changes. Use this in scripts or health checks when you only need to know the expected configuration.

## Expected Behavior in Gaming Mode

* Bluetooth, printing, and discovery daemons are disabled to remove background wakeups.
* Power profiles are forced to the `performance` governor when available. Additional kernel sysctl settings reduce scheduler migration and allow unprivileged profiling.
* Firewall rules open the standard UDP/TCP ranges for Steam-based titles.
* GPU persistence mode is enabled when the NVIDIA stack is present.

## Monitoring and Dashboards

Prometheus and Grafana assets for Armitage live in `tools/monitoring/`:

* `tools/monitoring/prometheus.yml` configures scrape jobs for the node exporter (`9100`), GPU metrics (`9400`), and the vLLM API (`8000`).
* `tools/monitoring/alerts/armitage.yml` defines device-specific alerts, including GPU thermal warnings, vLLM request errors, and detections for unexpected mode drift.
* `tools/monitoring/grafana/dashboards/armitage.json` provides a prebuilt dashboard that surfaces GPU temperatures, CPU load, vLLM request rate, and the current mode indicator.

Import the dashboard JSON into Grafana to visualize the metrics, and ensure Alertmanager is pointed at the Prometheus rules file to receive timely notifications.
