#!/usr/bin/env python3
# Copyright (c) 2025 MikeT LLC. All rights reserved.
"""
AI Fabric Smoke Test
Tests end-to-end functionality of the distributed AI fabric through litellm proxy
Tests all logical roles: chat-fast, chat-deep, embeddings-general
"""

import sys
import time
import json
import os
from typing import Dict, Any, List
import requests

# Configuration
LITELLM_URL = os.getenv("LITELLM_URL", "http://127.0.0.1:8000")
LITELLM_TOKEN = os.getenv("LITELLM_TOKEN", "")

# Test cases for each logical role
TEST_CASES = [
    {
        "name": "chat-fast: Quick response test",
        "model": "chat-fast",
        "type": "chat",
        "messages": [{"role": "user", "content": "Say 'hello' in one word"}],
        "max_tokens": 10,
        "expected_backend": "armitage"
    },
    {
        "name": "chat-deep: Reasoning test",
        "model": "chat-deep",
        "type": "chat",
        "messages": [{"role": "user", "content": "What is 2+2? Answer with just the number."}],
        "max_tokens": 5,
        "expected_backend": "wintermute"
    },
    {
        "name": "embeddings-general: Vector generation",
        "model": "embeddings-general",
        "type": "embedding",
        "input": "This is a test sentence for embeddings",
        "expected_backend": "motoko"
    },
    {
        "name": "Legacy alias: local/chat",
        "model": "local/chat",
        "type": "chat",
        "messages": [{"role": "user", "content": "Hi"}],
        "max_tokens": 5,
        "expected_backend": "armitage"
    },
    {
        "name": "Legacy alias: local/embed",
        "model": "local/embed",
        "type": "embedding",
        "input": "Test embedding",
        "expected_backend": "motoko"
    },
]

class Colors:
    GREEN = '\033[0;32m'
    RED = '\033[0;31m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'  # No Color

def print_header(text: str):
    print(f"\n{Colors.BLUE}{'='*70}{Colors.NC}")
    print(f"{Colors.BLUE}{text:^70}{Colors.NC}")
    print(f"{Colors.BLUE}{'='*70}{Colors.NC}\n")

def print_test(name: str):
    print(f"{Colors.YELLOW}▶ {name}{Colors.NC}")

def print_success(message: str):
    print(f"  {Colors.GREEN}✓ {message}{Colors.NC}")

def print_error(message: str):
    print(f"  {Colors.RED}✗ {message}{Colors.NC}")

def print_warning(message: str):
    print(f"  {Colors.YELLOW}⚠ {message}{Colors.NC}")

def test_litellm_connection() -> bool:
    """Test basic connectivity to litellm proxy"""
    print_test("Testing LiteLLM proxy connectivity")
    
    try:
        headers = {"Authorization": f"Bearer {LITELLM_TOKEN}"} if LITELLM_TOKEN else {}
        response = requests.get(f"{LITELLM_URL}/v1/models", headers=headers, timeout=5)
        
        if response.status_code == 200:
            models = response.json().get("data", [])
            print_success(f"Connected to LiteLLM proxy - {len(models)} models available")
            return True
        elif response.status_code == 401:
            print_error("Authentication failed - check LITELLM_TOKEN environment variable")
            return False
        else:
            print_error(f"Unexpected status code: {response.status_code}")
            return False
    except Exception as e:
        print_error(f"Connection failed: {str(e)}")
        return False

def test_chat_completion(test: Dict[str, Any]) -> Dict[str, Any]:
    """Test chat completion endpoint"""
    start_time = time.time()
    result = {
        "success": False,
        "latency_ms": 0,
        "error": None,
        "response_preview": None
    }
    
    try:
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {LITELLM_TOKEN}"
        } if LITELLM_TOKEN else {"Content-Type": "application/json"}
        
        payload = {
            "model": test["model"],
            "messages": test["messages"],
            "max_tokens": test.get("max_tokens", 50)
        }
        
        response = requests.post(
            f"{LITELLM_URL}/v1/chat/completions",
            headers=headers,
            json=payload,
            timeout=30
        )
        
        latency = int((time.time() - start_time) * 1000)
        result["latency_ms"] = latency
        
        if response.status_code == 200:
            data = response.json()
            content = data["choices"][0]["message"]["content"]
            result["success"] = True
            result["response_preview"] = content[:100]
            print_success(f"Response received in {latency}ms")
            print(f"    Preview: {content[:80]}...")
        else:
            result["error"] = f"HTTP {response.status_code}: {response.text[:200]}"
            print_error(result["error"])
    
    except Exception as e:
        result["error"] = str(e)
        print_error(f"Request failed: {str(e)}")
    
    return result

