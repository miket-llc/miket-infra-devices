"""Textual dashboard for monitoring Tailnet-connected devices."""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from dataclasses import dataclass
from typing import Any, Dict, Optional

from rich.console import Console
from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Container, Vertical
from textual.reactive import reactive
from textual.widgets import DataTable, Footer, Header, Static, TextLog

console = Console()


@dataclass
class TailnetStatus:
    """Structured representation of the tailscale status payload."""

    peers: Dict[str, Dict[str, Any]]

    @classmethod
    def from_json(cls, payload: Dict[str, Any]) -> "TailnetStatus":
        peers = payload.get("Peer") if isinstance(payload, dict) else None
        if not isinstance(peers, dict):
            peers = {}
        return cls(peers=peers)


class TailnetCLIProxy:
    """Helper for interacting with the Typer CLI via subprocess calls."""

    def __init__(self, *, tailscale_bin: Optional[str] = None) -> None:
        self._tailscale_bin = tailscale_bin

    def status(self) -> TailnetStatus:
        env = os.environ.copy()
        env["TAILNET_CLI_QUIET"] = "1"
        if self._tailscale_bin:
            env["TAILSCALE_BIN"] = self._tailscale_bin

        command = [sys.executable, "-m", "tools.cli.tailnet", "status", "--json-output"]
        result = subprocess.run(command, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        if result.returncode != 0:
            console.print(f"[red]tailscale status failed:[/] {result.stderr.strip()}")
            raise RuntimeError(result.stderr.strip())

        try:
            payload = json.loads(result.stdout)
        except json.JSONDecodeError as error:  # pragma: no cover - defensive
            raise RuntimeError("Unable to decode tailscale status JSON") from error

        return TailnetStatus.from_json(payload)


class SummaryWidget(Static):
    """Simple widget that renders counts of online peers."""

    total = reactive(0)

    def render(self) -> str:  # pragma: no cover - UI rendering
        return f"Peers online: {self.total}"


class TailnetMonitorApp(App[None]):
    """Textual UI entry point for monitoring Tailnet peers."""

    CSS = """
    #body {
        layout: horizontal;
    }

    #sidebar {
        width: 40%;
        min-width: 30;
    }

    #log {
        height: 1fr;
    }

    DataTable {
        height: 1fr;
    }
    """

    BINDINGS = [
        Binding("r", "refresh", "Refresh"),
        Binding("q", "quit", "Quit"),
    ]

    def __init__(self, *, refresh_interval: float = 15.0, tailscale_bin: Optional[str] = None) -> None:
        super().__init__()
        self.refresh_interval = refresh_interval
        self.api = TailnetCLIProxy(tailscale_bin=tailscale_bin)
        self.summary = SummaryWidget(id="summary")
        self.table = DataTable(id="peers")
        self.log = TextLog(id="log")

    def compose(self) -> ComposeResult:  # pragma: no cover - UI composition
        yield Header()
        with Container(id="body"):
            with Vertical(id="sidebar"):
                yield Static("Tailnet Peers", id="title")
                yield self.summary
                yield self.table
            yield self.log
        yield Footer()

    async def on_mount(self) -> None:  # pragma: no cover - UI lifecycle
        self.table.add_columns("Hostname", "User", "OS", "IP", "Last Seen")
        await self.refresh_status()
        self.set_interval(self.refresh_interval, self.refresh_status)

    async def action_refresh(self) -> None:  # pragma: no cover - key binding
        await self.refresh_status()

    async def refresh_status(self) -> None:
        try:
            status = await self.call_in_thread(self.api.status)
        except Exception as error:  # pragma: no cover - runtime error handling
            self.log.write_line(f"Failed to refresh status: {error}")
            return

        self.table.clear(columns=False)
        self.summary.total = len(status.peers)
        for peer_id, peer_data in sorted(status.peers.items()):
            hostname = str(peer_data.get("HostName", peer_id))
            user = str(peer_data.get("User", "?"))
            os_name = str(peer_data.get("OS", "?"))
            tailscale_ips = peer_data.get("TailscaleIPs") or []
            ip = ", ".join(tailscale_ips) if isinstance(tailscale_ips, list) else ""
            last_seen = str(peer_data.get("LastSeen", "?"))
            self.table.add_row(hostname, user, os_name, ip, last_seen)
        self.log.write_line("Status refreshed.")


def run(refresh_interval: float = 15.0, tailscale_bin: Optional[str] = None) -> None:
    app = TailnetMonitorApp(refresh_interval=refresh_interval, tailscale_bin=tailscale_bin)
    app.run()


def main(argv: Optional[list[str]] = None) -> None:
    parser = argparse.ArgumentParser(description="Tailnet Textual monitoring UI")
    parser.add_argument("--refresh-interval", type=float, default=15.0, help="Seconds between status refreshes")
    parser.add_argument("--tailscale-bin", type=str, default=None, help="Override path to the tailscale binary")
    args = parser.parse_args(argv)

    run(refresh_interval=args.refresh_interval, tailscale_bin=args.tailscale_bin)


if __name__ == "__main__":  # pragma: no cover - CLI entry
    main()
