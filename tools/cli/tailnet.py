"""Typer-based CLI utilities for Tailnet-connected workstations."""
from __future__ import annotations

import json
import os
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, Optional

import typer
from rich import box
from rich.console import Console
from rich.prompt import Confirm
from rich.table import Table

try:  # pragma: no cover - optional dependency
    import yaml  # type: ignore
except Exception:  # pragma: no cover - PyYAML is optional
    yaml = None

try:  # pragma: no cover - optional dependency
    from wakeonlan import send_magic_packet
except Exception:  # pragma: no cover - wakeonlan is optional
    send_magic_packet = None

QUIET_ENV_VAR = "TAILNET_CLI_QUIET"

app = typer.Typer(help="Manage Tailnet-connected workstations and supporting tasks.")
console = Console()

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
DEFAULT_INVENTORY = REPO_ROOT / "devices" / "inventory.yaml"


class InventoryError(RuntimeError):
    """Raised when the inventory cannot be processed."""


@dataclass
class Device:
    """Represents a single device from the inventory."""

    name: str
    attributes: Dict[str, object]

    @property
    def mac(self) -> Optional[str]:
        network = self.attributes.get("network", {}) if isinstance(self.attributes, dict) else {}
        if isinstance(network, dict):
            mac = network.get("mac") or network.get("mac_address")
            if isinstance(mac, str):
                return mac
        return None

    @property
    def hostname(self) -> str:
        hostname = self.attributes.get("hostname") if isinstance(self.attributes, dict) else None
        return hostname or self.name

    @property
    def os(self) -> str:
        value = self.attributes.get("os") if isinstance(self.attributes, dict) else None
        return value or "unknown"

    @property
    def tailscale_enabled(self) -> bool:
        network = self.attributes.get("network", {}) if isinstance(self.attributes, dict) else {}
        if isinstance(network, dict):
            value = network.get("tailscale")
            if isinstance(value, str):
                return value.lower() in {"enabled", "true", "yes"}
            if isinstance(value, bool):
                return value
        return False


def _load_yaml_inventory(path: Path) -> Dict[str, object]:
    if not path.exists():
        raise InventoryError(f"Inventory file not found: {path}")
    if yaml is None:
        raise InventoryError("PyYAML is required to read the device inventory. Install with `pip install pyyaml`." )
    with path.open("r", encoding="utf8") as handle:
        data = yaml.safe_load(handle)
    if not isinstance(data, dict):
        raise InventoryError("Inventory file must contain a top-level mapping.")
    return data


def iter_devices(inventory: Dict[str, object]) -> Iterable[Device]:
    devices_section = inventory.get("devices") if isinstance(inventory, dict) else None
    if not isinstance(devices_section, dict):
        return []
    for group, group_devices in devices_section.items():
        if not isinstance(group_devices, dict):
            continue
        for name, attributes in group_devices.items():
            if isinstance(attributes, dict):
                yield Device(name=name, attributes=attributes)


def find_device(identifier: str, inventory_path: Path = DEFAULT_INVENTORY) -> Optional[Device]:
    try:
        inventory = _load_yaml_inventory(inventory_path)
    except InventoryError as error:
        console.print(f"[red]Unable to load inventory:[/] {error}")
        return None

    identifier_normalized = identifier.lower()
    for device in iter_devices(inventory):
        if device.name.lower() == identifier_normalized:
            return device
        if device.hostname.lower() == identifier_normalized:
            return device
    return None


