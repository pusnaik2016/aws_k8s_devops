"""Tests for Tool 6: Legacy Code Modernizer."""

import pytest
from tools.legacy_modernizer import LegacyModernizer


class TestLegacyModernizer:

    def test_detects_eval(self, legacy_code_samples):
        modernizer = LegacyModernizer()
        result = modernizer.analyze(str(legacy_code_samples / "legacy_app.py"))
        rule_ids = [f.rule_id for f in result.findings]
        assert "SEC-EVAL" in rule_ids

    def test_detects_pickle(self, legacy_code_samples):
        modernizer = LegacyModernizer()
        result = modernizer.analyze(str(legacy_code_samples / "legacy_app.py"))
        rule_ids = [f.rule_id for f in result.findings]
        assert "SEC-PICKLE" in rule_ids

    def test_detects_os_system(self, legacy_code_samples):
        modernizer = LegacyModernizer()
        result = modernizer.analyze(str(legacy_code_samples / "legacy_app.py"))
        rule_ids = [f.rule_id for f in result.findings]
        assert "SEC-SHELL" in rule_ids

    def test_detects_hardcoded_credentials(self, legacy_code_samples):
        modernizer = LegacyModernizer()
        result = modernizer.analyze(str(legacy_code_samples / "legacy_app.py"))
        rule_ids = [f.rule_id for f in result.findings]
        assert "SEC-HARDCRED" in rule_ids

    def test_detects_bare_except(self, legacy_code_samples):
        modernizer = LegacyModernizer()
        result = modernizer.analyze(str(legacy_code_samples / "legacy_app.py"))
        rule_ids = [f.rule_id for f in result.findings]
        assert "QUAL-BARE-EXCEPT" in rule_ids

    def test_detects_file_no_context_manager(self, legacy_code_samples):
        modernizer = LegacyModernizer()
        result = modernizer.analyze(str(legacy_code_samples / "legacy_app.py"))
        rule_ids = [f.rule_id for f in result.findings]
        assert "QUAL-NO-CTX" in rule_ids

    def test_detects_python2_print(self, legacy_code_samples):
        modernizer = LegacyModernizer()
        result = modernizer.analyze(str(legacy_code_samples / "legacy_app.py"))
        rule_ids = [f.rule_id for f in result.findings]
        assert "PY2-PRINT" in rule_ids

    def test_fails_with_critical_findings(self, legacy_code_samples):
        modernizer = LegacyModernizer()
        result = modernizer.analyze(str(legacy_code_samples / "legacy_app.py"))
        assert not result.passed  # eval() and hardcoded creds are CRITICAL
