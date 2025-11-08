#!/bin/bash
# vLLM management script for Linux/WSL2
# Matches architecture pattern: direct docker run commands (like systemd template)
# Optimized for 12GB VRAM (RTX 4070 Super)
# Model: Qwen2.5-7B-Instruct-AWQ - Most capable model that fits comfortably

set -e

CONTAINER_NAME="vllm-wintermute"
MODEL_NAME="${VLLM_MODEL:-Qwen/Qwen2.5-7B-Instruct-AWQ}"
PORT="${VLLM_PORT:-8000}"
IMAGE="vllm/vllm-openai:latest"
GPU_MEMORY_UTILIZATION="${GPU_MEMORY_UTILIZATION:-0.85}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:-8192}"

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
        --max-model-len ${MAX_MODEL_LEN}
    
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
        echo "  Tailscale: http://wintermute.tail2e55fe.ts.net:${PORT}/v1"
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

