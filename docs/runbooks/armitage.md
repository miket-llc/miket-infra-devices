# Armitage Workstation Runbook

This document explains how to operate the Armitage workstation when switching between productivity and gaming workloads, as well as the observability resources that are available for the device.

## Overview

Armitage is a Windows 11 workstation configured for:
- **Workstation Mode**: Normal productivity and gaming use
- **LLM Serving Mode**: Automatic vLLM inference when idle
- **Automatic Switching**: Seamlessly transitions between modes based on usage

See [Armitage vLLM Setup](./armitage-vllm.md) for detailed vLLM configuration.

## Mode Switching Workflow

### Manual Mode Switching

The `devices/armitage/scripts/Set-WorkstationMode.ps1` script provides manual control:

**Switch to Gaming Mode:**
```powershell
.\Set-WorkstationMode.ps1 -Mode Gaming
```

**Switch to Productivity Mode:**
```powershell
.\Set-WorkstationMode.ps1 -Mode Productivity
```

**Switch to Development Mode:**
```powershell
.\Set-WorkstationMode.ps1 -Mode Development
```

### vLLM Mode Management

For vLLM mode control, use `Start-VLLM.ps1`:

```powershell
# Manual mode switching only - auto-switcher removed per CEO directive
# Start vLLM container
.\Start-VLLM.ps1 -Action Start

# Stop vLLM container
.\Start-VLLM.ps1 -Action Stop
```

See [Armitage vLLM Setup](./armitage-vllm.md) for complete vLLM documentation.

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
