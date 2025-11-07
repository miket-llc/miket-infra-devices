"""Tailnet operations CLI.

This module exposes a Typer-based command line interface for day-to-day
interactions with the workstation tailnet.  The commands are thin wrappers
around tools such as the Tailscale CLI, Ansible playbooks, and Wake-on-LAN.

All user-facing functions are written so they can be imported by other
modules (for example the Textual monitor UI).  They raise
:class:`TailnetCommandError` when something goes wrong which makes them easy to
reuse from other Python entrypoints.
"""
from __future__ import annotations

import json
import os
import shlex
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional

import typer
from typer.main import get_command
from rich.console import Console
from rich.table import Table


APP = typer.Typer(help="Automation helpers for managing the workstation tailnet.")
console = Console()


REPO_ROOT = Path(__file__).resolve().parents[2]
ANSIBLE_DIR = REPO_ROOT / "ansible"
DEFAULT_INVENTORY = ANSIBLE_DIR / "inventory"


class TailnetCommandError(RuntimeError):
    """Raised when an underlying command invocation fails."""


@dataclass
class TailnetDevice:
    """Minimal view of a device returned by the Tailscale CLI."""

    hostname: str
    user: str
    online: bool
    ips: List[str]
    tags: Iterable[str]


def _run_command(command: List[str], env: Optional[Dict[str, str]] = None) -> str:
    """Execute *command* and return ``stdout``.

    Args:
        command: Sequence passed to :func:`subprocess.run`.
        env: Optional environment overrides.

    Raises:
        TailnetCommandError: If the command fails or cannot be executed.
    """

    console.log(f"Running command: {shlex.join(command)}")
    try:
        result = subprocess.run(
            command,
            check=False,
            capture_output=True,
            text=True,
            env=None if env is None else {**os.environ, **env},
        )
    except FileNotFoundError as exc:  # pragma: no cover - depends on environment
        raise TailnetCommandError(str(exc)) from exc

    if result.returncode != 0:
        message = f"Command failed ({result.returncode}): {shlex.join(command)}\n{result.stderr}"
        raise TailnetCommandError(message)

    return result.stdout


def fetch_tailnet_status() -> List[TailnetDevice]:
    """Return the current tailnet status as reported by ``tailscale status``.

    When Tailscale is not installed or the command cannot be executed an empty
    list is returned.  Consumers can decide how to present that scenario to the
    user.
    """

    try:
        output = _run_command(["tailscale", "status", "--json"])
    except TailnetCommandError:
        return []

    payload = json.loads(output)
    devices: List[TailnetDevice] = []

    peers = payload.get("Peer", {})
    user_map = payload.get("User", {})

    for device_id, meta in peers.items():
        user_id = meta.get("UserID")
        user = user_map.get(str(user_id), {}).get("LoginName", "unknown")
        addresses = meta.get("TailscaleIPs", [])
        devices.append(
            TailnetDevice(
                hostname=meta.get("HostName", device_id),
                user=user,
                online=meta.get("Online", False),
                ips=addresses,
                tags=meta.get("Tags", []) or [],
            )
        )

    # Include the local node as well so the monitor view always has at least one
    # row when the JSON payload contains it.
    self_info = payload.get("Self", {})
    if self_info:
        devices.insert(
            0,
            TailnetDevice(
                hostname=self_info.get("HostName", "self"),
                user=self_info.get("User", ""),
                online=self_info.get("Online", True),
                ips=self_info.get("TailscaleIPs", []),
                tags=self_info.get("Tags", []) or [],
            ),
        )

    return devices


def switch_device_mode(
    hostname: str,
    mode: str,
    *,
    inventory: Path = DEFAULT_INVENTORY,
    playbook: Optional[Path] = None,
) -> None:
    """Switch the workstation *hostname* into *mode* using Ansible.

    The helper looks for a playbook named ``workstations/switch_mode.yml`` by
    default.  A custom path can be provided via *playbook*.
    """

    selected_playbook = playbook or (ANSIBLE_DIR / "workstations" / "switch_mode.yml")

    if not selected_playbook.exists():
        raise TailnetCommandError(
            f"Unable to find the switch mode playbook: {selected_playbook}."
        )

    extra_vars = json.dumps({"target": hostname, "mode": mode})
    command = [
        "ansible-playbook",
        "-i",
        str(inventory),
        str(selected_playbook),
        "--extra-vars",
        extra_vars,
    ]
    _run_command(command)


def deploy_workstation(
    playbook: Path,
    *,
    inventory: Path = DEFAULT_INVENTORY,
    limit: Optional[str] = None,
    tags: Optional[str] = None,
) -> None:
    """Run an Ansible *playbook* against the workstation inventory."""

    if not playbook.exists():
        raise TailnetCommandError(f"Playbook not found: {playbook}")

    command = ["ansible-playbook", "-i", str(inventory), str(playbook)]

    if limit:
        command.extend(["--limit", limit])
    if tags:
        command.extend(["--tags", tags])

    _run_command(command)


