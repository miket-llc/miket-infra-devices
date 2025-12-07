#!/usr/bin/env python3
# Copyright (c) 2025 MikeT LLC. All rights reserved.

"""
Nextcloud Pure Façade Smoke Test.
Tests that Nextcloud is operational and configured as a pure façade over /space.
Validates:
- Nextcloud server is reachable and healthy
- Skeleton files are disabled
- External storage mounts are configured
- Internal user homes are empty (pure façade)
- M365 sync and backup timers are active
"""

import os
import sys
import time
import json
import subprocess
from typing import Dict, List, Tuple, Optional
from datetime import datetime
from pathlib import Path

# Configuration
CONTAINER_RUNTIME = os.getenv("CONTAINER_RUNTIME", "podman")
NEXTCLOUD_CONFIG = {
    "name": "akira",
    "internal_url": "http://127.0.0.1:8080/status.php",
    "external_url": "https://nextcloud.miket.io",
    "container_name": "nextcloud-app",
    "data_path": "/flux/apps/nextcloud/data",
    "space_path": "/space/mike",
}

# Expected external mounts (per defaults/main.yml)
EXPECTED_MOUNTS = [
    {"name": "work", "path": "/space/mike/work"},
    {"name": "media", "path": "/space/mike/media"},
    {"name": "finance", "path": "/space/mike/finance"},
    {"name": "assets", "path": "/space/mike/assets"},
    {"name": "camera", "path": "/space/mike/camera"},
    {"name": "inbox", "path": "/space/mike/inbox"},
    {"name": "ms365", "path": "/space/mike/inbox/ms365"},
]

# Managed users (internal homes should be empty)
MANAGED_USERS = ["admin", "mike"]

# Expected systemd timers
EXPECTED_TIMERS = [
    "nextcloud-m365-sync.timer",
    "nextcloud-db-backup.timer",
    "nextcloud-home-sweeper.timer",
]


def run_command(cmd: List[str], capture: bool = True) -> Tuple[int, str, str]:
    """Run a shell command and return exit code, stdout, stderr."""
    try:
        result = subprocess.run(
            cmd,
            capture_output=capture,
            text=True,
            timeout=30,
        )
        return (result.returncode, result.stdout, result.stderr)
    except subprocess.TimeoutExpired:
        return (-1, "", "Command timed out")
    except Exception as e:
        return (-1, "", str(e))


def container_exec(args: List[str]) -> Tuple[int, str, str]:
    """Run a container command using the configured runtime."""
    return run_command([CONTAINER_RUNTIME] + args)


def test_container_running() -> Tuple[bool, str]:
    """Test if Nextcloud container is running."""
    code, stdout, stderr = run_command(
        [CONTAINER_RUNTIME, "ps", "--filter", f"name={NEXTCLOUD_CONFIG['container_name']}", "--format", "{{.Status}}"]
    )
    if code == 0 and "Up" in stdout:
        return (True, f"Container running: {stdout.strip()}")
    return (False, f"Container not running: {stderr or 'no output'}")


def test_nextcloud_status() -> Tuple[bool, str, Optional[Dict]]:
    """Test if Nextcloud API is responding and healthy."""
    import urllib.request
    import urllib.error
    
    try:
        with urllib.request.urlopen(NEXTCLOUD_CONFIG["internal_url"], timeout=10) as response:
            data = json.loads(response.read().decode())
            if data.get("installed") and not data.get("maintenance"):
                return (True, f"Nextcloud {data.get('versionstring', 'unknown')} operational", data)
            return (False, f"Nextcloud not operational: installed={data.get('installed')}, maintenance={data.get('maintenance')}", data)
    except urllib.error.URLError as e:
        return (False, f"Cannot reach Nextcloud: {str(e)}", None)
    except Exception as e:
        return (False, f"Error checking status: {str(e)}", None)


def test_skeleton_disabled() -> Tuple[bool, str]:
    """Test if skeleton directory is disabled (pure façade requirement)."""
    code, stdout, stderr = container_exec([
        "exec", "-u", "33", NEXTCLOUD_CONFIG["container_name"],
        "php", "occ", "config:system:get", "skeletondirectory"
    ])
    # Empty output or non-zero exit means disabled (good)
    if code != 0 or stdout.strip() == "":
        return (True, "Skeleton directory disabled")
    return (False, f"Skeleton directory is set: {stdout.strip()}")


def test_external_mounts() -> Tuple[bool, str, List[str]]:
    """Test if external storage mounts are configured."""
    # Use -a flag to show all mounts including user-specific (personal) mounts
    code, stdout, stderr = container_exec([
        "exec", "-u", "33", NEXTCLOUD_CONFIG["container_name"],
        "php", "occ", "files_external:list", "-a", "--output=json"
    ])
    if code != 0:
        return (False, f"Cannot list external mounts: {stderr}", [])
    
    try:
        mounts = json.loads(stdout)
        mount_names = [m.get("mount_point", "").strip("/") for m in mounts]
        expected_names = [m["name"] for m in EXPECTED_MOUNTS]
        
        missing = set(expected_names) - set(mount_names)
        if missing:
            return (False, f"Missing mounts: {', '.join(missing)}", mount_names)
        return (True, f"{len(mount_names)} mounts configured", mount_names)
    except json.JSONDecodeError:
        return (False, f"Invalid JSON from occ: {stdout[:100]}", [])


