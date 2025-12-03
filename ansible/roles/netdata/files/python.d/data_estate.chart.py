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
import time
from datetime import datetime, timezone

from bases.FrameworkServices.SimpleService import SimpleService

# Chart definitions
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
        'options': [None, 'Data Estate Job Age (hours since last success)', 'hours', 'data_estate', 'data_estate.job_age', 'line'],
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
        'options': [None, 'Data Estate Recent Failures (last hour)', 'failures', 'data_estate', 'data_estate.failures', 'line'],
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
        
        # Configuration from data_estate.conf
        self.status_json_path = self.configuration.get('status_json_path', '/space/_ops/data-estate/status.json')
        self.device_status_path = self.configuration.get('device_status_path', '')
        self.failure_log_path = self.configuration.get('failure_log_path', '/var/log/systemd-failures.log')
        self.markers_dir = self.configuration.get('markers_dir', '/space/_ops/data-estate/markers')
        self.failure_window_minutes = self.configuration.get('failure_window_minutes', 60)
        
    def check(self):
        """Check if data sources are accessible"""
        # We're lenient - if any source is available, we proceed
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
    
    def _read_status_json(self):
        """Read the main data estate status.json file"""
        try:
            if not os.path.exists(self.status_json_path):
                return None
            with open(self.status_json_path, 'r') as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError) as e:
            self.debug(f"Error reading status.json: {e}")
            return None
    
    def _read_device_status(self):
        """Read the device-specific _status.json if configured"""
        try:
            if not self.device_status_path or not os.path.exists(self.device_status_path):
                return None
            with open(self.device_status_path, 'r') as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError) as e:
            self.debug(f"Error reading device status: {e}")
            return None
    
    def _read_marker(self, marker_name):
        """Read a marker file and return parsed data"""
        marker_path = os.path.join(self.markers_dir, f"{marker_name}.json")
        try:
            if not os.path.exists(marker_path):
                return None
            with open(marker_path, 'r') as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError) as e:
            self.debug(f"Error reading marker {marker_name}: {e}")
            return None
    
    def _hours_since(self, timestamp_str):
        """Calculate hours since a given ISO timestamp"""
        try:
            if not timestamp_str or timestamp_str == 'null':
                return -1
            # Parse ISO timestamp
            ts = datetime.fromisoformat(timestamp_str.replace('Z', '+00:00'))
            now = datetime.now(timezone.utc)
            delta = now - ts
            return int(delta.total_seconds() / 3600)
        except (ValueError, TypeError) as e:
            self.debug(f"Error parsing timestamp {timestamp_str}: {e}")
            return -1
    
    def _count_recent_failures(self):
        """Count failures in the last N minutes from systemd-failures.log"""
        failures = {
            'space_mirror': 0,
            'flux_backup': 0,
            'flux_local': 0,
            'flux_graduate': 0,
            'total': 0
        }
        
        try:
            if not os.path.exists(self.failure_log_path):
                return failures
                
            cutoff = datetime.now(timezone.utc) - \
                     __import__('datetime').timedelta(minutes=self.failure_window_minutes)
            
            with open(self.failure_log_path, 'r') as f:
                for line in f:
                    if not line.startswith('['):
                        continue
                    try:
                        # Parse log line: [2025-12-03T10:00:00+00:00] FAILURE: unit-name failed
                        ts_end = line.find(']')
                        if ts_end < 0:
                            continue
                        ts_str = line[1:ts_end]
                        ts = datetime.fromisoformat(ts_str)
                        
                        if ts < cutoff:
                            continue
                            
                        failures['total'] += 1
                        
                        # Categorize by service
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
                        
        except IOError as e:
            self.debug(f"Error reading failure log: {e}")
            
        return failures
    
    def _check_mount(self, path):
        """Check if a mount point is healthy (mounted and accessible)"""
        try:
            if not os.path.exists(path):
                return 0
            if not os.path.ismount(path):
                # On some systems, could be a bind mount - check if readable
                if not os.access(path, os.R_OK):
                    return 0
            # Check if we can list the directory
            os.listdir(path)
            return 1
        except (OSError, PermissionError):
            return 0
    
    def get_data(self):
        """Collect metrics for Netdata"""
        data = {}
        
        # Mount health
        data['mount_flux'] = self._check_mount('/flux')
        data['mount_space'] = self._check_mount('/space')
        data['mount_time'] = self._check_mount('/time')
        
        # Try to get job ages from status.json first
        status = self._read_status_json()
        device_status = self._read_device_status()
        
        # Job ages - prefer status.json, fallback to markers
        if status and 'checks' in status:
            checks = status['checks']
            data['job_age_space_mirror'] = checks.get('space_mirror_age', {}).get('value_hours', -1)
            data['job_age_flux_backup'] = checks.get('restic_cloud_age', {}).get('value_hours', -1)
            data['job_age_flux_local'] = checks.get('restic_local_age', {}).get('value_hours', -1)
            # flux-graduate doesn't have a dedicated check, read from marker
            grad_marker = self._read_marker('flux_graduate')
            if grad_marker and grad_marker.get('status') == 'success':
                data['job_age_flux_graduate'] = self._hours_since(grad_marker.get('timestamp'))
            else:
                data['job_age_flux_graduate'] = -1
        else:
            # Fallback to reading markers directly
            for marker_name, data_key in [
                ('b2_mirror', 'job_age_space_mirror'),
                ('restic_cloud', 'job_age_flux_backup'),
                ('restic_local', 'job_age_flux_local'),
                ('flux_graduate', 'job_age_flux_graduate'),
            ]:
                marker = self._read_marker(marker_name)
                if marker and marker.get('status') == 'success':
                    data[data_key] = self._hours_since(marker.get('timestamp'))
                else:
                    data[data_key] = -1
        
        # SLO compliance
        if status and 'slo_compliance' in status:
            data['slo_compliance_pct'] = int(float(status['slo_compliance'].get('percentage', 0)))
        elif device_status and 'overall_data_estate' in device_status:
            data['slo_compliance_pct'] = int(float(
                device_status['overall_data_estate'].get('slo_compliance_percent', 0)
            ))
        else:
            data['slo_compliance_pct'] = 0
        
        # Recent failures
        failures = self._count_recent_failures()
        data['failures_space_mirror'] = failures['space_mirror']
        data['failures_flux_backup'] = failures['flux_backup']
        data['failures_flux_local'] = failures['flux_local']
        data['failures_flux_graduate'] = failures['flux_graduate']
        data['failures_total'] = failures['total']
        
        return data

