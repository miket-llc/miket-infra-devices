#!/usr/bin/env python3
# Copyright (c) 2025 MikeT LLC. All rights reserved.

"""
Context window smoke test for vLLM deployments.
Tests that models can handle requests near their max context limits without OOM.
"""

import os
import sys
import time
import json
import csv
import requests
import statistics
from typing import Dict, List, Tuple
from datetime import datetime

# Configuration
WINTERMUTE_HOST = os.getenv("WINTERMUTE_HOST", "wintermute")
ARMITAGE_HOST = os.getenv("ARMITAGE_HOST", "armitage")
MOTOKO_HOST = os.getenv("MOTOKO_HOST", "localhost")  # Use localhost for LiteLLM proxy
LITELLM_PORT = int(os.getenv("LITELLM_PORT", "8000"))
VLLM_PORT = int(os.getenv("VLLM_PORT", "8000"))

# Test configurations
TESTS = [
    {
        "name": "llama31-8b-wintermute",
        "base_url": f"http://{MOTOKO_HOST}:{LITELLM_PORT}",
        "model": "llama31-8b-wintermute",
        "max_input_tokens": 8000,  # Matches litellm config: wintermute_max_input_tokens
        "test_input_ratio": 0.75,  # Use 75% of max to avoid edge cases
        "max_output_tokens": 100,
    },
    {
        "name": "qwen2.5-7b-armitage",
        "base_url": f"http://{MOTOKO_HOST}:{LITELLM_PORT}",
        "model": "qwen2.5-7b-armitage",
        "max_input_tokens": 7000,
        "test_input_ratio": 0.75,
        "max_output_tokens": 100,
    },
    {
        "name": "wintermute-direct",
        "base_url": f"http://{WINTERMUTE_HOST}:{VLLM_PORT}",
        "model": "llama31-8b-wintermute",  # Use served_model_name
        "max_input_tokens": 8000,  # Matches vLLM max_model_len: 9000, but use 85% for safety
        "test_input_ratio": 0.75,
        "max_output_tokens": 100,
    },
    {
        "name": "armitage-direct",
        "base_url": f"http://{ARMITAGE_HOST}:{VLLM_PORT}",
        "model": "qwen2.5-7b-armitage",
        "max_input_tokens": 7000,
        "test_input_ratio": 0.75,
        "max_output_tokens": 100,
    },
]

# LiteLLM token (if required)
LITELLM_TOKEN = os.getenv("LITELLM_TOKEN", "")


def estimate_tokens(text: str) -> int:
    """Rough token estimation: ~4 chars per token."""
    return len(text) // 4


