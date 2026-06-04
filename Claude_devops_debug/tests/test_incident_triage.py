"""Tests for Tool 4: Incident Triage Analyzer."""

import pytest
from pathlib import Path
from tools.incident_triage import IncidentTriage


SAMPLE_LOG = """\
2024-03-15T10:00:01Z INFO Starting application on port 8080
2024-03-15T10:00:15Z INFO Connected to database
2024-03-15T10:05:30Z ERROR Connection refused to redis-cluster:6379 ECONNREFUSED
2024-03-15T10:05:31Z ERROR Connection refused to redis-cluster:6379 ECONNREFUSED
2024-03-15T10:05:32Z WARN Retry 1/3 for redis connection
2024-03-15T10:06:00Z ERROR java.lang.OutOfMemoryError: Java heap space
    at com.myapp.service.DataProcessor.process(DataProcessor.java:145)
    at com.myapp.handler.RequestHandler.handle(RequestHandler.java:67)
2024-03-15T10:06:01Z FATAL Application crashed - OOMKilled
2024-03-15T10:07:00Z ERROR HTTP 503 Service Unavailable from upstream
2024-03-15T10:08:00Z ERROR authentication failed for user admin - 401 Unauthorized
"""


class TestIncidentTriage:

    def test_detects_oom(self, tmp_path):
        log_file = tmp_path / "app.log"
        log_file.write_text(SAMPLE_LOG)
        triage = IncidentTriage()
        result = triage.analyze(str(log_file))
        titles = [f.title for f in result.findings]
        assert any("Memory" in t or "OOM" in t for t in titles)

    def test_detects_connection_failure(self, tmp_path):
        log_file = tmp_path / "app.log"
        log_file.write_text(SAMPLE_LOG)
        triage = IncidentTriage()
        result = triage.analyze(str(log_file))
        titles = [f.title for f in result.findings]
        assert any("Connection" in t for t in titles)

    def test_detects_http_5xx(self, tmp_path):
        log_file = tmp_path / "app.log"
        log_file.write_text(SAMPLE_LOG)
        triage = IncidentTriage()
        result = triage.analyze(str(log_file))
        titles = [f.title for f in result.findings]
        assert any("5xx" in t or "HTTP" in t for t in titles)

    def test_detects_auth_failure(self, tmp_path):
        log_file = tmp_path / "app.log"
        log_file.write_text(SAMPLE_LOG)
        triage = IncidentTriage()
        result = triage.analyze(str(log_file))
        titles = [f.title for f in result.findings]
        assert any("Authentication" in t or "auth" in t.lower() for t in titles)

    def test_error_frequency(self, tmp_path):
        log_file = tmp_path / "app.log"
        log_file.write_text(SAMPLE_LOG)
        triage = IncidentTriage()
        result = triage.analyze(str(log_file))
        assert result.summary.get("total_errors", 0) > 0

    def test_clean_log(self, tmp_path):
        log_file = tmp_path / "clean.log"
        log_file.write_text("2024-01-01 INFO All systems operational\n")
        triage = IncidentTriage()
        result = triage.analyze(str(log_file))
        assert any(f.rule_id == "INC099" for f in result.findings)

    def test_missing_file(self):
        triage = IncidentTriage()
        result = triage.analyze("/nonexistent/app.log")
        assert any(f.rule_id == "INC000" for f in result.findings)
