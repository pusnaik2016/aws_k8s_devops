"""
test_integration.py — End-to-End Integration Tests
=====================================================
Tests that all scanners work together and produce consistent results.
Validates cross-engine report aggregation and the full scanning pipeline.
"""

import pytest
import subprocess
import sys
import json
from pathlib import Path


# ═══════════════════════════════════════════════════════════════════════════════
# CLI Execution Tests — run scripts as commands
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.mark.integration
class TestCLIExecution:
    """Tests that each script runs correctly from the command line."""

    @staticmethod
    def _run_script(script_name: str, args: list[str], cwd: Path) -> subprocess.CompletedProcess:
        return subprocess.run(
            [sys.executable, str(cwd / "scripts" / script_name)] + args,
            capture_output=True, text=True, timeout=30, cwd=str(cwd),
        )

    def test_sec_scanner_cli_text(self, project_root):
        """sec_scanner.py must run successfully with --format text."""
        result = self._run_script("sec_scanner.py", [
            "--path", str(project_root / "examples"),
            "--format", "text",
        ], project_root)
        assert "SECURITY SCAN REPORT" in result.stdout, (
            f"Text output missing report header. stderr: {result.stderr}"
        )

    def test_sec_scanner_cli_json(self, project_root):
        """sec_scanner.py must produce valid JSON."""
        result = self._run_script("sec_scanner.py", [
            "--path", str(project_root / "examples"),
            "--format", "json",
        ], project_root)
        data = json.loads(result.stdout)
        assert "verdict" in data, "JSON output missing 'verdict' field"
        assert "findings" in data, "JSON output missing 'findings' array"

    def test_sec_scanner_cli_markdown(self, project_root):
        """sec_scanner.py must produce Markdown output."""
        result = self._run_script("sec_scanner.py", [
            "--path", str(project_root / "examples"),
            "--format", "markdown",
        ], project_root)
        assert "## 🔒 Security Scan Report" in result.stdout, (
            f"Markdown output missing header. stderr: {result.stderr}"
        )

    def test_k8s_helper_cli_text(self, project_root):
        """k8s_helper.py must run successfully with --format text."""
        result = self._run_script("k8s_helper.py", [
            "--path", str(project_root / "examples" / "k8s"),
            "--format", "text",
        ], project_root)
        assert "KUBERNETES DIAGNOSTICS REPORT" in result.stdout, (
            f"Text output missing header. stderr: {result.stderr}"
        )

    def test_k8s_helper_cli_json(self, project_root):
        """k8s_helper.py must produce valid JSON."""
        result = self._run_script("k8s_helper.py", [
            "--path", str(project_root / "examples" / "k8s"),
            "--format", "json",
        ], project_root)
        data = json.loads(result.stdout)
        assert "workloads" in data, "JSON output missing 'workloads'"
        assert len(data["workloads"]) >= 2, "Expected >= 2 workloads in JSON"

    def test_tf_helper_cli_text(self, project_root):
        """tf_helper.py must run successfully with --format text."""
        result = self._run_script("tf_helper.py", [
            "--path", str(project_root / "examples" / "terraform"),
            "--format", "text",
        ], project_root)
        assert "TERRAFORM VALIDATION REPORT" in result.stdout, (
            f"Text output missing header. stderr: {result.stderr}"
        )

    def test_tf_helper_cli_json(self, project_root):
        """tf_helper.py must produce valid JSON."""
        result = self._run_script("tf_helper.py", [
            "--path", str(project_root / "examples" / "terraform"),
            "--format", "json",
        ], project_root)
        data = json.loads(result.stdout)
        assert "modules" in data, "JSON output missing 'modules'"
        assert data["verdict"] == "PASS", f"Expected PASS but got {data['verdict']}"

    def test_pr_analyser_cli_with_files(self, project_root):
        """pr_analyser.py must work with --files flag."""
        result = self._run_script("pr_analyser.py", [
            "--files",
            str(project_root / "examples" / "terraform" / "main.tf"),
            str(project_root / "examples" / "k8s" / "backend.yaml"),
            "--format", "json",
        ], project_root)
        data = json.loads(result.stdout)
        assert "changed_files" in data, "JSON missing 'changed_files'"
        assert len(data["changed_files"]) == 2, f"Expected 2 files but got {len(data['changed_files'])}"


