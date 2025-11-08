# Ansible Performance Optimization Guide

## Overview

This document outlines the performance optimizations applied to the Ansible infrastructure and expected speed improvements. The environment consists of:

- **Control Node**: Motoko (Linux, always-on)
- **Managed Nodes**: 
  - Armitage (Windows, GPU workstation)
  - Wintermute (Linux, GPU workstation)

## Optimizations Applied

### 1. ansible.cfg Configuration

#### Performance Improvements

| Setting | Value | Impact | Expected Gain |
|---------|-------|--------|---------------|
| `forks` | 10 | Parallel task execution | **2-3x faster** for multi-host playbooks |
| `pipelining` | True | Reduced SSH round-trips | **2-5x faster** for tasks with many commands |
| `fact_caching` | jsonfile (24h) | Avoid re-gathering facts | **5-10s saved** per playbook run |
| `ControlPersist` | 60s | Reuse SSH connections | **30-50% faster** for multi-task playbooks |
| `gathering` | smart | Gather facts once per playbook | **2-5s saved** per play |

**Total Expected Improvement**: **3-5x faster** execution for typical playbooks

#### Observability Improvements

- **profile_tasks callback**: Shows task-level timing (built-in)
- **JSON callback**: Structured output for automation
- **Custom timing callback**: Logs to `/tmp/ansible-timings.log`
- **ARA integration**: Optional web UI for run history

### 2. Playbook Optimizations

#### Async Execution Pattern

**Before**:
```yaml
- name: Pull Docker image
  command: docker pull vllm/vllm-openai:latest
  # Blocks until complete (5-10 minutes)
```

**After**:
```yaml
- name: Pull Docker image (async)
  command: docker pull vllm/vllm-openai:latest
  async: 600
  poll: 15
  # Non-blocking, allows other tasks to proceed
```

**Expected Gain**: **50-70% faster** for playbooks with long-running tasks

#### Strategy: Free

**Before**:
```yaml
- name: Deploy to GPU hosts
  hosts: gpu_8gb,gpu_12gb
  # Linear execution: one host at a time
```

**After**:
```yaml
- name: Deploy to GPU hosts
  hosts: gpu_8gb,gpu_12gb
  strategy: free
  # Parallel execution: all hosts proceed independently
```

**Expected Gain**: **2-3x faster** for multi-host deployments

#### Reduced Fact Gathering

**Before**:
```yaml
- name: Deploy service
  hosts: all
  gather_facts: yes  # Always gathers all facts
```

**After**:
```yaml
- name: Deploy service
  hosts: all
  gather_facts: no  # Skip if not needed
  # Or gather only what's needed:
  # gather_subset: ['network', 'hardware']
```

**Expected Gain**: **2-5s saved** per host per playbook

## Expected Performance Gains

### Scenario 1: Single Host Deployment (Armitage vLLM Setup)

| Metric | Before | After | Improvement |
|--------|--------|-------|------------|
| Total time | ~15 minutes | ~8-10 minutes | **40-50% faster** |
| Fact gathering | 5-8s | 0-2s (cached) | **5-6s saved** |
| Docker pull | 5-8 min (blocking) | 5-8 min (async) | Non-blocking |
| Task parallelism | Sequential | Parallel where possible | **30-40% faster** |

### Scenario 2: Multi-Host Deployment (All GPU Hosts)

| Metric | Before | After | Improvement |
|--------|--------|-------|------------|
| Total time | ~25 minutes | ~10-12 minutes | **50-60% faster** |
| Parallel execution | Sequential | Strategy: free | **2-3x faster** |
| SSH overhead | High (new connections) | Low (ControlPersist) | **30-50% faster** |
| Fact gathering | 15-20s total | 2-5s (cached) | **10-15s saved** |

### Scenario 3: Frequent Runs (Fact Cache Hit)

| Metric | Before | After | Improvement |
|--------|--------|-------|------------|
| Fact gathering | 5-8s per host | <1s (cache hit) | **5-7s saved** |
| Playbook startup | 10-15s | 2-3s | **70-80% faster** |

## Alternative Solutions

### When to Consider Alternatives

Ansible is excellent for configuration management, but some operations may benefit from alternatives:

### 1. Docker Compose for GPU Service Deployment

**Use Case**: Deploying and managing GPU services (vLLM, embeddings)

**Why Consider**: 
- Faster service startup (no Ansible overhead)
- Better for frequent restarts/updates
- Native Docker orchestration

**Implementation**:
```yaml
# Instead of Ansible tasks, use docker-compose directly
- name: Deploy vLLM via Docker Compose
  command: docker compose -f /opt/vllm/docker-compose.yml up -d
  # Or use Ansible's docker_compose module (best of both worlds)
```

**Recommendation**: **Keep using Ansible** for initial setup, use Docker Compose for runtime management

**Speed Comparison**:
- Ansible: ~30s for service deployment
- Docker Compose: ~5-10s for service deployment
- **Gain**: 3-6x faster for service restarts

