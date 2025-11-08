# vLLM Motoko Role

Deploys vLLM reasoning and embeddings services on Motoko using Docker Compose.

## Requirements

- Docker and Docker Compose plugin installed
- NVIDIA GPU with CUDA support
- NVIDIA Container Toolkit installed

## Role Variables

See `defaults/main.yml` for all available variables.

### Key Variables

- `vllm_reasoning_enabled`: Enable reasoning service (default: `true`)
- `vllm_reasoning_model`: Model to use for reasoning (default: `mistralai/Mistral-7B-Instruct-v0.2-AWQ`)
- `vllm_reasoning_port`: Port for reasoning service (default: `8001`)
- `vllm_embeddings_enabled`: Enable embeddings service (default: `true`)
- `vllm_embeddings_model`: Model to use for embeddings (default: `BAAI/bge-base-en-v1.5`)
- `vllm_embeddings_port`: Port for embeddings service (default: `8200`)

## Example Playbook

```yaml
- name: Deploy vLLM on Motoko
  hosts: motoko
  become: true
  roles:
    - vllm-motoko
```

## License

MIT

