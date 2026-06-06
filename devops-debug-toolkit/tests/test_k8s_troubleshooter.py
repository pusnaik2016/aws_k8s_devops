"""Tests for Tool 8: K8s Troubleshooter."""

import pytest
from tools.k8s_troubleshooter import K8sTroubleshooter


class TestK8sTroubleshooter:

    def test_detects_privileged_container(self, k8s_samples):
        ts = K8sTroubleshooter()
        result = ts.analyze(str(k8s_samples / "bad_deployment.yaml"))
        rule_ids = [f.rule_id for f in result.findings]
        assert "K8S021" in rule_ids

    def test_detects_root_user(self, k8s_samples):
        ts = K8sTroubleshooter()
        result = ts.analyze(str(k8s_samples / "bad_deployment.yaml"))
        rule_ids = [f.rule_id for f in result.findings]
        assert "K8S020" in rule_ids

    def test_detects_latest_tag(self, k8s_samples):
        ts = K8sTroubleshooter()
        result = ts.analyze(str(k8s_samples / "bad_deployment.yaml"))
        rule_ids = [f.rule_id for f in result.findings]
        assert "K8S030" in rule_ids

    def test_detects_host_network(self, k8s_samples):
        ts = K8sTroubleshooter()
        result = ts.analyze(str(k8s_samples / "bad_deployment.yaml"))
        rule_ids = [f.rule_id for f in result.findings]
        assert "K8S023" in rule_ids

    def test_detects_host_pid(self, k8s_samples):
        ts = K8sTroubleshooter()
        result = ts.analyze(str(k8s_samples / "bad_deployment.yaml"))
        rule_ids = [f.rule_id for f in result.findings]
        assert "K8S024" in rule_ids

    def test_detects_single_replica(self, k8s_samples):
        ts = K8sTroubleshooter()
        result = ts.analyze(str(k8s_samples / "bad_deployment.yaml"))
        rule_ids = [f.rule_id for f in result.findings]
        assert "K8S050" in rule_ids

    def test_fails_with_critical_issues(self, k8s_samples):
        ts = K8sTroubleshooter()
        result = ts.analyze(str(k8s_samples / "bad_deployment.yaml"))
        assert not result.passed  # Privileged container is CRITICAL

    def test_no_k8s_files(self, tmp_path):
        ts = K8sTroubleshooter()
        result = ts.analyze(str(tmp_path))
        assert len(result.findings) >= 1