### 2. PowerShell DSC for Windows Configuration

**Use Case**: Complex Windows configuration (registry, services, features)

**Why Consider**:
- Native Windows tooling
- Declarative configuration
- Better for Windows-specific tasks

**Current Approach**: Ansible win_* modules work well, but DSC may be faster for complex configs

**Recommendation**: **Keep using Ansible** - win_* modules are sufficient and maintain consistency

**Speed Comparison**:
- Ansible win_feature: ~2-5 minutes
- PowerShell DSC: ~1-3 minutes
- **Gain**: 20-40% faster, but adds complexity

### 3. SaltStack for Ad-Hoc Commands

**Use Case**: Fast ad-hoc command execution across hosts

**Why Consider**:
- Faster command execution (push-based)
- Better for real-time monitoring
- Lower latency

**Current Approach**: Ansible ad-hoc commands (`ansible all -a "command"`)

**Recommendation**: **Keep using Ansible** - ad-hoc commands are fast enough with optimizations

**Speed Comparison**:
- Ansible ad-hoc: ~2-5s per host
- SaltStack: ~1-2s per host
- **Gain**: 2-3x faster, but requires SaltStack infrastructure

### 4. Fabric for Simple Script Execution

**Use Case**: Simple Python scripts for automation

**Why Consider**:
- Lightweight Python library
- Good for simple tasks
- Lower overhead

**Recommendation**: **Use Ansible** - more features, better error handling, idempotency

## Monitoring and Observability

### Built-in Observability

1. **profile_tasks callback** (enabled by default)
   - Shows task execution times
   - Identifies slow tasks
   - No installation required

2. **Structured Logging**
   - Logs to `/tmp/ansible.log`
   - JSON format available
   - Parseable for analysis

3. **Custom Timing Callback**
   - Logs to `/tmp/ansible-timings.log`
   - JSON format for each task
   - Track trends over time

### Optional: ARA Integration

**Benefits**:
- Web UI for browsing playbook runs
- Historical performance trends
- Task-level analytics
- Search and filtering

**Setup**:
```bash
pip install ara[server]
export ANSIBLE_CALLBACK_PLUGINS=$(python -m ara.setup.callback_plugins)
ara-manage runserver
# Access at http://localhost:8000
```

**Performance Impact**: ~3-5% slower, but provides valuable insights

## Best Practices

### 1. Use Async for Long-Running Tasks

```yaml
- name: Long operation
  command: long-running-command
  async: 600  # Max time
  poll: 15    # Check interval
```

### 2. Use Strategy: Free for Independent Tasks

```yaml
- name: Deploy to multiple hosts
  hosts: gpu_8gb,gpu_12gb
  strategy: free  # Parallel execution
```

### 3. Skip Facts When Not Needed

```yaml
- name: Quick task
  hosts: all
  gather_facts: no  # Faster startup
```

### 4. Leverage Fact Caching

- Facts cached for 24 hours
- Clear cache when needed: `rm -rf /tmp/ansible_facts/*`
- Use Redis for shared cache (optional)

### 5. Batch Similar Operations

```yaml
# Instead of multiple tasks, batch them
- name: Install packages
  apt:
    name:
      - package1
      - package2
      - package3
    state: present
```

## Troubleshooting Performance

### Slow Playbook Execution

1. **Check fact gathering**: Use `gather_facts: no` if not needed
2. **Check forks**: Increase `forks` in ansible.cfg (default: 10)
3. **Check async**: Use async for long-running tasks
4. **Check strategy**: Use `strategy: free` for independent tasks

### High SSH Overhead

1. **Check ControlPersist**: Ensure SSH args include ControlPersist
2. **Check pipelining**: Ensure `pipelining = True` in ansible.cfg
3. **Check connection reuse**: Look for connection reuse in logs

### Fact Gathering Slow

1. **Check cache**: Ensure fact caching is enabled
2. **Check cache timeout**: Increase `fact_caching_timeout` if needed
3. **Check gather_subset**: Use `gather_subset` to limit facts gathered

## Summary

### Key Optimizations

1. ✅ **ansible.cfg**: Pipelining, ControlPersist, higher forks, fact caching
2. ✅ **Async execution**: Long-running tasks don't block
3. ✅ **Strategy: free**: Parallel execution for independent tasks
4. ✅ **Reduced fact gathering**: Skip when not needed
5. ✅ **Observability**: profile_tasks, custom callbacks, optional ARA

### Expected Results

- **Single host**: 40-50% faster
- **Multi-host**: 50-60% faster
- **Cached runs**: 70-80% faster startup
- **Better visibility**: Task-level timing, structured logs

### Recommendations

- **Keep Ansible** for configuration management
- **Use Docker Compose** for runtime service management
- **Enable ARA** for production environments (optional)
- **Monitor timings** using profile_tasks and custom callbacks

