# Ansible Optimization Quick Reference

## Quick Start

### Run Optimized Playbooks

```bash
# Default (with profile_tasks timing)
ansible-playbook playbooks/armitage-vllm-setup.yml

# JSON output for automation
ANSIBLE_STDOUT_CALLBACK=json ansible-playbook playbook.yml > output.json

# With custom timing callback
export ANSIBLE_CALLBACK_WHITELIST=custom_timing
ansible-playbook playbook.yml
```

## Key Configuration Changes

### ansible.cfg Highlights

- ✅ **forks = 10**: Parallel execution (2-3x faster)
- ✅ **pipelining = True**: Reduced SSH overhead (2-5x faster)
- ✅ **fact_caching = jsonfile**: 24h cache (5-10s saved per run)
- ✅ **ControlPersist**: SSH connection reuse (30-50% faster)
- ✅ **stdout_callback = profile_tasks**: Task timing display

## Playbook Patterns

### Async Execution (Long Tasks)

```yaml
- name: Pull Docker image
  command: docker pull {{ image }}
  async: 600    # Max time
  poll: 15      # Check interval
```

### Parallel Execution (Multi-Host)

```yaml
- name: Deploy to all hosts
  hosts: gpu_8gb,gpu_12gb
  strategy: free  # Parallel!
  gather_facts: no
```

### Skip Facts (Faster Startup)

```yaml
- name: Quick task
  hosts: all
  gather_facts: no  # Skip if not needed
```

## Expected Performance Gains

| Scenario | Before | After | Improvement |
|----------|--------|-------|-------------|
| Single host | 15 min | 8-10 min | **40-50%** |
| Multi-host | 25 min | 10-12 min | **50-60%** |
| Cached facts | 10-15s | 2-3s | **70-80%** |

## Observability

### Built-in (profile_tasks)
- Shows task timings automatically
- No setup required

### Custom Timing Log
- Location: `/tmp/ansible-timings.log`
- Format: JSON per task
- Enable: `export ANSIBLE_CALLBACK_WHITELIST=custom_timing`

### ARA (Optional)
```bash
pip install ara[server]
export ANSIBLE_CALLBACK_PLUGINS=$(python -m ara.setup.callback_plugins)
ara-manage runserver
# http://localhost:8000
```

## Files Created

1. **ansible/ansible.cfg** - Optimized configuration
2. **ansible/playbooks/examples/gpu-async-example.yml** - Async patterns
3. **ansible/playbooks/examples/multi-host-gpu-deploy-optimized.yml** - Multi-host example
4. **ansible/plugins/callback/custom_timing.py** - Custom callback
5. **ansible/plugins/callback/README.md** - Callback guide
6. **ansible/PERFORMANCE_OPTIMIZATION.md** - Full documentation

## Next Steps

1. **Test optimizations**: Run existing playbooks and compare timings
2. **Enable ARA** (optional): For persistent run history
3. **Refactor playbooks**: Add async/strategy:free where applicable
4. **Monitor**: Use profile_tasks to identify slow tasks

## Troubleshooting

**Slow execution?**
- Check `forks` in ansible.cfg
- Use `strategy: free` for multi-host
- Use async for long tasks

**High SSH overhead?**
- Verify `pipelining = True`
- Check ControlPersist in ssh_args
- Look for connection reuse in logs

**Fact gathering slow?**
- Use `gather_facts: no` when possible
- Check fact cache: `ls /tmp/ansible_facts/`
- Clear cache if stale: `rm -rf /tmp/ansible_facts/*`

