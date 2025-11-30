#!/usr/bin/env python3
"""
Motoko AI Profile Load Test
Tests embedding and classification services under load while monitoring thermals.

Usage:
    python load_test.py --duration 60 --rps 10

Requirements:
    pip install httpx asyncio
"""

import argparse
import asyncio
import json
import time
from dataclasses import dataclass
from typing import List, Optional
import subprocess

try:
    import httpx
except ImportError:
    print("Please install httpx: pip install httpx")
    exit(1)


@dataclass
class TestResult:
    service: str
    latency_ms: float
    success: bool
    error: Optional[str] = None


class LoadTester:
    def __init__(self, base_url: str = "http://127.0.0.1"):
        self.base_url = base_url
        self.results: List[TestResult] = []
        self.start_time = time.time()
        
    async def test_embedding_bge(self, client: httpx.AsyncClient) -> TestResult:
        """Test BGE embeddings via TEI."""
        start = time.time()
        try:
            response = await client.post(
                f"{self.base_url}:8201/embed",
                json={"inputs": "This is a test sentence for embedding."},
                timeout=30.0
            )
            latency = (time.time() - start) * 1000
            if response.status_code == 200:
                return TestResult("BGE Embed", latency, True)
            return TestResult("BGE Embed", latency, False, f"Status {response.status_code}")
        except Exception as e:
            return TestResult("BGE Embed", (time.time() - start) * 1000, False, str(e))
    
    async def test_embedding_arctic(self, client: httpx.AsyncClient) -> TestResult:
        """Test Arctic embeddings via TEI."""
        start = time.time()
        try:
            response = await client.post(
                f"{self.base_url}:8202/embed",
                json={"inputs": "This is a test sentence for embedding."},
                timeout=30.0
            )
            latency = (time.time() - start) * 1000
            if response.status_code == 200:
                return TestResult("Arctic Embed", latency, True)
            return TestResult("Arctic Embed", latency, False, f"Status {response.status_code}")
        except Exception as e:
            return TestResult("Arctic Embed", (time.time() - start) * 1000, False, str(e))
    
    async def test_classification(self, client: httpx.AsyncClient) -> TestResult:
        """Test zero-shot classification."""
        start = time.time()
        try:
            response = await client.post(
                f"{self.base_url}:8203/classify",
                json={
                    "input": "I absolutely love this product! It's amazing.",
                    "candidate_labels": ["positive", "negative", "neutral"],
                    "multi_label": False
                },
                timeout=30.0
            )
            latency = (time.time() - start) * 1000
            if response.status_code == 200:
                return TestResult("Classification", latency, True)
            return TestResult("Classification", latency, False, f"Status {response.status_code}")
        except Exception as e:
            return TestResult("Classification", (time.time() - start) * 1000, False, str(e))
    
    def get_gpu_stats(self) -> dict:
        """Get current GPU temperature and memory usage."""
        try:
            result = subprocess.run(
                ["nvidia-smi", "--query-gpu=temperature.gpu,memory.used,power.draw", 
                 "--format=csv,noheader,nounits"],
                capture_output=True, text=True, timeout=5
            )
            if result.returncode == 0:
                parts = result.stdout.strip().split(", ")
                return {
                    "temperature": int(parts[0]),
                    "memory_mb": int(parts[1]),
                    "power_w": float(parts[2])
                }
        except Exception:
            pass
        return {"temperature": -1, "memory_mb": -1, "power_w": -1}
    
    async def run_test_batch(self, client: httpx.AsyncClient):
        """Run one batch of tests (one of each type)."""
        tasks = [
            self.test_embedding_bge(client),
            self.test_embedding_arctic(client),
            self.test_classification(client),
        ]
        results = await asyncio.gather(*tasks)
        self.results.extend(results)
        return results
    
    async def run_load_test(self, duration_seconds: int, rps: float):
        """Run load test for specified duration."""
        print(f"Starting load test: {duration_seconds}s duration, {rps} RPS target")
        print("=" * 60)
        
        interval = 1.0 / rps if rps > 0 else 1.0
        end_time = time.time() + duration_seconds
        
        gpu_samples = []
        
        async with httpx.AsyncClient() as client:
            while time.time() < end_time:
                batch_start = time.time()
                
                # Run test batch
                results = await self.run_test_batch(client)
                
                # Get GPU stats
                gpu_stats = self.get_gpu_stats()
                gpu_samples.append(gpu_stats)
                
                # Print progress
                elapsed = time.time() - self.start_time
                success_count = sum(1 for r in results if r.success)
                avg_latency = sum(r.latency_ms for r in results) / len(results)
                
                print(f"[{elapsed:6.1f}s] GPU: {gpu_stats['temperature']}°C, "
                      f"{gpu_stats['power_w']:.1f}W | "
                      f"Latency: {avg_latency:.0f}ms | "
                      f"Success: {success_count}/{len(results)}")
                
                # Wait for next batch
                elapsed_batch = time.time() - batch_start
                if elapsed_batch < interval:
                    await asyncio.sleep(interval - elapsed_batch)
        
        self.print_summary(gpu_samples)
    
    def print_summary(self, gpu_samples: List[dict]):
        """Print test summary."""
        print("\n" + "=" * 60)
        print("LOAD TEST SUMMARY")
        print("=" * 60)
        
        # Group results by service
        services = {}
        for r in self.results:
            if r.service not in services:
                services[r.service] = []
            services[r.service].append(r)
        
        for service, results in services.items():
            latencies = [r.latency_ms for r in results if r.success]
            success_rate = sum(1 for r in results if r.success) / len(results) * 100
            
            if latencies:
                latencies.sort()
                p50 = latencies[len(latencies) // 2]
                p95 = latencies[int(len(latencies) * 0.95)]
                p99 = latencies[int(len(latencies) * 0.99)] if len(latencies) > 100 else latencies[-1]
                
                print(f"\n{service}:")
                print(f"  Requests:     {len(results)}")
                print(f"  Success Rate: {success_rate:.1f}%")
                print(f"  Latency P50:  {p50:.0f}ms")
                print(f"  Latency P95:  {p95:.0f}ms")
                print(f"  Latency P99:  {p99:.0f}ms")
            else:
                print(f"\n{service}:")
                print(f"  Requests:     {len(results)}")
                print(f"  Success Rate: 0% (all failed)")
        
        # GPU summary
        if gpu_samples:
            temps = [s["temperature"] for s in gpu_samples if s["temperature"] > 0]
            powers = [s["power_w"] for s in gpu_samples if s["power_w"] > 0]
            
            print(f"\nGPU Thermals:")
            if temps:
                print(f"  Temperature: {min(temps)}°C - {max(temps)}°C (avg: {sum(temps)/len(temps):.1f}°C)")
            if powers:
                print(f"  Power Draw:  {min(powers):.1f}W - {max(powers):.1f}W (avg: {sum(powers)/len(powers):.1f}W)")
        
        print("\n" + "=" * 60)


def main():
    parser = argparse.ArgumentParser(description="Motoko AI Profile Load Test")
    parser.add_argument("--duration", type=int, default=60, help="Test duration in seconds")
    parser.add_argument("--rps", type=float, default=5, help="Requests per second")
    parser.add_argument("--host", type=str, default="http://127.0.0.1", help="Base URL")
    args = parser.parse_args()
    
    tester = LoadTester(args.host)
    asyncio.run(tester.run_load_test(args.duration, args.rps))


if __name__ == "__main__":
    main()