# ═══════════════════════════════════════════════════════════════════════════════
# Cross-Engine Consistency Tests
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.mark.integration
class TestCrossEngineConsistency:
    """Tests that findings are consistent across different scanners."""

    def test_frontend_latest_tag_in_both_scanners(
        self, security_report, k8s_report, sec_scanner
    ):
        """The :latest tag in frontend.yaml should be detected by BOTH
        sec_scanner (K8S-IMG-001) and k8s_helper (Image tag FAIL)."""
        sec_findings = [
            f for f in security_report.findings
            if f.rule_id == "K8S-IMG-001" and "frontend" in f.description.lower()
        ]
        k8s_diags = [
            d for d in k8s_report.diagnostics
            if d.category == "Image" and d.status == "FAIL" and "frontend" in d.resource.lower()
        ]
        assert len(sec_findings) > 0, "sec_scanner missed :latest tag in frontend"
        assert len(k8s_diags) > 0, "k8s_helper missed :latest tag in frontend"

    def test_security_context_in_both_scanners(
        self, security_report, k8s_report
    ):
        """Missing securityContext in frontend should be detected by both scanners."""
        sec_findings = [
            f for f in security_report.findings
            if f.rule_id == "K8S-SEC-001" and "frontend" in f.description.lower()
        ]
        k8s_diags = [
            d for d in k8s_report.diagnostics
            if d.check == "runAsNonRoot" and d.status == "FAIL" and "frontend" in d.resource.lower()
        ]
        assert len(sec_findings) > 0, "sec_scanner missed runAsNonRoot issue in frontend"
        assert len(k8s_diags) > 0, "k8s_helper missed runAsNonRoot issue in frontend"


# ═══════════════════════════════════════════════════════════════════════════════
# PR Analyser File Categorisation Tests
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.mark.pr
class TestPRAnalyserCategorisation:
    """Tests that the PR analyser correctly categorises file types."""

    def test_categorises_terraform_files(self, pr_analyser):
        """Terraform .tf files must be categorised as Infrastructure."""
        cat = pr_analyser._categorise_file("infra/main.tf")
        assert cat == pr_analyser.FileCategory.INFRASTRUCTURE, (
            f"Expected 'Infrastructure' but got '{cat}' for main.tf. "
            f"Check CATEGORY_MAP and path-based detection."
        )

    def test_categorises_k8s_manifests(self, pr_analyser, project_root):
        """K8s manifests with apiVersion/kind must be categorised as Kubernetes."""
        # Use the actual example file so content-based detection works
        actual_path = str(project_root / "examples" / "k8s" / "backend.yaml")
        cat = pr_analyser._categorise_file(actual_path)
        assert cat == pr_analyser.FileCategory.KUBERNETES, (
            f"Expected 'Kubernetes' but got '{cat}' for examples/k8s/backend.yaml. "
            f"The file contains apiVersion/kind which should trigger K8s detection."
        )

    def test_categorises_github_actions(self, pr_analyser):
        """GitHub Actions workflow files must be categorised as CI/CD."""
        cat = pr_analyser._categorise_file(".github/workflows/ci.yml")
        assert cat == pr_analyser.FileCategory.CICD, (
            f"Expected 'CI/CD' but got '{cat}' for .github/workflows/ci.yml."
        )

    def test_categorises_dockerfiles(self, pr_analyser):
        """Dockerfiles must be categorised as Docker."""
        cat = pr_analyser._categorise_file("Dockerfile")
        assert cat == pr_analyser.FileCategory.DOCKER, (
            f"Expected 'Docker' but got '{cat}' for Dockerfile."
        )

    def test_categorises_python_files(self, pr_analyser):
        """Python files must be categorised as Application."""
        cat = pr_analyser._categorise_file("scripts/scanner.py")
        assert cat == pr_analyser.FileCategory.APPLICATION, (
            f"Expected 'Application' but got '{cat}' for scanner.py."
        )

    def test_categorises_markdown_as_docs(self, pr_analyser):
        """Markdown files must be categorised as Documentation."""
        cat = pr_analyser._categorise_file("README.md")
        assert cat == pr_analyser.FileCategory.DOCUMENTATION, (
            f"Expected 'Documentation' but got '{cat}' for README.md."
        )

    def test_risk_weights_are_correct(self, pr_analyser):
        """Infrastructure and K8s changes should have higher risk than docs."""
        infra_weight = pr_analyser.RISK_WEIGHTS[pr_analyser.FileCategory.INFRASTRUCTURE]
        docs_weight = pr_analyser.RISK_WEIGHTS[pr_analyser.FileCategory.DOCUMENTATION]
        assert infra_weight > docs_weight, (
            f"Infrastructure risk weight ({infra_weight}) should be higher than "
            f"Documentation ({docs_weight})."
        )