def wake_device(mac_address: str, *, broadcast: str = "255.255.255.255") -> None:
    """Send a Wake-on-LAN packet to *mac_address*."""

    try:
        from wakeonlan import send_magic_packet
    except ImportError as exc:  # pragma: no cover - depends on optional deps
        raise TailnetCommandError("wakeonlan is not installed.") from exc

    send_magic_packet(mac_address, ip_address=broadcast)


@APP.command()
def status(json_output: bool = typer.Option(False, "--json", help="Emit JSON output")) -> None:
    """Display the current tailnet status."""

    devices = fetch_tailnet_status()

    if json_output:
        payload = [
            {
                "hostname": device.hostname,
                "user": device.user,
                "online": device.online,
                "ips": device.ips,
                "tags": list(device.tags),
            }
            for device in devices
        ]
        typer.echo(json.dumps(payload, indent=2))
        raise typer.Exit(code=0)

    if not devices:
        console.print("[yellow]No Tailscale status information available.[/yellow]")
        raise typer.Exit(code=0)

    table = Table(title="Tailnet Status")
    table.add_column("Hostname", style="cyan")
    table.add_column("User")
    table.add_column("Online", justify="center")
    table.add_column("IPs")
    table.add_column("Tags")

    for device in devices:
        table.add_row(
            device.hostname,
            device.user,
            "✅" if device.online else "❌",
            ", ".join(device.ips) or "-",
            ", ".join(device.tags) or "-",
        )

    console.print(table)


@APP.command("switch-mode")
def switch_mode(  # pragma: no cover - thin typer wrapper
    hostname: str = typer.Argument(..., help="Inventory hostname to target."),
    mode: str = typer.Argument(..., help="Desired workstation mode."),
    inventory: Path = typer.Option(
        DEFAULT_INVENTORY,
        "--inventory",
        "-i",
        help="Path to the Ansible inventory to use.",
    ),
    playbook: Optional[Path] = typer.Option(
        None,
        "--playbook",
        "-p",
        help="Override path to the switch_mode playbook.",
    ),
) -> None:
    """Switch a workstation into a predefined mode using Ansible."""

    try:
        switch_device_mode(hostname, mode, inventory=inventory, playbook=playbook)
    except TailnetCommandError as exc:
        console.print(f"[red]{exc}[/red]")
        raise typer.Exit(code=1) from exc

    console.print(f"[green]Mode '{mode}' applied to {hostname}.[/green]")


@APP.command()
def wake(  # pragma: no cover - thin typer wrapper
    mac_address: str = typer.Argument(..., help="MAC address of the device."),
    broadcast: str = typer.Option(
        "255.255.255.255",
        "--broadcast",
        "-b",
        help="Broadcast address used for the magic packet.",
    ),
) -> None:
    """Send a Wake-on-LAN packet to the provided MAC address."""

    try:
        wake_device(mac_address, broadcast=broadcast)
    except TailnetCommandError as exc:
        console.print(f"[red]{exc}[/red]")
        raise typer.Exit(code=1) from exc

    console.print(f"[green]Wake packet sent to {mac_address}.[/green]")


@APP.command()
def deploy(  # pragma: no cover - thin typer wrapper
    playbook: Path = typer.Argument(..., exists=False, help="Path to the Ansible playbook."),
    inventory: Path = typer.Option(
        DEFAULT_INVENTORY,
        "--inventory",
        "-i",
        help="Path to the Ansible inventory to use.",
    ),
    limit: Optional[str] = typer.Option(None, "--limit", "-l", help="Limit to hosts."),
    tags: Optional[str] = typer.Option(None, "--tags", "-t", help="Restrict to these tags."),
) -> None:
    """Run an Ansible playbook against the workstation inventory."""

    try:
        deploy_workstation(playbook, inventory=inventory, limit=limit, tags=tags)
    except TailnetCommandError as exc:
        console.print(f"[red]{exc}[/red]")
        raise typer.Exit(code=1) from exc

    console.print(f"[green]Playbook {playbook} completed successfully.[/green]")


@APP.command()
def monitor(  # pragma: no cover - thin typer wrapper
    refresh: float = typer.Option(30.0, "--refresh", help="Refresh interval in seconds."),
) -> None:
    """Launch the Textual tailnet monitor UI."""

    try:
        from tools.ui.app import TailnetMonitorApp
    except ImportError as exc:  # pragma: no cover - depends on optional deps
        console.print(
            "[red]Unable to import the Textual UI. Did you install tools/cli requirements?[/red]"
        )
        raise typer.Exit(code=1) from exc

    app = TailnetMonitorApp(refresh_interval=refresh)
    app.run()


def main(argv: Optional[List[str]] = None) -> None:
    """Entry point to run the CLI programmatically."""

    command = get_command(APP)
    command.main(args=argv, prog_name="tailnet")


if __name__ == "__main__":  # pragma: no cover - manual invocation helper
    main()
