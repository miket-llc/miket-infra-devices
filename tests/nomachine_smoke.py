#!/usr/bin/env python3
"""
NoMachine connectivity smoke test.
Tests that NoMachine servers are reachable and responsive on port 4000.
Validates architectural compliance (RDP/VNC ports should NOT be listening).
"""

import os
import sys
import time
import socket
import subprocess
import csv
from typing import Dict, List, Tuple
from datetime import datetime

# Configuration
NOMACHINE_SERVERS = [
    {"name": "motoko", "host": "motoko.pangolin-vega.ts.net", "port": 4000, "os": "Linux"},
    {"name": "wintermute", "host": "wintermute.pangolin-vega.ts.net", "port": 4000, "os": "Windows"},
    {"name": "armitage", "host": "armitage.pangolin-vega.ts.net", "port": 4000, "os": "Windows"},
]

# Deprecated ports that should NOT be listening (architectural compliance)
DEPRECATED_PORTS = {
    "rdp": 3389,
    "vnc": 5900,
}


def test_port_connectivity(host: str, port: int, timeout: int = 5) -> Tuple[bool, float, str]:
    """
    Test if a port is reachable and responsive.
    Returns: (success, latency_ms, error_message)
    """
    start_time = time.time()
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        result = sock.connect_ex((host, port))
        latency_ms = (time.time() - start_time) * 1000
        sock.close()
        
        if result == 0:
            return (True, latency_ms, "")
        else:
            return (False, latency_ms, f"Connection refused (error code: {result})")
    except socket.gaierror as e:
        latency_ms = (time.time() - start_time) * 1000
        return (False, latency_ms, f"DNS resolution failed: {str(e)}")
    except socket.timeout:
        latency_ms = (time.time() - start_time) * 1000
        return (False, latency_ms, f"Connection timeout after {timeout}s")
    except Exception as e:
        latency_ms = (time.time() - start_time) * 1000
        return (False, latency_ms, f"Unexpected error: {str(e)}")


def test_deprecated_port_not_listening(host: str, port: int, protocol: str) -> Tuple[bool, str]:
    """
    Test that deprecated RDP/VNC ports are NOT listening (architectural compliance).
    Returns: (compliant, message)
    """
    success, latency, error = test_port_connectivity(host, port, timeout=2)
    
    if success:
        return (False, f"FAIL: {protocol.upper()} port {port} is listening (architectural violation)")
    else:
        # Port not listening is expected (good)
        if "Connection refused" in error or "timeout" in error.lower():
            return (True, f"PASS: {protocol.upper()} port {port} not listening (architectural compliance)")
        else:
            # DNS failure is acceptable (port still not listening)
            return (True, f"PASS: {protocol.upper()} port {port} not reachable (DNS may fail, but port not listening)")


def test_nomachine_server(server: Dict) -> Dict:
    """Test a single NoMachine server."""
    print(f"\nTesting {server['name']} ({server['os']})...")
    print(f"  Host: {server['host']}:{server['port']}")
    
    result = {
        "server_name": server["name"],
        "host": server["host"],
        "port": server["port"],
        "os": server["os"],
        "nomachine_reachable": False,
        "nomachine_latency_ms": None,
        "nomachine_error": "",
        "rdp_compliant": False,
        "rdp_message": "",
        "vnc_compliant": False,
        "vnc_message": "",
        "overall_status": "FAIL",
        "timestamp": datetime.now().isoformat(),
    }
    
    # Test NoMachine port 4000
    print("  Testing NoMachine connectivity...")
    success, latency, error = test_port_connectivity(server["host"], server["port"])
    result["nomachine_reachable"] = success
    result["nomachine_latency_ms"] = round(latency, 2)
    result["nomachine_error"] = error
    
    if success:
        print(f"  ✅ NoMachine reachable (latency: {latency:.2f}ms)")
    else:
        print(f"  ❌ NoMachine not reachable: {error}")
    
    # Test architectural compliance (RDP/VNC should NOT be listening)
    print("  Testing architectural compliance...")
    
    rdp_compliant, rdp_msg = test_deprecated_port_not_listening(
        server["host"], DEPRECATED_PORTS["rdp"], "rdp"
    )
    result["rdp_compliant"] = rdp_compliant
    result["rdp_message"] = rdp_msg
    print(f"  {'✅' if rdp_compliant else '❌'} RDP compliance: {rdp_msg}")
    
    vnc_compliant, vnc_msg = test_deprecated_port_not_listening(
        server["host"], DEPRECATED_PORTS["vnc"], "vnc"
    )
    result["vnc_compliant"] = vnc_compliant
    result["vnc_message"] = vnc_msg
    print(f"  {'✅' if vnc_compliant else '❌'} VNC compliance: {vnc_msg}")
    
    # Overall status
    if result["nomachine_reachable"] and result["rdp_compliant"] and result["vnc_compliant"]:
        result["overall_status"] = "PASS"
    else:
        result["overall_status"] = "FAIL"
    
    return result


def main():
    """Run all NoMachine smoke tests and generate report."""
    print("=" * 60)
    print("NoMachine Connectivity Smoke Test")
    print("=" * 60)
    print(f"Timestamp: {datetime.now().isoformat()}")
    print(f"Testing {len(NOMACHINE_SERVERS)} servers")
    print()
    
    results = []
    
    for server in NOMACHINE_SERVERS:
        result = test_nomachine_server(server)
        results.append(result)
    
    # Summary
    print("\n" + "=" * 60)
    print("Test Summary")
    print("=" * 60)
    
    passed = sum(1 for r in results if r["overall_status"] == "PASS")
    total = len(results)
    
    print(f"Overall: {passed}/{total} servers PASS")
    print()
    
    for result in results:
        status_icon = "✅" if result["overall_status"] == "PASS" else "❌"
        print(f"{status_icon} {result['server_name']} ({result['os']}): {result['overall_status']}")
        if result["nomachine_reachable"]:
            print(f"   NoMachine: Reachable ({result['nomachine_latency_ms']}ms)")
        else:
            print(f"   NoMachine: NOT reachable - {result['nomachine_error']}")
        print(f"   RDP compliance: {result['rdp_message']}")
        print(f"   VNC compliance: {result['vnc_message']}")
        print()
    
    # Write CSV report
    artifacts_dir = "artifacts"
    os.makedirs(artifacts_dir, exist_ok=True)
    csv_path = os.path.join(artifacts_dir, "nomachine_smoke_test_results.csv")
    
    with open(csv_path, "w", newline="") as f:
        fieldnames = [
            "timestamp", "server_name", "host", "port", "os",
            "nomachine_reachable", "nomachine_latency_ms", "nomachine_error",
            "rdp_compliant", "rdp_message",
            "vnc_compliant", "vnc_message",
            "overall_status"
        ]
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for r in results:
            writer.writerow(r)
    
    print(f"Results saved to: {csv_path}")
    
    # Exit with error if any test failed
    if passed < total:
        print("\n❌ Some tests failed. Review results above.")
        sys.exit(1)
    else:
        print("\n✅ All tests passed!")
        sys.exit(0)


if __name__ == "__main__":
    main()