# ═══════════════════════════════════════════════════════════════════════════════
# Hooks Existence Tests
# ═══════════════════════════════════════════════════════════════════════════════

@pytest.mark.integration
class TestHooksExist:
    """Tests that hook scripts exist and are executable."""

    def test_pre_tool_hook_exists(self, project_root):
        """pre-tool.sh must exist."""
        hook_path = project_root / "hooks" / "pre-tool.sh"
        assert hook_path.exists(), f"pre-tool.sh not found at {hook_path}"

    def test_pre_tool_hook_is_executable(self, project_root):
        """pre-tool.sh must be executable."""
        import os
        hook_path = project_root / "hooks" / "pre-tool.sh"
        assert os.access(hook_path, os.X_OK), (
            f"pre-tool.sh is not executable. Run: chmod +x {hook_path}"
        )

    def test_pre_commit_hook_exists(self, project_root):
        """pre-commit.sh must exist."""
        hook_path = project_root / "hooks" / "pre-commit.sh"
        assert hook_path.exists(), f"pre-commit.sh not found at {hook_path}"

    def test_pre_commit_hook_is_executable(self, project_root):
        """pre-commit.sh must be executable."""
        import os
        hook_path = project_root / "hooks" / "pre-commit.sh"
        assert os.access(hook_path, os.X_OK), (
            f"pre-commit.sh is not executable. Run: chmod +x {hook_path}"
        )

    def test_pre_tool_blocks_terraform_destroy(self, project_root):
        """pre-tool.sh must exit non-zero for 'terraform destroy'."""
        hook = project_root / "hooks" / "pre-tool.sh"
        result = subprocess.run(
            [str(hook), "terraform destroy -auto-approve"],
            capture_output=True, text=True, timeout=5,
            stdin=subprocess.DEVNULL,  # non-interactive
        )
        assert result.returncode != 0, (
            "pre-tool.sh should BLOCK 'terraform destroy' but exited 0 (success). "
            "The hook must return non-zero for dangerous commands."
        )

    def test_pre_tool_allows_safe_command(self, project_root):
        """pre-tool.sh must exit 0 for safe commands like 'ls -la'."""
        hook = project_root / "hooks" / "pre-tool.sh"
        result = subprocess.run(
            [str(hook), "ls -la"],
            capture_output=True, text=True, timeout=5,
        )
        assert result.returncode == 0, (
            f"pre-tool.sh blocked safe command 'ls -la' (exit {result.returncode}). "
            f"Only dangerous commands should be blocked."
        )
