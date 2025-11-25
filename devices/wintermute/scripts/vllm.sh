#!/bin/bash
# Copyright (c) 2025 MikeT LLC. All rights reserved.

# vLLM management script for Linux/WSL2
# Matches architecture pattern: direct docker run commands (like systemd template)
# Optimized for 12GB VRAM (RTX 4070 Super)
# Model: Llama 3.1 8B Instruct AWQ - Reasoner model (matches LiteLLM config)

set -e

CONTAINER_NAME="vllm-wintermute"
MODEL_NAME="${VLLM_MODEL:-casperhansen/llama-3-8b-instruct-awq}"
PORT="${VLLM_PORT:-8000}"
IMAGE="vllm/vllm-openai:latest"
GPU_MEMORY_UTILIZATION="${GPU_MEMORY_UTILIZATION:-0.92}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:-16384}"
MAX_NUM_SEQS="${MAX_NUM_SEQS:-2}"
KV_CACHE_DTYPE="${KV_CACHE_DTYPE:-fp8}"
TENSOR_PARALLEL_SIZE="${TENSOR_PARALLEL_SIZE:-1}"

function start_vllm() {
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo "vLLM container is already running"
        return 0
    fi
    
    # Remove stopped container if exists
    docker rm -f ${CONTAINER_NAME} 2>/dev/null || true
    
    echo "Starting vLLM container..."
    echo "  Model: ${MODEL_NAME}"
    echo "  Port: ${PORT}"
    echo "  Container: ${CONTAINER_NAME}"
    echo "  Max Model Length: ${MAX_MODEL_LEN}"
    echo "  Max Num Seqs: ${MAX_NUM_SEQS}"
    echo "  GPU Memory Utilization: ${GPU_MEMORY_UTILIZATION}"
    echo "  KV Cache Dtype: ${KV_CACHE_DTYPE}"
    
    docker run -d \
        --name ${CONTAINER_NAME} \
        --gpus all \
        -p ${PORT}:8000 \
        --ipc host \
        --restart unless-stopped \
        -v ~/.cache/huggingface:/root/.cache/huggingface \
        ${IMAGE} \
        --model ${MODEL_NAME} \
        --port 8000 \
        --host 0.0.0.0 \
        --gpu-memory-utilization ${GPU_MEMORY_UTILIZATION} \
        --max-model-len ${MAX_MODEL_LEN} \
        --max-num-seqs ${MAX_NUM_SEQS} \
        --kv-cache-dtype ${KV_CACHE_DTYPE} \
        --tensor-parallel-size ${TENSOR_PARALLEL_SIZE}
    
    echo "✅ vLLM container started"
    echo "API available at: http://localhost:${PORT}/v1"
}

function stop_vllm() {
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo "vLLM container is not running"
        return 0
    fi
    
    docker stop ${CONTAINER_NAME}
    echo "✅ vLLM container stopped"
}

function status_vllm() {
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo "Status: Running"
        docker ps --filter name=${CONTAINER_NAME} --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo ""
        echo "API Endpoints:"
        echo "  Local:    http://localhost:${PORT}/v1"
        echo "  Health:   http://localhost:${PORT}/health"
        echo "  Tailscale: http://wintermute.pangolin-vega.ts.net:${PORT}/v1"
    else
        echo "Status: Stopped"
    fi
}

case "${1:-start}" in
    start)
        start_vllm
        ;;
    stop)
        stop_vllm
        ;;
    restart)
        stop_vllm
        sleep 2
        start_vllm
        ;;
    status)
        status_vllm
        ;;
    logs)
        docker logs -f ${CONTAINER_NAME}
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs}"
        exit 1
        ;;
esac

