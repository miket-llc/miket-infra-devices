#!/usr/bin/env python3
"""
Custom Ansible Callback Plugin: Task Timing Logger
Logs task execution times to a structured log file for analysis.

Usage:
1. Copy to ansible/plugins/callback/custom_timing.py
2. Enable in ansible.cfg: callback_plugins = plugins/callback
3. Set environment: export ANSIBLE_CALLBACK_WHITELIST=custom_timing
4. Run playbooks - timings logged to /tmp/ansible-timings.log
"""

from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

import json
import os
from datetime import datetime
from ansible.plugins.callback import CallbackBase

DOCUMENTATION = '''
    callback: custom_timing
    type: stdout
    short_description: Logs task execution times to file
    description:
      - Logs task name, host, duration, and status to JSON log file
      - Useful for performance analysis and trend tracking
    requirements:
      - None
'''

class CallbackModule(CallbackBase):
    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = 'stdout'
    CALLBACK_NAME = 'custom_timing'
    CALLBACK_NEEDS_WHITELIST = True

    def __init__(self):
        super(CallbackModule, self).__init__()
        self.log_file = os.environ.get('ANSIBLE_TIMING_LOG', '/tmp/ansible-timings.log')
        self.task_timings = []

    def v2_playbook_on_task_start(self, task, is_conditional):
        """Record task start time"""
        self.task_start_time = datetime.now()

    def v2_runner_on_ok(self, result):
        """Record successful task completion"""
        self._record_timing(result, 'ok')

    def v2_runner_on_failed(self, result, ignore_errors=False):
        """Record failed task"""
        self._record_timing(result, 'failed')

    def v2_runner_on_skipped(self, result):
        """Record skipped task"""
        self._record_timing(result, 'skipped')

    def _record_timing(self, result, status):
        """Record task timing to log file"""
        if hasattr(self, 'task_start_time'):
            duration = (datetime.now() - self.task_start_time).total_seconds()
            
            log_entry = {
                'timestamp': datetime.now().isoformat(),
                'host': result._host.name,
                'task': result._task.get_name(),
                'duration_seconds': round(duration, 2),
                'status': status,
                'changed': result._result.get('changed', False)
            }
            
            # Append to log file
            with open(self.log_file, 'a') as f:
                f.write(json.dumps(log_entry) + '\n')
            
            self.task_timings.append(log_entry)

    def v2_playbook_on_stats(self, stats):
        """Print summary at end of playbook"""
        total_time = sum(t['duration_seconds'] for t in self.task_timings)
        self._display.display(f"\nTask timing summary logged to: {self.log_file}")
        self._display.display(f"Total task time: {total_time:.2f}s")
        self._display.display(f"Tasks logged: {len(self.task_timings)}")

