#!/usr/bin/env python3
"""Mode switcher utility for the Armitage workstation.

This script toggles between productivity and gaming profiles by
coordinating the relevant systemd units.  It stores the last selected
mode locally so that user interfaces or monitoring agents can surface
the current state without querying systemd.
"""
from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path
from typing import Dict, List

STATE_FILE = Path.home() / ".local/share/armitage" / "mode_state.json"
DEFAULT_MODE = "productivity"

SYSTEMD_UNITS: Dict[str, Dict[str, List[str]]] = {
    "gaming": {
        "start": [
            "gaming-mode.target",
            "vllm-container@armitage.service",
        ],
        "stop": [
            "llm-idle.target",
        ],
    },
    "productivity": {
        "start": [
            "llm-idle.target",
        ],
        "stop": [
            "gaming-mode.target",
            "vllm-container@armitage.service",
        ],
    },
}


def _ensure_state_dir() -> None:
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)


def _store_state(mode: str) -> None:
    _ensure_state_dir()
    payload = {"mode": mode}
    STATE_FILE.write_text(json.dumps(payload, indent=2))


def _load_state() -> str:
    if STATE_FILE.exists():
        try:
            data = json.loads(STATE_FILE.read_text())
            mode = data.get("mode", DEFAULT_MODE)
            if mode in SYSTEMD_UNITS:
                return mode
        except json.JSONDecodeError:
            pass
    return DEFAULT_MODE


def _run_systemctl(action: str, unit: str) -> None:
    result = subprocess.run([
        "systemctl",
        action,
        unit,
    ], check=False, capture_output=True, text=True)
    if result.returncode != 0:
        message = result.stderr.strip() or result.stdout.strip()
        raise RuntimeError(f"systemctl {action} {unit} failed: {message}")


def set_mode(mode: str) -> str:
    """Apply the requested mode and persist the new state."""
    if mode not in SYSTEMD_UNITS:
        valid = ", ".join(SYSTEMD_UNITS)
        raise ValueError(f"Unknown mode '{mode}'. Valid modes: {valid}")

    definition = SYSTEMD_UNITS[mode]

    for unit in definition.get("stop", []):
        _run_systemctl("stop", unit)

    for unit in definition.get("start", []):
        _run_systemctl("start", unit)

    _store_state(mode)
    return mode


def print_status() -> str:
    mode = _load_state()
    print(mode)
    return mode


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Toggle Armitage system modes")
    subparsers = parser.add_subparsers(dest="command", required=True)

    switch_parser = subparsers.add_parser("switch", help="Switch to the specified mode")
    switch_parser.add_argument("mode", choices=sorted(SYSTEMD_UNITS.keys()))

    subparsers.add_parser("status", help="Print the last stored mode")

    return parser.parse_args()


def main() -> None:
    args = parse_args()

    if args.command == "status":
        print_status()
        return

    if args.command == "switch":
        new_mode = set_mode(args.mode)
        print(f"Switched to {new_mode}")
        return

    raise RuntimeError("Unsupported command")


if __name__ == "__main__":
    main()
