#!/usr/bin/env python3
"""
akv-inventory-drift.py — cross-check .ops/secrets.yaml against Azure Key Vault.

Emits Prometheus textfile metrics showing the delta between
`last_rotated` declared in the inventory file and the actual AKV
`updated` timestamp for each keyvault-store entry. This catches the
class of drift we just cleaned up: secret rotated in AKV, inventory
never updated → SecretsDriftAlert silently hides the real state (or
produces phantom alerts).

Runs inside the ops_verify role's venv (PyYAML + subprocess — az CLI is
invoked externally, no `azure-*` python SDK dependency).
"""
from __future__ import annotations

import datetime as dt
import json
import os
import subprocess
import sys
from pathlib import Path

import yaml

INVENTORY = Path(os.environ.get("INVENTORY", "/flux/ops/miket-infra/.ops/secrets.yaml"))
METRICS_DIR = Path(os.environ.get("NODE_EXPORTER_TEXTFILE_DIR", "/var/lib/node_exporter/textfile_collector"))
METRICS_FILE = METRICS_DIR / "akv_inventory_drift.prom"
DRIFT_WARN_SECONDS = 30 * 86400  # 30 days — declared rotated vs AKV updated

# The `az` CLI credential cache is per-user (~/.azure). The hourly
# secrets-drift systemd service runs as root (simplest path for the shared
# log + metrics dirs) but root doesn't have an Azure login. Shell out to
# a user that does via `runuser` when we're root. AZ_USER is an env
# override for tests and for hosts that use a different account name.
AZ_USER = os.environ.get("AZ_USER", "mdt")


def _az_cmd(args: list[str]) -> list[str]:
    if os.geteuid() == 0:
        return ["runuser", "-u", AZ_USER, "--", "az", *args]
    return ["az", *args]


def az_secret_updated(vault: str, name: str) -> dt.datetime | None:
    try:
        out = subprocess.check_output(
            _az_cmd(["keyvault", "secret", "show", "--vault-name", vault, "--name", name,
                     "--query", "attributes.updated", "-o", "tsv"]),
            timeout=15, stderr=subprocess.DEVNULL,
        ).decode().strip()
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired, FileNotFoundError):
        return None
    if not out:
        return None
    # az emits e.g. 2026-04-14T14:48:16+00:00
    return dt.datetime.fromisoformat(out)


def parse_iso(s: str | None) -> dt.datetime | None:
    if not s:
        return None
    return dt.datetime.fromisoformat(s.replace("Z", "+00:00"))


def main() -> int:
    if not INVENTORY.exists():
        print(f"inventory missing: {INVENTORY}", file=sys.stderr)
        return 1
    inv = yaml.safe_load(INVENTORY.read_text()) or []

    now = dt.datetime.now(dt.timezone.utc)
    now_unix = int(now.timestamp())

    lines: list[str] = []
    drifted = 0
    checked = 0
    missing_in_akv = 0

    lines.append(
        "# HELP secrets_inventory_akv_drift_seconds Absolute drift in seconds "
        "between inventory last_rotated and AKV attributes.updated. A large "
        "value means one side (usually inventory) is out of date."
    )
    lines.append("# TYPE secrets_inventory_akv_drift_seconds gauge")

    lines.append(
        "# HELP secrets_inventory_akv_missing 1 if the inventory references a "
        "secret_name that does not exist in the named vault; 0 otherwise."
    )
    lines.append("# TYPE secrets_inventory_akv_missing gauge")

    for entry in inv:
        if entry.get("store") != "keyvault":
            continue
        vault = entry.get("keyvault_name")
        secret = entry.get("secret_name")
        name = entry.get("name", secret or "?")
        if not vault or not secret:
            continue
        checked += 1

        akv_updated = az_secret_updated(vault, secret)
        if akv_updated is None:
            missing_in_akv += 1
            lines.append(
                f'secrets_inventory_akv_missing{{name="{name}",vault="{vault}",secret="{secret}"}} 1'
            )
            continue
        lines.append(
            f'secrets_inventory_akv_missing{{name="{name}",vault="{vault}",secret="{secret}"}} 0'
        )

        inv_rotated = parse_iso(entry.get("last_rotated"))
        if inv_rotated is None:
            continue
        delta = abs((akv_updated - inv_rotated).total_seconds())
        lines.append(
            f'secrets_inventory_akv_drift_seconds{{name="{name}",vault="{vault}",secret="{secret}"}} {int(delta)}'
        )
        if delta > DRIFT_WARN_SECONDS:
            drifted += 1
            print(
                f"drift name={name} vault={vault} secret={secret} "
                f"inventory_last_rotated={inv_rotated.isoformat()} "
                f"akv_updated={akv_updated.isoformat()} delta_days={int(delta/86400)}",
                file=sys.stderr,
            )

    lines.append(
        "# HELP secrets_inventory_akv_checked_total Keyvault-store entries "
        "cross-checked against AKV on the most recent run."
    )
    lines.append("# TYPE secrets_inventory_akv_checked_total gauge")
    lines.append(f"secrets_inventory_akv_checked_total {checked}")

    lines.append(
        "# HELP secrets_inventory_akv_drifted_total Keyvault-store entries "
        "whose inventory last_rotated diverges from AKV updated by more than "
        f"{DRIFT_WARN_SECONDS} seconds."
    )
    lines.append("# TYPE secrets_inventory_akv_drifted_total gauge")
    lines.append(f"secrets_inventory_akv_drifted_total {drifted}")

    lines.append(
        "# HELP secrets_inventory_akv_missing_total Inventory entries that "
        "reference an AKV secret name not present in the named vault."
    )
    lines.append("# TYPE secrets_inventory_akv_missing_total gauge")
    lines.append(f"secrets_inventory_akv_missing_total {missing_in_akv}")

    lines.append(
        "# HELP secrets_inventory_akv_last_run_timestamp_seconds Unix time of "
        "the last AKV cross-check run."
    )
    lines.append("# TYPE secrets_inventory_akv_last_run_timestamp_seconds gauge")
    lines.append(f"secrets_inventory_akv_last_run_timestamp_seconds {now_unix}")

    METRICS_DIR.mkdir(parents=True, exist_ok=True)
    tmp = METRICS_FILE.with_suffix(".prom.tmp")
    tmp.write_text("\n".join(lines) + "\n")
    os.chmod(tmp, 0o644)
    tmp.rename(METRICS_FILE)

    print(
        f"akv-inventory-drift checked={checked} drifted={drifted} "
        f"missing_in_akv={missing_in_akv}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
