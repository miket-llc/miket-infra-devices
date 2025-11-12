# Post-Deployment Validation Checklist

## Immediate Checks (After Deployment)

- [ ] Wintermute vLLM container is running
  ```powershell
  docker ps --filter name=vllm-wintermute
  ```

- [ ] Armitage vLLM container is running
  ```powershell
  docker ps --filter name=vllm-armitage
  ```

- [ ] LiteLLM proxy is running
  ```bash
  sudo systemctl status litellm
  ```

- [ ] New configuration appears in logs
  - Check for `max_model_len: 16384` (Wintermute)
  - Check for `max_model_len: 8192` (Armitage)
  - Check for `kv_cache_dtype: fp8`
  - Check for `max_num_seqs` values

## Health Checks

- [ ] Run health check script
  ```bash
  make health-check
  ```
  Expected: All services healthy

- [ ] Test LiteLLM API
  ```bash
  curl http://localhost:8000/v1/models
  ```
  Expected: List of models including new aliases

- [ ] Test Wintermute model
  ```bash
  curl http://localhost:8000/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{"model": "llama31-8b-wintermute", "messages": [{"role": "user", "content": "test"}], "max_tokens": 10}'
  ```
  Expected: Successful response

- [ ] Test Armitage model
  ```bash
  curl http://localhost:8000/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d '{"model": "qwen2.5-7b-armitage", "messages": [{"role": "user", "content": "test"}], "max_tokens": 10}'
  ```
  Expected: Successful response

## Tests

- [ ] Context window test
  ```bash
  make test-context
  ```
  Expected: All tests pass

- [ ] Burst load test
  ```bash
  make test-burst
  ```
  Expected: ≤1 error

## Monitoring (First 24 Hours)

- [ ] Monitor GPU memory usage
  - Wintermute: Should be ~92% utilization
  - Armitage: Should be ~90% utilization

- [ ] Check for OOM errors
  ```bash
  docker logs vllm-wintermute | grep -i oom
  docker logs vllm-armitage | grep -i oom
  ```
  Expected: No OOM errors

- [ ] Check for CUDA errors
  ```bash
  docker logs vllm-wintermute | grep -i cuda
  docker logs vllm-armitage | grep -i cuda
  ```
  Expected: No CUDA errors

- [ ] Monitor latency
  - Check test results: `artifacts/context_test_results.csv`
  - P90 latency should be reasonable (<30s for large contexts)

## Success Criteria

- [x] All services running
- [ ] Health checks passing
- [ ] Context tests passing
- [ ] Burst tests passing
- [ ] No OOM/CUDA errors
- [ ] GPU memory within expected ranges
- [ ] Latency acceptable

## If Issues Occur

1. Check logs: `logs/deployment-*.log`
2. Review troubleshooting: `docs/vLLM_CONTEXT_WINDOW_GUIDE.md`
3. Rollback if needed: `make rollback-wintermute rollback-armitage rollback-proxy`
