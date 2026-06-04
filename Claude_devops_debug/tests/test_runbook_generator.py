"""Tests for Tool 7: Runbook Generator."""

import pytest
from pathlib import Path
from tools.runbook_generator import RunbookGenerator


class TestRunbookGenerator:

    def test_generates_runbook_from_terraform(self, terraform_samples, tmp_path):
        gen = RunbookGenerator()
        output = str(tmp_path / "runbook.md")
        result = gen.analyze(str(terraform_samples), output=output)
        assert Path(output).exists()
        content = Path(output).read_text()
        assert "Operational Runbook" in content

    def test_runbook_contains_resources(self, terraform_samples, tmp_path):
        gen = RunbookGenerator()
        output = str(tmp_path / "runbook.md")
        gen.analyze(str(terraform_samples), output=output)
        content = Path(output).read_text()
        assert "Terraform Resources" in content

    def test_runbook_contains_deployment_steps(self, terraform_samples, tmp_path):
        gen = RunbookGenerator()
        output = str(tmp_path / "runbook.md")
        gen.analyze(str(terraform_samples), output=output)
        content = Path(output).read_text()
        assert "Deployment Procedure" in content
        assert "terraform plan" in content

    def test_runbook_contains_incident_response(self, terraform_samples, tmp_path):
        gen = RunbookGenerator()
        output = str(tmp_path / "runbook.md")
        gen.analyze(str(terraform_samples), output=output)
        content = Path(output).read_text()
        assert "Incident Response" in content
        assert "SEV-1" in content

    def test_runbook_from_k8s(self, k8s_samples, tmp_path):
        gen = RunbookGenerator()
        output = str(tmp_path / "runbook.md")
        result = gen.analyze(str(k8s_samples), output=output)
        content = Path(output).read_text()
        assert "Kubernetes Objects" in content

    def test_empty_directory(self, tmp_path):
        gen = RunbookGenerator()
        output = str(tmp_path / "runbook.md")
        result = gen.analyze(str(tmp_path), output=output)
        assert any(f.rule_id == "RUN000" for f in result.findings)
