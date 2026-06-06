"""Tests for Tool 5: Server Config Analyzer."""

import pytest
from tools.server_config_analyzer import ServerConfigAnalyzer


class TestServerConfigAnalyzer:

    def test_detects_server_tokens(self, server_config_samples):
        analyzer = ServerConfigAnalyzer()
        result = analyzer.analyze(str(server_config_samples / "nginx_bad.conf"))
        rule_ids = [f.rule_id for f in result.findings]
        assert "SRV001" in rule_ids

    def test_detects_http_without_ssl(self, server_config_samples):
        analyzer = ServerConfigAnalyzer()
        result = analyzer.analyze(str(server_config_samples / "nginx_bad.conf"))
        rule_ids = [f.rule_id for f in result.findings]
        assert "SRV002" in rule_ids

    def test_detects_weak_ssl(self, server_config_samples):
        analyzer = ServerConfigAnalyzer()
        result = analyzer.analyze(str(server_config_samples / "nginx_bad.conf"))
        rule_ids = [f.rule_id for f in result.findings]
        assert "SRV003" in rule_ids

    def test_detects_autoindex(self, server_config_samples):
        analyzer = ServerConfigAnalyzer()
        result = analyzer.analyze(str(server_config_samples / "nginx_bad.conf"))
        rule_ids = [f.rule_id for f in result.findings]
        assert "SRV006" in rule_ids

    def test_detects_access_log_off(self, server_config_samples):
        analyzer = ServerConfigAnalyzer()
        result = analyzer.analyze(str(server_config_samples / "nginx_bad.conf"))
        rule_ids = [f.rule_id for f in result.findings]
        assert "SRV007" in rule_ids

    def test_identifies_nginx(self, server_config_samples):
        analyzer = ServerConfigAnalyzer()
        result = analyzer.analyze(str(server_config_samples / "nginx_bad.conf"))
        assert len(result.findings) > 0

    def test_missing_file(self):
        analyzer = ServerConfigAnalyzer()
        result = analyzer.analyze("/nonexistent/nginx.conf")
        assert len(result.findings) >= 1