def generate_test_prompt(target_tokens: int) -> str:
    """Generate a test prompt that approximates the target token count."""
    # Base prompt
    base = "Please summarize the following text in detail:\n\n"
    # Fill text to reach target
    filler = "This is a test sentence. " * (target_tokens // 5)
    return base + filler


def test_model(test_config: Dict) -> Tuple[bool, Dict]:
    """Test a single model with a large context request."""
    print(f"\nTesting {test_config['name']}...")
    print(f"  URL: {test_config['base_url']}")
    print(f"  Model: {test_config['model']}")
    print(f"  Target input tokens: {int(test_config['max_input_tokens'] * test_config['test_input_ratio'])}")
    
    # Generate test prompt
    target_tokens = int(test_config['max_input_tokens'] * test_config['test_input_ratio'])
    prompt = generate_test_prompt(target_tokens)
    actual_tokens = estimate_tokens(prompt)
    
    # Prepare request
    headers = {
        "Content-Type": "application/json",
    }
    if LITELLM_TOKEN:
        headers["Authorization"] = f"Bearer {LITELLM_TOKEN}"
    
    payload = {
        "model": test_config["model"],
        "messages": [
            {"role": "user", "content": prompt}
        ],
        "max_tokens": test_config["max_output_tokens"],
        "temperature": 0.1,
    }
    
    # Make request and measure latency
    start_time = time.time()
    try:
        response = requests.post(
            f"{test_config['base_url']}/v1/chat/completions",
            headers=headers,
            json=payload,
            timeout=300,
        )
        elapsed = time.time() - start_time
        
        if response.status_code == 200:
            data = response.json()
            output_text = data.get("choices", [{}])[0].get("message", {}).get("content", "")
            output_tokens = len(output_text.split())  # Rough estimate
            
            # Extract usage if available
            usage = data.get("usage", {})
            prompt_tokens = usage.get("prompt_tokens", actual_tokens)
            completion_tokens = usage.get("completion_tokens", output_tokens)
            total_tokens = usage.get("total_tokens", prompt_tokens + completion_tokens)
            
            print(f"  ✅ Success")
            print(f"  Latency: {elapsed:.2f}s")
            print(f"  Input tokens: {prompt_tokens}")
            print(f"  Output tokens: {completion_tokens}")
            print(f"  Total tokens: {total_tokens}")
            
            return True, {
                "success": True,
                "latency": elapsed,
                "status_code": response.status_code,
                "prompt_tokens": prompt_tokens,
                "completion_tokens": completion_tokens,
                "total_tokens": total_tokens,
                "error": None,
            }
        else:
            error_msg = f"HTTP {response.status_code}: {response.text[:200]}"
            print(f"  ❌ Failed: {error_msg}")
            return False, {
                "success": False,
                "latency": elapsed,
                "status_code": response.status_code,
                "error": error_msg,
            }
    except requests.exceptions.Timeout:
        elapsed = time.time() - start_time
        print(f"  ❌ Timeout after {elapsed:.2f}s")
        return False, {
            "success": False,
            "latency": elapsed,
            "status_code": None,
            "error": "Request timeout",
        }
    except Exception as e:
        elapsed = time.time() - start_time
        print(f"  ❌ Error: {str(e)}")
        return False, {
            "success": False,
            "latency": elapsed,
            "status_code": None,
            "error": str(e),
        }


def main():
    """Run all context tests and generate report."""
    print("=" * 60)
    print("Context Window Smoke Test")
    print("=" * 60)
    print(f"Timestamp: {datetime.now().isoformat()}")
    print()
    
    results = []
    latencies = []
    
    for test_config in TESTS:
        success, result = test_model(test_config)
        result["test_name"] = test_config["name"]
        result["model"] = test_config["model"]
        result["max_input_tokens"] = test_config["max_input_tokens"]
        results.append(result)
        
        if success:
            latencies.append(result["latency"])
    
    # Summary
    print("\n" + "=" * 60)
    print("Test Summary")
    print("=" * 60)
    successful = sum(1 for r in results if r["success"])
    total = len(results)
    print(f"Successful: {successful}/{total}")
    
    if latencies:
        print(f"Latency stats:")
        print(f"  P50: {statistics.median(latencies):.2f}s")
        print(f"  P90: {statistics.quantiles(latencies, n=10)[8]:.2f}s" if len(latencies) >= 10 else f"  P90: N/A")
        print(f"  Mean: {statistics.mean(latencies):.2f}s")
        print(f"  Min: {min(latencies):.2f}s")
        print(f"  Max: {max(latencies):.2f}s")
    
    # Write CSV report
    artifacts_dir = "artifacts"
    os.makedirs(artifacts_dir, exist_ok=True)
    csv_path = os.path.join(artifacts_dir, "context_test_results.csv")
    
    with open(csv_path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=[
            "test_name", "model", "max_input_tokens", "success",
            "latency", "status_code", "prompt_tokens", "completion_tokens",
            "total_tokens", "error"
        ])
        writer.writeheader()
        for r in results:
            writer.writerow(r)
    
    print(f"\nResults saved to: {csv_path}")
    
    # Exit with error if any test failed
    if successful < total:
        sys.exit(1)


if __name__ == "__main__":
    main()

