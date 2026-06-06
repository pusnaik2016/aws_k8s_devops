"""Tests for Tool 3: Security Scanner."""

import pytest
from tools.security_scanner import SecurityScanner


class TestSecurityScanner:

    def test_detects_hardcoded_access_key(self, terraform_samples):
        scanner = SecurityScanner()
        result = scanner.analyze(str(terraform_samples))
        rule_ids = [f.rule_id for f in result.findings]
        assert "SEC001" in rule_ids

    def test_detects_hardcoded_password(self, terraform_samples):
        scanner = SecurityScanner()
        result = scanner.analyze(str(terraform_samples))
        rule_ids = [f.rule_id for f in result.findings]
        assert "SEC002" in rule_ids

    def test_detects_open_security_group(self, terraform_samples):
        scanner = SecurityScanner()
        result = scanner.analyze(str(terraform_samples))
        rule_ids = [f.rule_id for f in result.findings]
        assert "SEC010" in rule_ids

    def test_detects_public_s3(self, terraform_samples):
        scanner = SecurityScanner()
        result = scanner.analyze(str(terraform_samples))
        rule_ids = [f.rule_id for f in result.findings]
        assert "SEC020" in rule_ids

    def test_detects_unencrypted_ebs(self, terraform_samples):
        scanner = SecurityScanner()
        result = scanner.analyze(str(terraform_samples))
        rule_ids = [f.rule_id for f in result.findings]
        assert "SEC030" in rule_ids

    def test_detects_public_rds(self, terraform_samples):
        scanner = SecurityScanner()
        result = scanner.analyze(str(terraform_samples))
        rule_ids = [f.rule_id for f in result.findings]
        assert "SEC032" in rule_ids

    def test_detects_wildcard_iam(self, terraform_samples):
        scanner = SecurityScanner()
        result = scanner.analyze(str(terraform_samples))
        rule_ids = [f.rule_id for f in result.findings]
        assert "SEC040" in rule_ids or "SEC041" in rule_ids

    def test_fails_overall(self, terraform_samples):
        scanner = SecurityScanner()
        result = scanner.analyze(str(terraform_samples))
        assert not result.passed  # Should FAIL — many CRITICAL/HIGH findings

    def test_files_scanned_count(self, terraform_samples):
        scanner = SecurityScanner()
        result = scanner.analyze(str(terraform_samples))
        assert result.summary.get("files_scanned", 0) >= 1

    def test_no_files(self, tmp_path):
        scanner = SecurityScanner()
        result = scanner.analyze(str(tmp_path))
        assert len(result.findings) >= 1  # At least an INFO finding
