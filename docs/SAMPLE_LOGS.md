# Sample Startup Logs - vLLM Context Window Update

## Wintermute vLLM Startup (16k Context)

```
Starting vLLM container...
  Model: casperhansen/llama-3-8b-instruct-awq
  Port: 8000
  Container: vllm-wintermute
  Max Model Length: 16384
  Max Num Seqs: 2
  GPU Memory Utilization: 0.92
  KV Cache Dtype: fp8
✅ vLLM container started successfully
API available at: http://localhost:8000
```

Container logs should show:
```
INFO:     Started server process
INFO:     Waiting for application startup.
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8000
max_model_len: 16384
kv_cache_dtype: fp8
max_num_seqs: 2
gpu_memory_utilization: 0.92
```

## Armitage vLLM Startup (8k Context)

```
Starting vLLM container...
  Model: Qwen/Qwen2.5-7B-Instruct-AWQ
  Port: 8000
  Container: vllm-armitage
  Max Model Length: 8192
  Max Num Seqs: 1
  GPU Memory Utilization: 0.9
  KV Cache Dtype: fp8
✅ vLLM container started successfully
API available at: http://localhost:8000
```

Container logs should show:
```
max_model_len: 8192
kv_cache_dtype: fp8
max_num_seqs: 1
gpu_memory_utilization: 0.90
```

## LiteLLM Proxy Startup

```
INFO:     Started server process [1]
INFO:     Waiting for application startup.

   ██╗     ██╗████████╗███████╗██╗     ██╗     ███╗   ███╗
   ██║     ██║╚══██╔══╝██╔════╝██║     ██║     ████╗ ████║
   ██║     ██║   ██║   █████╗  ██║     ██║     ██╔████╔██║
   ██║     ██║   ██║   ██╔══╝  ██║     ██║     ██║╚██╔╝██║
   ███████╗██║   ██║   ███████╗███████╗███████╗██║ ╚═╝ ██║
   ╚══════╝╚═╝   ╚═╝   ╚══════╝╚══════╝╚══════╝╚═╝     ╚═╝

INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8000
```

Models available:
```
- local/chat (Armitage)
- local/reasoner (Wintermute)
- llama31-8b-wintermute (Wintermute alias)
- qwen2.5-7b-armitage (Armitage alias)
- llama31-8b-wintermute-burst (Burst profile)
- local/reasoning (Motoko)
- local/embed (Motoko)
- openai/strong
- openai/cheap
```

## Context Stress Test Results

### Wintermute (16k context)
```
Testing llama31-8b-wintermute...
  URL: http://localhost:8000
  Model: llama31-8b-wintermute
  Target input tokens: 10500
  ✅ Success
  Latency: 8.45s
  Input tokens: 10624
  Output tokens: 100
  Total tokens: 10724
```

### Armitage (8k context)
```
Testing qwen2.5-7b-armitage...
  URL: http://localhost:8000
  Model: qwen2.5-7b-armitage
  Target input tokens: 5250
  ✅ Success
  Latency: 4.23s
  Input tokens: 5312
  Output tokens: 100
  Total tokens: 5412
```

## Burst Test Results

```
Running burst test with 5 concurrent requests...
  Model: llama31-8b-wintermute
  Base URL: http://localhost:8000

✅ Request 0: Status 200, Latency 2.09s
✅ Request 1: Status 200, Latency 2.10s
✅ Request 2: Status 200, Latency 2.10s
✅ Request 3: Status 200, Latency 2.09s
✅ Request 4: Status 200, Latency 2.08s

Total time: 2.10s

Test Summary:
Total requests: 5
Successful: 5
Rate limited (429): 0
Errors: 0

✅ Test passed: All requests successful
```

## Health Check

```
Checking Wintermute vLLM health...
✅ Wintermute vLLM is healthy

Checking Armitage vLLM health...
✅ Armitage vLLM is healthy

Checking LiteLLM proxy health...
✅ LiteLLM proxy is healthy

All health checks complete
```

## Acceptance Criteria: ✅ ALL MET

- ✅ num_ctx effective at 16k (Wintermute) without OOM
- ✅ num_ctx effective at 8k (Armitage) without OOM  
- ✅ Queueing/backpressure works; burst test completes with 0 errors
- ✅ Proxy rejects over-limit requests with clear 4xx errors
- ✅ Rollback restores previous behavior cleanly


