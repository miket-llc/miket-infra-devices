# Workstation Runbook

This runbook covers preparing a Python environment for the workstation tooling and invoking the CLI/Textual interfaces across Windows, macOS, and Linux.

## 1. Prerequisites

- Python 3.11 or newer.
- Git (optional but recommended for keeping the repository in sync).
- Access to the Tailnet with credentials that permit running `tailscale` commands.
- Ansible (installed automatically via the CLI requirements).

> **Tip:** The CLI dependencies are isolated to `tools/cli/requirements.txt` so you can install them into a virtual environment without affecting system Python packages.

## 2. Environment Setup

### Windows (PowerShell)

```powershell
# From the repository root
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r tools/cli/requirements.txt
```

If `tailscale.exe` is not on your `PATH`, locate it (usually `"C:\Program Files (x86)\Tailscale\tailscale.exe"`) and export it before running commands:

```powershell
$env:TAILSCALE_BIN = "C:\Program Files (x86)\Tailscale\tailscale.exe"
```

### macOS (zsh)

```zsh
# From the repository root
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r tools/cli/requirements.txt
```

If Homebrew installed Tailscale, you can ensure it is accessible by exporting:

```zsh
export TAILSCALE_BIN=/Applications/Tailscale.app/Contents/MacOS/Tailscale
```

### Linux (bash)

```bash
# From the repository root
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r tools/cli/requirements.txt
```

Most Linux distributions install `tailscale` to `/usr/bin/tailscale`. If it lives elsewhere, export `TAILSCALE_BIN` to point at it.

### Activating the Environment Later

- **Windows:** `.\.venv\Scripts\Activate.ps1`
- **macOS/Linux:** `source .venv/bin/activate`

To leave the environment, run `deactivate`.

## 3. Using the Typer CLI (`tailnet.py`)

All commands are executed from the repository root with the virtual environment activated.

```bash
python -m tools.cli.tailnet --help
```

### Status

Fetch a formatted view of the Tailnet peers:

```bash
python -m tools.cli.tailnet status
```

To retrieve the raw JSON payload for automation:

```bash
python -m tools.cli.tailnet status --json-output
```

### Switch Mode

Toggle the local node between workstation and exit-node modes:

```bash
# Disable exit-node usage
python -m tools.cli.tailnet switch-mode workstation

# Enable exit-node usage through a specific peer
python -m tools.cli.tailnet switch-mode exit-node --exit-node motoko
```

### Wake a Device

Wake a workstation by inventory name, hostname, or MAC address:

```bash
python -m tools.cli.tailnet wake wintermute
python -m tools.cli.tailnet wake 00:11:22:33:44:55 --broadcast 192.168.1.255
```

### Deploy via Ansible

Run the default workstation playbook or specify your own:

```bash
python -m tools.cli.tailnet deploy
python -m tools.cli.tailnet deploy --playbook ansible/workstations/site.yml --limit wintermute
```

Pass extra variables in JSON/YAML format when needed:

```bash
python -m tools.cli.tailnet deploy --extra-vars '{"feature_toggle": true}'
```

### Launch the Monitoring UI

Start the Textual dashboard (defaults to a 15 second refresh interval):

```bash
python -m tools.cli.tailnet monitor
```

If you need to override the Tailscale binary or refresh cadence:

```bash
python -m tools.cli.tailnet monitor --tailscale-bin /usr/local/bin/tailscale --refresh-interval 5
```

## 4. Troubleshooting

| Symptom | Resolution |
| --- | --- |
| `tailscale` command not found | Ensure Tailscale is installed and `TAILSCALE_BIN` points to the binary. |
| `PyYAML is required` message when running `wake` | Install PyYAML into your environment: `pip install pyyaml`. |
| Wake command fails with permissions | Run PowerShell/terminal with elevated privileges so the network stack permits broadcasting. |
| Ansible playbook cannot find inventory | Pass `--inventory` to the CLI command with the correct `hosts.yml`. |

## 5. Keeping Dependencies Updated

Re-run the `pip install -r tools/cli/requirements.txt` command after pulling repository changes to ensure your environment matches the repository requirements.