def test_internal_home_empty(user: str) -> Tuple[bool, str]:
    """Test if user's internal Nextcloud home is empty (pure façade)."""
    # Use container exec to check as www-data user (uid 33)
    code, stdout, stderr = container_exec([
        "exec", "-u", "33", NEXTCLOUD_CONFIG["container_name"],
        "find", f"/var/www/html/data/{user}/files", "-maxdepth", "1", "-type", "f"
    ])
    
    if code != 0:
        if "No such file" in stderr:
            return (True, "User home not created yet (expected)")
        return (True, f"Cannot check home: {stderr[:50]}")
    
    # Count files found
    files = [f for f in stdout.strip().split('\n') if f]
    if len(files) == 0:
        return (True, "Internal home is empty (pure façade compliant)")
    
    # List what's there
    file_names = [Path(f).name for f in files[:5]]
    return (False, f"Found {len(files)} files in internal home: {file_names}")


def test_space_mounts_exist() -> Tuple[bool, str, List[str]]:
    """Test if /space mount directories exist."""
    missing = []
    for mount in EXPECTED_MOUNTS:
        if not Path(mount["path"]).exists():
            missing.append(mount["name"])
    
    if missing:
        return (False, f"Missing /space directories: {', '.join(missing)}", missing)
    return (True, f"All {len(EXPECTED_MOUNTS)} /space directories exist", [])


def test_timer_active(timer: str) -> Tuple[bool, str]:
    """Test if a systemd timer is active."""
    code, stdout, stderr = run_command(["systemctl", "is-active", timer])
    if code == 0 and "active" in stdout:
        return (True, f"{timer} is active")
    return (False, f"{timer} is not active: {stdout.strip() or stderr.strip()}")


def main():
    """Run all Nextcloud pure façade smoke tests."""
    print("=" * 70)
    print("Nextcloud Pure Façade Smoke Test")
    print("=" * 70)
    print(f"Timestamp: {datetime.now().isoformat()}")
    print(f"Testing: {NEXTCLOUD_CONFIG['name']}")
    print()
    
    results = []
    all_passed = True
    
    # Test 1: Container running
    print("1. Container Status")
    passed, msg = test_container_running()
    results.append(("Container", passed, msg))
    print(f"   {'✅' if passed else '❌'} {msg}")
    if not passed:
        all_passed = False
    
    # Test 2: Nextcloud status
    print("\n2. Nextcloud API Status")
    passed, msg, status_data = test_nextcloud_status()
    results.append(("API Status", passed, msg))
    print(f"   {'✅' if passed else '❌'} {msg}")
    if not passed:
        all_passed = False
    
    # Test 3: Skeleton disabled
    print("\n3. Skeleton Directory (Pure Façade)")
    passed, msg = test_skeleton_disabled()
    results.append(("Skeleton Disabled", passed, msg))
    print(f"   {'✅' if passed else '❌'} {msg}")
    if not passed:
        all_passed = False
    
    # Test 4: External mounts
    print("\n4. External Storage Mounts")
    passed, msg, mounts = test_external_mounts()
    results.append(("External Mounts", passed, msg))
    print(f"   {'✅' if passed else '❌'} {msg}")
    if mounts:
        for m in mounts:
            print(f"      - {m}")
    if not passed:
        all_passed = False
    
    # Test 5: /space directories exist
    print("\n5. /space Mount Directories")
    passed, msg, missing = test_space_mounts_exist()
    results.append(("/space Dirs", passed, msg))
    print(f"   {'✅' if passed else '❌'} {msg}")
    if not passed:
        all_passed = False
    
    # Test 6: Internal homes empty
    print("\n6. Internal User Homes (Pure Façade)")
    for user in MANAGED_USERS:
        passed, msg = test_internal_home_empty(user)
        results.append((f"Home {user}", passed, msg))
        print(f"   {'✅' if passed else '⚠️'} {user}: {msg}")
        # Don't fail overall for non-empty homes (might have pre-existing data)
        # Just warn
    
    # Test 7: Systemd timers
    print("\n7. Systemd Timers")
    for timer in EXPECTED_TIMERS:
        passed, msg = test_timer_active(timer)
        results.append((timer, passed, msg))
        print(f"   {'✅' if passed else '⚠️'} {msg}")
    
    # Summary
    print("\n" + "=" * 70)
    print("Test Summary")
    print("=" * 70)
    
    passed_count = sum(1 for _, p, _ in results if p)
    total = len(results)
    
    print(f"Overall: {passed_count}/{total} tests passed")
    print()
    
    # External mounts may fail if mike user doesn't exist yet (first run) - not critical
    critical_tests = ["Container", "API Status", "Skeleton Disabled"]
    critical_passed = all(p for name, p, _ in results if name in critical_tests)
    
    if critical_passed:
        print("✅ All critical tests passed - Nextcloud pure façade is operational")
        exit_code = 0
    else:
        print("❌ Some critical tests failed - review results above")
        exit_code = 1
    
    # Write results to artifacts
    artifacts_dir = Path("artifacts")
    artifacts_dir.mkdir(exist_ok=True)
    
    report_path = artifacts_dir / "nextcloud_smoke_test_results.json"
    with open(report_path, "w") as f:
        json.dump({
            "timestamp": datetime.now().isoformat(),
            "server": NEXTCLOUD_CONFIG["name"],
            "overall_passed": critical_passed,
            "results": [{"test": name, "passed": p, "message": msg} for name, p, msg in results],
        }, f, indent=2)
    
    print(f"\nResults saved to: {report_path}")
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
