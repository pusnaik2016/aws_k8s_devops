"""Tests for Tool 1: IaC Generator."""

import pytest
from pathlib import Path
from tools.iac_generator import IaCGenerator


class TestIaCGenerator:

    def test_generate_from_service_description(self, service_desc_samples, output_dir):
        gen = IaCGenerator()
        result = gen.analyze(
            str(service_desc_samples / "order_api.yaml"),
            output_dir=str(output_dir),
        )
        assert len(result.findings) >= 1
        # Should have generated terraform files
        assert result.summary.get("generated_files")
        assert (output_dir / "main.tf").exists()

    def test_generates_eks_tf(self, service_desc_samples, output_dir):
        gen = IaCGenerator()
        gen.analyze(
            str(service_desc_samples / "order_api.yaml"),
            output_dir=str(output_dir),
        )
        assert (output_dir / "eks.tf").exists()
        content = (output_dir / "eks.tf").read_text()
        assert "module" in content
        assert "eks" in content

    def test_generates_database_tf(self, service_desc_samples, output_dir):
        gen = IaCGenerator()
        gen.analyze(
            str(service_desc_samples / "order_api.yaml"),
            output_dir=str(output_dir),
        )
        assert (output_dir / "database.tf").exists()

    def test_generates_storage_tf(self, service_desc_samples, output_dir):
        gen = IaCGenerator()
        gen.analyze(
            str(service_desc_samples / "order_api.yaml"),
            output_dir=str(output_dir),
        )
        assert (output_dir / "storage.tf").exists()
        content = (output_dir / "storage.tf").read_text()
        assert "encryption" in content.lower() or "server_side_encryption" in content

    def test_missing_file(self, output_dir):
        gen = IaCGenerator()
        result = gen.analyze("/nonexistent/file.yaml", output_dir=str(output_dir))
        assert not result.passed or any(f.rule_id == "IAC000" for f in result.findings)

    def test_result_structure(self, service_desc_samples, output_dir):
        gen = IaCGenerator()
        result = gen.analyze(
            str(service_desc_samples / "order_api.yaml"),
            output_dir=str(output_dir),
        )
        d = result.to_dict()
        assert "tool_name" in d
        assert d["tool_name"] == "IaC Generator"
        assert "findings" in d
