# Monitoring vLLM on Wintermute

## Quick Status Check

```bash
# Check container status
cd ~/miket-infra-devices
./devices/wintermute/scripts/vllm.sh status

# Or directly:
docker ps --filter name=vllm-wintermute
```

## Check API Health

```bash
# Health endpoint
curl http://localhost:8000/health

# List available models
curl http://localhost:8000/v1/models

# Test from another Tailnet node
curl http://wintermute.pangolin-vega.ts.net:8000/v1/models
```

## Monitor Logs

```bash
# Follow logs in real-time
docker logs -f vllm-wintermute

# Last 50 lines
docker logs vllm-wintermute --tail 50

# Check for errors
docker logs vllm-wintermute 2>&1 | grep -i error | tail -10

# Check for successful startup
docker logs vllm-wintermute 2>&1 | grep -E "(listening|Uvicorn|ready|started)"
```

## Monitor GPU Usage

```bash
# Current GPU status
nvidia-smi

# Watch GPU usage (updates every second)
watch -n 1 nvidia-smi

# Check GPU memory
nvidia-smi --query-gpu=memory.used,memory.free,utilization.gpu --format=csv
```

## Container Management

```bash
# Start/stop/restart
cd ~/miket-infra-devices
./devices/wintermute/scripts/vllm.sh start
./devices/wintermute/scripts/vllm.sh stop
./devices/wintermute/scripts/vllm.sh restart
./devices/wintermute/scripts/vllm.sh logs

# Or directly with docker
docker start vllm-wintermute
docker stop vllm-wintermute
docker restart vllm-wintermute
docker logs -f vllm-wintermute
```

## Current Issue

The container is restarting due to KV cache memory errors. The 14B model needs more memory than available after other processes.

**Current Status:**
- Container: Restarting (failing KV cache initialization)
- Model: Qwen2.5-14B-Instruct-AWQ
- Error: Needs 0.19 GiB KV cache, only 0.11 GiB available
- Suggested max_model_len: 624 (from error message)

**To Fix:**
Either reduce max_model_len further or switch to a smaller model (7B).

