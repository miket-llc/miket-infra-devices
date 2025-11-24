# Workstation Operations Runbook

This guide explains how to prepare a Python environment for the automation
helpers in this repository and how to run the command line interface (CLI) and
Textual dashboard on the three major desktop platforms.

**Note:** Tailnet CLI installation is a **manual prerequisite** that must be completed before automated Codex CLI deployment. Follow the instructions below to install Tailnet CLI manually on each device.

## Repository layout

* `tools/cli/tailnet.py` – Typer CLI with commands for querying status,
  switching workstation modes, sending wake-on-LAN packets, and triggering
  Ansible deployments.
* `tools/ui/app.py` – Textual dashboard that shows the same status data in a
  terminal user interface.
* `tools/cli/requirements.txt` – Python dependencies required by both entry
  points.

## Preparing Python

All commands below assume that you have cloned this repository locally and the
shell is located at the repository root.

### Windows 11+

1. Install [Python 3.11+ for Windows](https://www.python.org/downloads/windows/)
   and make sure the installer adds Python to your `PATH`.
2. Open **Windows Terminal** or **PowerShell** and create a virtual environment:

   ```powershell
   py -3.11 -m venv .\.venv
   .\.venv\Scripts\Activate.ps1
   ```

3. Install the tooling dependencies:

   ```powershell
   pip install -r tools/cli/requirements.txt
   ```

### macOS 13+

1. Install Python via [Homebrew](https://brew.sh/):

   ```bash
   brew install python@3.11
   ```

2. Create and activate a virtual environment:

   ```bash
   /opt/homebrew/bin/python3.11 -m venv .venv
   source .venv/bin/activate
   ```

3. Install dependencies:

   ```bash
   pip install -r tools/cli/requirements.txt
   ```

### Ubuntu 22.04+

1. Install the system packages:

   ```bash
   sudo apt update && sudo apt install -y python3.11 python3.11-venv
   ```

2. Create a virtual environment and activate it:

   ```bash
   python3.11 -m venv .venv
   source .venv/bin/activate
   ```

3. Install the Python requirements:

   ```bash
   pip install -r tools/cli/requirements.txt
   ```

> **Tip:** add `source .venv/bin/activate` (or the PowerShell equivalent) to your
> shell profile to automatically activate the virtual environment when entering
> the repository.

## Using the CLI

The CLI exposes several subcommands. Run `python -m tools.cli.tailnet --help`
for a full reference.

### Check tailnet status

```bash
python -m tools.cli.tailnet status
```

Use `--json` to emit structured output for scripting.

### Switch workstation mode

```bash
python -m tools.cli.tailnet switch-mode <hostname> <mode>
```

Optional flags such as `--inventory` and `--playbook` allow you to target a
specific Ansible inventory or custom playbook.

### Wake a workstation

```bash
python -m tools.cli.tailnet wake <mac-address>
```

Use `--broadcast` to override the default broadcast address if required by your
network.

### Deploy configuration

```bash
python -m tools.cli.tailnet deploy ansible/workstations/site.yml --limit <host-pattern>
```

The command supports `--tags` to restrict execution to specific roles.

## Launch the Textual monitor

Run the monitor from the same virtual environment after installing the
requirements:

```bash
python -m tools.cli.tailnet monitor --refresh 15
```

The Textual UI shows a live view of the tailnet and refreshes automatically at
the chosen interval. Use `r` to trigger a manual refresh and `q` to quit.

---

## Codex CLI Deployment

After Tailnet CLI is manually installed, Codex CLI can be deployed automatically using Ansible:

```bash
cd /path/to/miket-infra-devices/ansible
ansible-playbook -i inventory/hosts.yml playbooks/deploy-codex-cli.yml
```

Codex CLI will be installed globally via npm and configured automatically. See the [Codex CLI deployment playbook](../../ansible/playbooks/deploy-codex-cli.yml) for details.
