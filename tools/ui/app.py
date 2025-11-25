# Copyright (c) 2025 MikeT LLC. All rights reserved.

"""Textual application for monitoring the workstation tailnet."""
from __future__ import annotations

import asyncio
from typing import Optional

from rich.text import Text
from textual.app import App, ComposeResult
from textual.containers import Container
from textual.widgets import Button, DataTable, Footer, Header, Static

from tools.cli import tailnet


class TailnetMonitorApp(App):
    """Simple Textual dashboard on top of the :mod:`tools.cli.tailnet` helpers."""

    CSS_PATH = None
    BINDINGS = [
        ("r", "refresh", "Refresh"),
        ("q", "quit", "Quit"),
    ]

    def __init__(self, *, refresh_interval: float = 30.0) -> None:
        super().__init__()
        self.refresh_interval = refresh_interval
        self._refresh_task: Optional[asyncio.Task[None]] = None

    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)
        yield Container(
            Static("Tailnet status", classes="title"),
            DataTable(id="status-table"),
            Button("Refresh", id="refresh"),
            Static("Messages will appear here.", id="status-message"),
        )
        yield Footer()

    async def on_mount(self) -> None:
        table = self._status_table
        table.add_columns("Hostname", "User", "Online", "IPs", "Tags")
        await self.refresh_status()
        if self.refresh_interval > 0:
            self._refresh_task = asyncio.create_task(self._refresh_loop())

    async def on_unmount(self) -> None:
        if self._refresh_task is not None:
            self._refresh_task.cancel()

    async def on_button_pressed(self, event: Button.Pressed) -> None:  # pragma: no cover - UI glue
        if event.button.id == "refresh":
            await self.refresh_status()

    async def action_refresh(self) -> None:
        await self.refresh_status()

    async def refresh_status(self) -> None:
        self._status_text.update(Text("Refreshing...", style="cyan"))
        devices = await asyncio.to_thread(tailnet.fetch_tailnet_status)

        table = self._status_table
        table.clear()

        if not devices:
            self._status_text.update(
                Text("No Tailscale status available. Ensure tailscale is installed.", style="yellow")
            )
            return

        for device in devices:
            table.add_row(
                device.hostname,
                device.user,
                "online" if device.online else "offline",
                ", ".join(device.ips) or "-",
                ", ".join(device.tags) or "-",
            )

        self._status_text.update(Text(f"Updated {len(devices)} devices", style="green"))

    async def _refresh_loop(self) -> None:
        try:
            while True:
                await asyncio.sleep(self.refresh_interval)
                await self.refresh_status()
        except asyncio.CancelledError:  # pragma: no cover - shutdown behaviour
            return

    @property
    def _status_table(self) -> DataTable:
        return self.query_one("#status-table", DataTable)

    @property
    def _status_text(self) -> Static:
        return self.query_one("#status-message", Static)


if __name__ == "__main__":  # pragma: no cover
    TailnetMonitorApp().run()