def run_subprocess(
    command: Iterable[str], *, check: bool = False, quiet: Optional[bool] = None
) -> subprocess.CompletedProcess[str]:
    command_list = list(command)
    if quiet is None:
        quiet = os.environ.get(QUIET_ENV_VAR) == "1"
    if not quiet:
        console.log(f"Running command: {' '.join(command_list)}")
    return subprocess.run(
        command_list,
        check=check,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def _tailscale_binary(path: Optional[str]) -> str:
    if path:
        return path
    return os.environ.get("TAILSCALE_BIN", "tailscale")


@app.command()
def status(
    raw: bool = typer.Option(False, help="Print raw tailscale status output."),
    json_output: bool = typer.Option(False, help="Return raw JSON payload if supported."),
    tailscale_bin: Optional[str] = typer.Option(None, help="Path to the tailscale binary."),
) -> None:
    """Display the status of the current Tailnet session."""

    binary = _tailscale_binary(tailscale_bin)

    if raw and json_output:
        raise typer.BadParameter("Use --raw or --json-output, not both.")

    args = [binary, "status"]
    if json_output:
        args.append("--json")

    try:
        result = run_subprocess(args)
    except FileNotFoundError:
        console.print(f"[red]tailscale binary not found at '{binary}'.[/]")
        raise typer.Exit(code=2)

    if result.returncode != 0:
        console.print(f"[red]tailscale status failed ({result.returncode}):[/]\n{result.stderr.strip()}")
        raise typer.Exit(code=result.returncode)

    if raw:
        console.print(result.stdout)
        return

    payload: Optional[Dict[str, object]] = None
    if json_output:
        console.print(result.stdout)
        return

    # Attempt to request JSON for richer output.
    if "\"" in result.stdout or result.stdout.strip().startswith("{"):
        try:
            payload = json.loads(result.stdout)
        except json.JSONDecodeError:
            payload = None
    else:
        # Fallback attempt with --json when not explicitly requested.
        try:
            json_result = run_subprocess([binary, "status", "--json"], quiet=True)
            if json_result.returncode == 0:
                payload = json.loads(json_result.stdout)
        except FileNotFoundError:
            payload = None
        except json.JSONDecodeError:
            payload = None

    if payload is None:
        console.print(result.stdout)
        return

    table = Table(title="Tailnet Status", box=box.SIMPLE_HEAVY)
    table.add_column("Peer")
    table.add_column("User")
    table.add_column("OS")
    table.add_column("Tailscale IP")
    table.add_column("Last Seen")

    peers = payload.get("Peer") if isinstance(payload, dict) else None
    if isinstance(peers, dict):
        for peer_id, peer_data in peers.items():
            if not isinstance(peer_data, dict):
                continue
            host = peer_data.get("HostName", peer_id)
            user = peer_data.get("User")
            os_name = peer_data.get("OS")
            tailscale_ips = peer_data.get("TailscaleIPs") or []
            tail_ip = ", ".join(tailscale_ips) if isinstance(tailscale_ips, list) else ""
            last_seen = peer_data.get("LastSeen") or "?"
            table.add_row(str(host), str(user), str(os_name), tail_ip, str(last_seen))

    console.print(table)


@app.command("switch-mode")
def switch_mode(
    mode: str = typer.Argument(..., help="Desired mode, e.g. 'workstation' or 'exit-node'."),
    exit_node: Optional[str] = typer.Option(None, help="Exit node hostname or IP when mode requires it."),
    tailscale_bin: Optional[str] = typer.Option(None, help="Path to the tailscale binary."),
    yes: bool = typer.Option(False, "--yes", "-y", help="Assume yes for any confirmation prompts."),
) -> None:
    """Toggle between Tailnet modes such as workstation and exit-node."""

    normalized = mode.lower()
    binary = _tailscale_binary(tailscale_bin)

    if normalized not in {"workstation", "exit-node", "exitnode", "direct"}:
        raise typer.BadParameter("Supported modes: workstation, exit-node, direct")

    if normalized in {"exit-node", "exitnode"} and not exit_node:
        raise typer.BadParameter("--exit-node is required when switching to exit-node mode")

    if not yes:
        if not Confirm.ask(f"Apply Tailnet mode '{mode}' using {binary}?"):
            raise typer.Exit(code=0)

    command = [binary, "set"]
    if normalized in {"workstation", "direct"}:
        command.append("--exit-node=")
        command.append("--exit-node-allow-lan-access=false")
    else:
        command.append(f"--exit-node={exit_node}")
        command.append("--exit-node-allow-lan-access=true")

    try:
        result = run_subprocess(command)
    except FileNotFoundError:
        console.print(f"[red]tailscale binary not found at '{binary}'.[/]")
        raise typer.Exit(code=2)

    if result.returncode != 0:
        console.print(f"[red]tailscale set failed ({result.returncode}):[/]\n{result.stderr.strip()}")
        raise typer.Exit(code=result.returncode)

    console.print("[green]Tailnet mode updated successfully.[/]")


@app.command()
def wake(
    target: str = typer.Argument(..., help="Inventory name, hostname, or MAC address."),
    broadcast: Optional[str] = typer.Option(None, help="Broadcast address for the magic packet."),
    inventory: Path = typer.Option(DEFAULT_INVENTORY, exists=False, help="Path to the device inventory."),
) -> None:
    """Send a Wake-on-LAN packet to a workstation."""

    mac = None
    if target.count(":") >= 5 or target.count("-") >= 5:
        mac = target
    else:
        device = find_device(target, inventory)
        if device and device.mac:
            mac = device.mac
        elif device:
            console.print(f"[yellow]No MAC address stored for {device.name}. Provide one explicitly.")

    if mac is None:
        console.print("[red]Unable to resolve MAC address for target.[/]")
        raise typer.Exit(code=1)

    if send_magic_packet is None:
        console.print("[red]wakeonlan module is not installed. Install with `pip install wakeonlan`." )
        raise typer.Exit(code=1)

    kwargs = {"address": broadcast} if broadcast else {}
    send_magic_packet(mac, **kwargs)
    console.print(f"[green]Sent wake signal to {mac}.[/]")


@app.command()
def deploy(
    playbook: Path = typer.Option(Path("ansible/workstations/site.yml"), help="Path to the Ansible playbook."),
    limit: Optional[str] = typer.Option(None, help="Limit execution to the provided Ansible host pattern."),
    check: bool = typer.Option(False, help="Run Ansible in check mode."),
    extra_vars: Optional[str] = typer.Option(None, help="JSON/YAML string of additional vars."),
    inventory: Optional[Path] = typer.Option(None, help="Path to the Ansible inventory file."),
) -> None:
    """Run an Ansible playbook for Tailnet-connected workstations."""

    command = ["ansible-playbook", str(playbook)]
    if limit:
        command.extend(["--limit", limit])
    if check:
        command.append("--check")
    if extra_vars:
        command.extend(["--extra-vars", extra_vars])
    if inventory:
        command.extend(["-i", str(inventory)])

    try:
        result = run_subprocess(command)
    except FileNotFoundError:
        console.print("[red]ansible-playbook command not found. Ensure Ansible is installed in your environment.[/]")
        raise typer.Exit(code=2)

    if result.returncode != 0:
        console.print(f"[red]Ansible execution failed ({result.returncode}):[/]\n{result.stderr.strip()}")
        raise typer.Exit(code=result.returncode)

    console.print(result.stdout)


@app.command()
def monitor(
    tailscale_bin: Optional[str] = typer.Option(None, help="Override path to tailscale binary for the UI."),
    refresh_interval: float = typer.Option(15.0, help="Status refresh cadence in seconds."),
) -> None:
    """Launch the Textual monitoring dashboard."""

    env = os.environ.copy()
    if tailscale_bin:
        env["TAILSCALE_BIN"] = tailscale_bin
    env[QUIET_ENV_VAR] = "1"

    command = [sys.executable, "-m", "tools.ui.app", "--refresh-interval", str(refresh_interval)]

    try:
        process = subprocess.run(command, env=env)
    except FileNotFoundError:
        console.print("[red]Unable to launch Textual UI. Ensure dependencies are installed.")
        raise typer.Exit(code=2)

    if process.returncode != 0:
        raise typer.Exit(code=process.returncode)


def main() -> None:
    app()


if __name__ == "__main__":
    main()
