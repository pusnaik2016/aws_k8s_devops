"""
test_tf_helper.py — Terraform Validation Test Suite
======================================================
Tests the Terraform helper against examples/terraform/.
Validates module discovery, file structure, variable analysis, and report output.
"""

import pytest
from pathlib import Path


# ═══════════════════════════════════════════════════════════════════════════════
# Module Discovery Tests
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.mark.terraform
class TestModuleDiscovery:
    """Tests that the scanner finds Terraform modules."""

    def test_discovers_terraform_module(self, tf_report):
        """Scanner must find the examples/terraform/ module."""
        assert len(tf_report.modules) >= 1, (
            f"No Terraform modules found. Expected at least 1. "
            f"Check find_tf_directories() logic."
        )

    def test_discovers_resources(self, tf_report):
        """Scanner must discover Terraform resources."""
        assert tf_report.total_resources > 0, (
            f"No resources found in examples/terraform/. "
            f"Expected aws_vpc, aws_subnet, aws_security_group, etc."
        )

    def test_discovers_variables(self, tf_report):
        """Scanner must discover all variable declarations."""
        assert tf_report.total_variables >= 5, (
            f"Only {tf_report.total_variables} variables found — expected >= 5. "
            f"Check examples/terraform/variables.tf for variable declarations."
        )

    def test_discovers_outputs(self, tf_report):
        """Scanner must discover output declarations."""
        assert tf_report.total_outputs >= 2, (
            f"Only {tf_report.total_outputs} outputs found — expected >= 2. "
            f"Check examples/terraform/outputs.tf."
        )

    def test_discovers_data_sources(self, tf_report):
        """Scanner must discover data sources."""
        assert tf_report.total_data_sources >= 2, (
            f"Only {tf_report.total_data_sources} data sources found — expected >= 2. "
            f"Check data blocks in examples/terraform/main.tf."
        )


# ═══════════════════════════════════════════════════════════════════════════════
# File Structure Tests
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.mark.terraform
class TestModuleStructure:
    """Tests for Terraform module file structure."""

    def test_module_has_main_tf(self, tf_report):
        """Every Terraform module MUST have a main.tf file."""
        for mod in tf_report.modules:
            assert mod.has_main, (
                f"Module '{mod.path}' is missing main.tf. "
                f"Convention: resource definitions go in main.tf."
            )

    def test_module_has_variables_tf(self, tf_report):
        """Every Terraform module MUST have a variables.tf file."""
        for mod in tf_report.modules:
            assert mod.has_variables, (
                f"Module '{mod.path}' is missing variables.tf. "
                f"Convention: all variable declarations in variables.tf."
            )

    def test_module_has_outputs_tf(self, tf_report):
        """Every Terraform module MUST have an outputs.tf file."""
        for mod in tf_report.modules:
            assert mod.has_outputs, (
                f"Module '{mod.path}' is missing outputs.tf. "
                f"Convention: all output declarations in outputs.tf."
            )

    def test_module_has_provider_config(self, tf_report):
        """Root modules must have provider configuration."""
        root_modules = [m for m in tf_report.modules if m.has_backend]
        for mod in root_modules:
            assert mod.has_providers, (
                f"Root module '{mod.path}' has a backend but no provider configuration. "
                f"Add a providers.tf or provider block."
            )

    def test_module_has_backend_config(self, tf_report):
        """At least one module should have backend (remote state) configuration."""
        has_any_backend = any(m.has_backend for m in tf_report.modules)
        assert has_any_backend, (
            "No module has backend configuration. "
            "Root modules should use S3 backend with DynamoDB locking."
        )

    def test_structure_completeness_pass(self, tf_report):
        """The example module should pass structure completeness check."""
        for mod in tf_report.modules:
            assert mod.structure_complete, (
                f"Module '{mod.path}' is incomplete — "
                f"main.tf={mod.has_main}, variables.tf={mod.has_variables}, "
                f"outputs.tf={mod.has_outputs}. All three are required."
            )


# ═══════════════════════════════════════════════════════════════════════════════
# Dependency Graph Tests
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.mark.terraform
class TestDependencyGraph:
    """Tests for module dependency mapping."""

    def test_dependency_graph_is_populated(self, tf_report):
        """The dependency graph should contain entries for discovered modules."""
        assert len(tf_report.dependency_graph) > 0, (
            "Dependency graph is empty. "
            "The scanner should map module → source relationships."
        )

    def test_eks_module_dependency_detected(self, tf_report):
        """The EKS module reference should be detected."""
        all_deps = []
        for deps in tf_report.dependency_graph.values():
            all_deps.extend(deps)
        has_eks_dep = any("eks" in d.lower() for d in all_deps)
        assert has_eks_dep, (
            f"EKS module dependency not detected. Dependencies found: {all_deps}. "
            f"examples/terraform/main.tf uses terraform-aws-modules/eks/aws."
        )


# ═══════════════════════════════════════════════════════════════════════════════
# Variable Analysis Tests
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.mark.terraform
class TestVariableAnalysis:
    """Tests for variable declaration analysis."""

    def test_environment_variable_exists(self, tf_report):
        """An 'environment' variable must be defined."""
        all_vars = []
        for mod in tf_report.modules:
            all_vars.extend([v["name"] for v in mod.variables])
        assert "environment" in all_vars, (
            "Variable 'environment' not found. "
            "This is a required variable for environment-based resource naming."
        )

    def test_environment_has_validation(self, terraform_dir):
        """The 'environment' variable should have a validation block."""
        content = (terraform_dir / "variables.tf").read_text()
        assert "validation" in content, (
            "No validation block found in variables.tf. "
            "The 'environment' variable should validate against allowed values."
        )


# ═══════════════════════════════════════════════════════════════════════════════
# Report Output Tests
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.mark.terraform
class TestTfReportOutput:
    """Tests for Terraform report generation."""

    def test_markdown_output_has_structure_table(self, tf_helper, tf_report):
        """Markdown report must include the module structure table."""
        output = tf_helper.format_markdown(tf_report)
        assert "### 📁 Module Structure" in output, "Missing module structure section"
        assert "main.tf" in output, "main.tf not mentioned in report"
        assert "variables.tf" in output, "variables.tf not mentioned in report"

    def test_markdown_output_has_dependency_section(self, tf_helper, tf_report):
        """Markdown report must include the dependency graph."""
        output = tf_helper.format_markdown(tf_report)
        assert "### 🔗 Module Dependencies" in output, "Missing dependency graph section"

    def test_json_output_is_valid(self, tf_helper, tf_report):
        """JSON output must be valid and parseable."""
        import json
        output = tf_helper.format_json(tf_report)
        data = json.loads(output)
        assert "modules" in data, "JSON missing modules array"
        assert "verdict" in data, "JSON missing verdict"
        assert "dependency_graph" in data, "JSON missing dependency graph"

    def test_verdict_is_pass(self, tf_report):
        """Example Terraform module should pass validation (well-structured)."""
        assert tf_report.verdict == "PASS", (
            f"Expected verdict 'PASS' but got '{tf_report.verdict}'. "
            f"Warnings: {[w for m in tf_report.modules for w in m.warnings]}. "
            f"Errors: {[e for m in tf_report.modules for e in m.errors]}."
        )