def test_embedding(test: Dict[str, Any]) -> Dict[str, Any]:
    """Test embeddings endpoint"""
    start_time = time.time()
    result = {
        "success": False,
        "latency_ms": 0,
        "error": None,
        "vector_dimensions": None
    }
    
    try:
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {LITELLM_TOKEN}"
        } if LITELLM_TOKEN else {"Content-Type": "application/json"}
        
        payload = {
            "model": test["model"],
            "input": test["input"]
        }
        
        response = requests.post(
            f"{LITELLM_URL}/v1/embeddings",
            headers=headers,
            json=payload,
            timeout=30
        )
        
        latency = int((time.time() - start_time) * 1000)
        result["latency_ms"] = latency
        
        if response.status_code == 200:
            data = response.json()
            embedding = data["data"][0]["embedding"]
            result["success"] = True
            result["vector_dimensions"] = len(embedding)
            print_success(f"Embedding generated in {latency}ms ({len(embedding)} dimensions)")
        else:
            result["error"] = f"HTTP {response.status_code}: {response.text[:200]}"
            print_error(result["error"])
    
    except Exception as e:
        result["error"] = str(e)
        print_error(f"Request failed: {str(e)}")
    
    return result

def run_smoke_tests() -> bool:
    """Run all smoke tests"""
    print_header("AI Fabric Smoke Test Suite")
    
    # Check connectivity first
    if not test_litellm_connection():
        return False
    
    results = []
    passed = 0
    failed = 0
    skipped = 0
    
    print_header("Running Logical Role Tests")
    
    for test in TEST_CASES:
        print_test(test["name"])
        print(f"    Model: {test['model']}")
        print(f"    Expected backend: {test.get('expected_backend', 'any')}")
        
        if test["type"] == "chat":
            result = test_chat_completion(test)
        elif test["type"] == "embedding":
            result = test_embedding(test)
        else:
            print_warning(f"Unknown test type: {test['type']}")
            skipped += 1
            continue
        
        results.append({
            "test": test["name"],
            "model": test["model"],
            **result
        })
        
        if result["success"]:
            passed += 1
        else:
            failed += 1
            if "offline" in result.get("error", "").lower() or "connection" in result.get("error", "").lower():
                print_warning(f"Backend {test.get('expected_backend')} may be offline - this is expected for workstations")
        
        print()
    
    # Summary
    print_header("Test Summary")
    total = passed + failed
    print(f"Total tests: {total}")
    print(f"{Colors.GREEN}Passed: {passed}{Colors.NC}")
    print(f"{Colors.RED}Failed: {failed}{Colors.NC}")
    if skipped > 0:
        print(f"{Colors.YELLOW}Skipped: {skipped}{Colors.NC}")
    
    # Detailed results
    if results:
        print("\nDetailed Results:")
        for r in results:
            status = f"{Colors.GREEN}PASS{Colors.NC}" if r["success"] else f"{Colors.RED}FAIL{Colors.NC}"
            print(f"  [{status}] {r['test']} - {r['latency_ms']}ms")
            if not r["success"] and r.get("error"):
                print(f"         Error: {r['error']}")
    
    # Recommendations
    if failed > 0:
        print(f"\n{Colors.YELLOW}Recommendations:{Colors.NC}")
        print("  • Check that backend vLLM services are running (use health check script)")
        print("  • Windows workstations (wintermute/armitage) may be powered off")
        print("  • Run: scripts/health/check_vllm_backends.sh to diagnose")
    
    return failed == 0

if __name__ == "__main__":
    # Load token from env file if not set
    if not LITELLM_TOKEN:
        try:
            with open("/podman/apps/litellm/.env", "r") as f:
                for line in f:
                    if line.startswith("LITELLM_TOKEN="):
                        LITELLM_TOKEN = line.split("=", 1)[1].strip()
                        break
        except:
            pass
    
    success = run_smoke_tests()
    sys.exit(0 if success else 1)

