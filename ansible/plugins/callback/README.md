---
# Callback Plugin Configuration Guide
# Location: ansible/plugins/callback/README.md

# Ansible Callback Plugins for Observability

This directory contains custom callback plugins and configuration for enhanced observability.

## Built-in Callbacks (No Installation Required)

### 1. profile_tasks
**Status**: Enabled in ansible.cfg (stdout_callback = profile_tasks)

Shows execution time for each task, sorted by duration. Excellent for identifying slow tasks.

**Usage**: Automatically enabled via ansible.cfg

**Output Example**:
```
TASK [deploy vllm] **************************************************************
ok: [armitage] => (item=docker pull)  12.45s
ok: [wintermute] => (item=docker pull)  15.23s

PLAY RECAP **********************************************************************
armitage                   : ok=15   changed=3    unreachable=0    failed=0   
wintermute                  : ok=15   changed=3    unreachable=0    failed=0   

Task execution time:
  deploy vllm: 27.68s
  verify service: 3.12s
  gather facts: 1.45s
```

### 2. json
**Status**: Available (built-in)

Outputs playbook execution as JSON for programmatic parsing.

**Usage**:
```bash
ANSIBLE_STDOUT_CALLBACK=json ansible-playbook playbook.yml > output.json
```

**Installation**: None required

### 3. minimal
**Status**: Available (built-in)

Compact output showing only changed/failed tasks.

**Usage**:
```bash
ANSIBLE_STDOUT_CALLBACK=minimal ansible-playbook playbook.yml
```

## Third-Party Callbacks (Require Installation)

### 4. logstash
**Status**: Optional (requires installation)

Sends Ansible execution data to Logstash for centralized logging.

**Installation**:
```bash
pip install logstash-formatter
```

**Configuration**:
```bash
export ANSIBLE_LOGSTASH_HOST=logstash.example.com
export ANSIBLE_LOGSTASH_PORT=5000
export ANSIBLE_STDOUT_CALLBACK=logstash
ansible-playbook playbook.yml
```

**Benefits**:
- Centralized logging across all playbook runs
- Searchable execution history
- Integration with ELK stack

### 5. ARA (Ansible Run Analysis)
**Status**: Optional (requires installation)

Persistent run history with web UI for analyzing playbook executions.

**Installation**:
```bash
pip install ara[server]
```

**Configuration**:
1. Add to ansible.cfg:
```ini
callback_plugins = /usr/share/ansible/plugins/callback:~/.ansible/plugins/callback:plugins/callback
```

2. Enable ARA callback:
```bash
export ANSIBLE_CALLBACK_PLUGINS=$(python -m ara.setup.callback_plugins)
export ANSIBLE_ACTION_PLUGINS=$(python -m ara.setup.action_plugins)
export ANSIBLE_LIBRARY=$(python -m ara.setup.action_plugins)
```

3. Start ARA server:
```bash
ara-manage runserver  # Default: http://localhost:8000
```

**Benefits**:
- Web UI for browsing playbook runs
- Task-level execution history
- Performance metrics and trends
- Search and filtering capabilities

**Access**: http://localhost:8000 (or configure host/port)

## Custom Callback Example

See `custom_timing.py` for an example custom callback that logs task timings to a file.

## Recommended Setup

For this environment (Motoko control node, GPU workstations):

1. **Default**: `profile_tasks` (already configured)
   - Shows task timings inline
   - No installation required
   - Great for ad-hoc performance analysis

2. **For CI/CD**: `json` callback
   - Structured output for automation
   - Parse results programmatically

3. **For Production**: `logstash` + `ARA`
   - Logstash for centralized logging
   - ARA for historical analysis and trends

## Usage Examples

### Enable profile_tasks (default)
```bash
ansible-playbook playbooks/armitage-vllm-setup.yml
# Task timings shown automatically
```

### Enable JSON output
```bash
ANSIBLE_STDOUT_CALLBACK=json ansible-playbook playbook.yml | jq '.plays[].tasks[] | select(.task.duration > 10)'
# Filter tasks taking longer than 10 seconds
```

### Enable multiple callbacks (via environment)
```bash
export ANSIBLE_STDOUT_CALLBACK=profile_tasks
export ANSIBLE_CALLBACK_PLUGINS=/path/to/ara/plugins/callback
ansible-playbook playbook.yml
# Shows profile_tasks output + sends data to ARA
```

## Performance Impact

- **profile_tasks**: Negligible overhead (~1-2% slower)
- **json**: Minimal overhead (~2-3% slower)
- **logstash**: Network overhead (depends on latency)
- **ARA**: Database writes (~3-5% slower, but provides valuable insights)

