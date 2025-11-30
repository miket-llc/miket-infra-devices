# Motoko AI Profile

## Overview

Motoko (Alienware m17 R2, RTX 2080 Max-Q 8GB) runs lightweight AI workloads:
- **Text embeddings** (BGE Base, Arctic XS)
- **Zero-shot classification** (mDeBERTa)

**This node is NOT for large language models.** The RTX 2080 Max-Q has thermal constraints.

## Deployed Models

| Model | Task | LiteLLM Route | VRAM | Notes |
|-------|------|---------------|------|-------|
| BAAI/bge-base-en-v1.5 | Embedding | `local-motoko-embed-bge-base-en-v1-5` | ~400MB | Primary, 768-dim |
| Snowflake/snowflake-arctic-embed-xs | Embedding | `local-motoko-embed-arctic-xs` | ~100MB | Low-heat fallback, 384-dim |
| MoritzLaurer/mDeBERTa-v3-base-mnli-xnli | Classification | `local-motoko-classify-mdeberta-multilingual` | ~500MB | Zero-shot, multilingual |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        MOTOKO                                │
│                   RTX 2080 Max-Q 8GB                         │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ TEI Server  │  │ TEI Server  │  │ Classification API  │  │
│  │ BGE Base    │  │ Arctic XS   │  │ mDeBERTa            │  │
│  │ :8201       │  │ :8202       │  │ :8203               │  │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘  │
│         │                │                    │              │
│         └────────────────┴────────────────────┘              │
│                          │                                   │
│  ┌───────────────────────┴───────────────────────┐          │
│  │              LiteLLM Proxy (:8000)            │          │
│  │     Routes: embed.*, classify.*               │          │
│  │     Thermal-aware routing                     │          │
│  └───────────────────────────────────────────────┘          │
│                          │                                   │
│  ┌───────────────────────┴───────────────────────┐          │
│  │         Thermal Monitor (systemd)             │          │
│  │     GPU Temp → /tmp/gpu_thermal_state         │          │
│  │     Normal (<70°C) | Hot (70-80°C) | Critical │          │
│  └───────────────────────────────────────────────┘          │
└─────────────────────────────────────────────────────────────┘
```

## Ports

| Port | Service | Description |
|------|---------|-------------|
| 8000 | LiteLLM | Unified API gateway |
| 8201 | TEI (BGE) | Primary embeddings |
| 8202 | TEI (Arctic) | Low-heat embeddings |
| 8203 | Classifier | Zero-shot classification |

## Thermal Protection

### Power Limit
GPU power capped at 70W (vs 90W default) via:
```bash
nvidia-smi -pl 70
```

### Thermal States
- **Normal** (GPU < 70°C): All models available
- **Hot** (70-80°C): Route embeddings to Arctic XS, reduce classification concurrency
- **Critical** (> 80°C): Reject new GPU requests, return 503

### Automatic Degradation
The thermal monitor updates `/tmp/gpu_thermal_state` every 10 seconds.
LiteLLM checks this file and adjusts routing.

## Usage

### Embeddings
```bash
curl http://motoko:8000/v1/embeddings \
  -H "Authorization: Bearer sk-motoko-local" \
  -H "Content-Type: application/json" \
  -d '{"input": "Hello world", "model": "local-motoko-embed-bge-base-en-v1-5"}'
```

### Classification
```bash
curl http://motoko:8000/v1/classify \
  -H "Authorization: Bearer sk-motoko-local" \
  -H "Content-Type: application/json" \
  -d '{
    "input": "I love this product!",
    "candidate_labels": ["positive", "negative", "neutral"],
    "model": "local-motoko-classify-mdeberta-multilingual"
  }'
```

## Files

- `/podman/apps/tei-bge/` - BGE embeddings container
- `/podman/apps/tei-arctic/` - Arctic embeddings container
- `/podman/apps/classifier/` - Classification service
- `/podman/apps/litellm/config.yaml` - LiteLLM routing config
- `/etc/systemd/system/gpu-thermal-monitor.service` - Thermal monitor

## Maintenance

### Check thermal state
```bash
cat /tmp/gpu_thermal_state
nvidia-smi --query-gpu=temperature.gpu,power.draw --format=csv
```

### Restart services
```bash
systemctl restart podman-tei-bge podman-tei-arctic podman-classifier
```

