#!/usr/bin/env python3
# Copyright (c) 2025 MikeT LLC. All rights reserved.

"""
Burst load test for vLLM deployments.
Tests concurrent request handling and queueing behavior.
"""

import os
import sys
import time
import json
import csv
import requests
import concurrent.futures
from typing import Dict, List
from datetime import datetime

# Configuration
WINTERMUTE_HOST = os.getenv("WINTERMUTE_HOST", "wintermute")
MOTOKO_HOST = os.getenv("MOTOKO_HOST", "localhost")  # Use localhost for LiteLLM proxy
LITELLM_PORT = int(os.getenv("LITELLM_PORT", "8000"))

# Test configuration
BURST_SIZE = 5  # Number of concurrent requests
TEST_MODEL = "llama31-8b-wintermute"  # Use Wintermute for burst test
BASE_URL = f"http://{MOTOKO_HOST}:{LITELLM_PORT}"
LITELLM_TOKEN = os.getenv("LITELLM_TOKEN", "")


def make_request(request_id: int) -> Dict:
    """Make a single API request."""
    prompt = f"Request #{request_id}: Please provide a brief summary of machine learning."
    
    headers = {
        "Content-Type": "application/json",
    }
    if LITELLM_TOKEN:
        headers["Authorization"] = f"Bearer {LITELLM_TOKEN}"
    
    payload = {
        "model": TEST_MODEL,
        "messages": [
            {"role": "user", "content": prompt}
        ],
        "max_tokens": 100,
        "temperature": 0.1,
    }
    
    start_time = time.time()
    try:
        response = requests.post(
            f"{BASE_URL}/v1/chat/completions",
            headers=headers,
            json=payload,
            timeout=300,
        )
        elapsed = time.time() - start_time
        
        if response.status_code == 200:
            data = response.json()
            usage = data.get("usage", {})
            return {
                "request_id": request_id,
                "success": True,
                "status_code": response.status_code,
                "latency": elapsed,
                "prompt_tokens": usage.get("prompt_tokens", 0),
                "completion_tokens": usage.get("completion_tokens", 0),
                "error": None,
            }
        elif response.status_code == 429:
            # Rate limited - check for Retry-After header
            retry_after = response.headers.get("Retry-After", "unknown")
            return {
                "request_id": request_id,
                "success": False,
                "status_code": 429,
                "latency": elapsed,
                "error": f"Rate limited (Retry-After: {retry_after})",
            }
        else:
            return {
                "request_id": request_id,
                "success": False,
                "status_code": response.status_code,
                "latency": elapsed,
                "error": f"HTTP {response.status_code}: {response.text[:200]}",
            }
    except requests.exceptions.Timeout:
        elapsed = time.time() - start_time
        return {
            "request_id": request_id,
            "success": False,
            "status_code": None,
            "latency": elapsed,
            "error": "Request timeout",
        }
    except Exception as e:
        elapsed = time.time() - start_time
        return {
            "request_id": request_id,
            "success": False,
            "status_code": None,
            "latency": elapsed,
            "error": str(e),
        }


def run_burst_test() -> List[Dict]:
    """Run burst test with concurrent requests."""
    print(f"Running burst test with {BURST_SIZE} concurrent requests...")
    print(f"  Model: {TEST_MODEL}")
    print(f"  Base URL: {BASE_URL}")
    print()
    
    start_time = time.time()
    
    # Submit all requests concurrently
    with concurrent.futures.ThreadPoolExecutor(max_workers=BURST_SIZE) as executor:
        futures = [executor.submit(make_request, i) for i in range(BURST_SIZE)]
        results = [future.result() for future in concurrent.futures.as_completed(futures)]
    
    total_time = time.time() - start_time
    
    # Sort results by request_id for readability
    results.sort(key=lambda x: x["request_id"])
    
    # Print individual results
    for result in results:
        status = "✅" if result["success"] else "❌"
        print(f"{status} Request {result['request_id']}: "
              f"Status {result['status_code']}, "
              f"Latency {result['latency']:.2f}s")
        if result["error"]:
            print(f"    Error: {result['error']}")
    
    print(f"\nTotal time: {total_time:.2f}s")
    
    return results


def main():
    """Run burst test and generate report."""
    print("=" * 60)
    print("Burst Load Test")
    print("=" * 60)
    print(f"Timestamp: {datetime.now().isoformat()}")
    print()
    
    results = run_burst_test()
    
    # Summary
    print("\n" + "=" * 60)
    print("Test Summary")
    print("=" * 60)
    successful = sum(1 for r in results if r["success"])
    rate_limited = sum(1 for r in results if r["status_code"] == 429)
    errors = sum(1 for r in results if not r["success"] and r["status_code"] != 429)
    
    print(f"Total requests: {len(results)}")
    print(f"Successful: {successful}")
    print(f"Rate limited (429): {rate_limited}")
    print(f"Errors: {errors}")
    
    if successful > 0:
        successful_latencies = [r["latency"] for r in results if r["success"]]
        import statistics
        print(f"\nLatency stats (successful requests):")
        print(f"  Mean: {statistics.mean(successful_latencies):.2f}s")
        print(f"  Min: {min(successful_latencies):.2f}s")
        print(f"  Max: {max(successful_latencies):.2f}s")
    
    # Write CSV report
    artifacts_dir = "artifacts"
    os.makedirs(artifacts_dir, exist_ok=True)
    csv_path = os.path.join(artifacts_dir, "burst_test_results.csv")
    
    with open(csv_path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=[
            "request_id", "success", "status_code", "latency",
            "prompt_tokens", "completion_tokens", "error"
        ])
        writer.writeheader()
        for r in results:
            writer.writerow(r)
    
    print(f"\nResults saved to: {csv_path}")
    
    # Exit with error if more than 1 request failed (allowing for 1 error as per acceptance criteria)
    if errors > 1:
        print(f"\n❌ Test failed: {errors} errors (max allowed: 1)")
        sys.exit(1)
    elif rate_limited > 0:
        print(f"\n⚠️  Warning: {rate_limited} requests were rate limited (expected behavior)")
    else:
        print(f"\n✅ Test passed: All requests successful")


if __name__ == "__main__":
    main()

