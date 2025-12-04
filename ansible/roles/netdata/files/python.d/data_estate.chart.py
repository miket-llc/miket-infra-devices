# -*- coding: utf-8 -*-
# Copyright (c) 2025 MikeT LLC. All rights reserved.
#
# data_estate.chart.py
# Netdata Python collector for Data Estate monitoring
#
# Reads _status.json manifests and systemd failure logs to provide:
# - Mount health status (flux/space/time)
# - Job age since last success (space-mirror, flux-backup, flux-local-snap, flux-graduate)
# - Recent failure counts from systemd-failures.log
#
# Deployed by Ansible netdata role

import json
import os
from datetime import datetime, timezone, timedelta

from bases.FrameworkServices.SimpleService import SimpleService

ORDER = [
    'mount_health',
    'job_age',
    'slo_compliance',
    'recent_failures',
]

CHARTS = {
    'mount_health': {
        'options': [None, 'Data Estate Mount Health', 'status', 'data_estate', 'data_estate.mount_health', 'line'],
        'lines': [
            ['mount_flux', 'flux', 'absolute', 1, 1],
            ['mount_space', 'space', 'absolute', 1, 1],
            ['mount_time', 'time', 'absolute', 1, 1],
        ]
    },
    'job_age': {
        'options': [None, 'Data Estate Job Age', 'hours', 'data_estate', 'data_estate.job_age', 'line'],
        'lines': [
            ['job_age_space_mirror', 'space-mirror', 'absolute', 1, 1],
            ['job_age_flux_backup', 'flux-backup', 'absolute', 1, 1],
            ['job_age_flux_local', 'flux-local-snap', 'absolute', 1, 1],
            ['job_age_flux_graduate', 'flux-graduate', 'absolute', 1, 1],
        ]
    },
    'slo_compliance': {
        'options': [None, 'Data Estate SLO Compliance', 'percent', 'data_estate', 'data_estate.slo_compliance', 'area'],
        'lines': [
            ['slo_compliance_pct', 'compliance', 'absolute', 1, 1],
        ]
    },
    'recent_failures': {
        'options': [None, 'Data Estate Recent Failures', 'failures', 'data_estate', 'data_estate.failures', 'line'],
        'lines': [
            ['failures_space_mirror', 'space-mirror', 'absolute', 1, 1],
            ['failures_flux_backup', 'flux-backup', 'absolute', 1, 1],
            ['failures_flux_local', 'flux-local-snap', 'absolute', 1, 1],
            ['failures_flux_graduate', 'flux-graduate', 'absolute', 1, 1],
            ['failures_total', 'total', 'absolute', 1, 1],
        ]
    },
}


class Service(SimpleService):
    def __init__(self, configuration=None, name=None):
        SimpleService.__init__(self, configuration=configuration, name=name)
        self.order = ORDER
        self.definitions = CHARTS
        self.status_json_path = self.configuration.get('status_json_path', '/space/_ops/data-estate/status.json')
        self.device_status_path = self.configuration.get('device_status_path', '')
        self.failure_log_path = self.configuration.get('failure_log_path', '/var/log/systemd-failures.log')
        self.markers_dir = self.configuration.get('markers_dir', '/space/_ops/data-estate/markers')
        self.failure_window_minutes = self.configuration.get('failure_window_minutes', 60)

    def check(self):
        sources_available = False
        if os.path.exists(self.status_json_path):
            self.debug(f"Status JSON found: {self.status_json_path}")
            sources_available = True
        if os.path.exists(self.markers_dir):
            self.debug(f"Markers directory found: {self.markers_dir}")
            sources_available = True
        if os.path.exists(self.failure_log_path):
            self.debug(f"Failure log found: {self.failure_log_path}")
            sources_available = True
        if not sources_available:
            self.error("No data sources available")
            return False
        return True

    def _read_json(self, path):
        try:
            if not os.path.exists(path):
                return None
            with open(path, 'r') as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError):
            return None

    def _read_marker(self, marker_name):
        return self._read_json(os.path.join(self.markers_dir, f"{marker_name}.json"))

    def _hours_since(self, timestamp_str):
        try:
            if not timestamp_str or timestamp_str == 'null':
                return -1
            ts = datetime.fromisoformat(timestamp_str.replace('Z', '+00:00'))
            now = datetime.now(timezone.utc)
            return int((now - ts).total_seconds() / 3600)
        except (ValueError, TypeError):
            return -1

    def _count_recent_failures(self):
        failures = {'space_mirror': 0, 'flux_backup': 0, 'flux_local': 0, 'flux_graduate': 0, 'total': 0}
        try:
            if not os.path.exists(self.failure_log_path):
                return failures
            cutoff = datetime.now(timezone.utc) - timedelta(minutes=self.failure_window_minutes)
            with open(self.failure_log_path, 'r') as f:
                for line in f:
                    if not line.startswith('['):
                        continue
                    try:
                        ts_end = line.find(']')
                        if ts_end < 0:
                            continue
                        ts = datetime.fromisoformat(line[1:ts_end])
                        if ts < cutoff:
                            continue
                        failures['total'] += 1
                        if 'space-mirror' in line:
                            failures['space_mirror'] += 1
                        elif 'flux-backup' in line:
                            failures['flux_backup'] += 1
                        elif 'flux-local' in line:
                            failures['flux_local'] += 1
                        elif 'flux-graduate' in line:
                            failures['flux_graduate'] += 1
                    except (ValueError, IndexError):
                        continue
        except IOError:
            pass
        return failures

    def _check_mount(self, path):
        try:
            if not os.path.exists(path):
                return 0
            os.listdir(path)
            return 1
        except (OSError, PermissionError):
            return 0

    def get_data(self):
        data = {
            'mount_flux': self._check_mount('/flux'),
            'mount_space': self._check_mount('/space'),
            'mount_time': self._check_mount('/time'),
        }

        status = self._read_json(self.status_json_path)
        if status and 'checks' in status:
            checks = status['checks']
            data['job_age_space_mirror'] = checks.get('space_mirror_age', {}).get('value_hours', -1)
            data['job_age_flux_backup'] = checks.get('restic_cloud_age', {}).get('value_hours', -1)
            data['job_age_flux_local'] = checks.get('restic_local_age', {}).get('value_hours', -1)
            grad_marker = self._read_marker('flux_graduate')
            data['job_age_flux_graduate'] = self._hours_since(grad_marker.get('timestamp')) if grad_marker and grad_marker.get('status') == 'success' else -1
        else:
            for marker_name, key in [('b2_mirror', 'job_age_space_mirror'), ('restic_cloud', 'job_age_flux_backup'), ('restic_local', 'job_age_flux_local'), ('flux_graduate', 'job_age_flux_graduate')]:
                marker = self._read_marker(marker_name)
                data[key] = self._hours_since(marker.get('timestamp')) if marker and marker.get('status') == 'success' else -1

        if status and 'slo_compliance' in status:
            data['slo_compliance_pct'] = int(float(status['slo_compliance'].get('percentage', 0)))
        else:
            data['slo_compliance_pct'] = 0

        failures = self._count_recent_failures()
        data['failures_space_mirror'] = failures['space_mirror']
        data['failures_flux_backup'] = failures['flux_backup']
        data['failures_flux_local'] = failures['flux_local']
        data['failures_flux_graduate'] = failures['flux_graduate']
        data['failures_total'] = failures['total']

        return data

