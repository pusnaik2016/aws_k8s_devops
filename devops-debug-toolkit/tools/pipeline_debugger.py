"""Tool 2: CI/CD Pipeline Debugger — Parse build logs, identify failures."""

from __future__ import annotations

from pathlib import Path

from core.analyzer import BaseAnalyzer, AnalysisResult, Severity, Category
from core.rules_engine import RulesEngine
from core.file_utils import read_file


class PipelineDebugger(BaseAnalyzer):
    """Parse CI/CD pipeline logs and diagnose failures."""

    name = "CI/CD Pipeline Debugger"
    version = "1.0.0"

    def __init__(self):
        super().__init__()
        self.engine = RulesEngine()
        rules_path = Path(__file__).parent.parent / "rules" / "pipeline_patterns.yaml"
        self.engine.load_file(rules_path)

    def analyze(self, target: str, **kwargs) -> AnalysisResult:
        """Analyze a CI/CD pipeline log file for failure patterns."""
        target_path = Path(target)

        if not target_path.exists():
            self._add_finding(
                "PIPE000", Severity.CRITICAL, Category.PIPELINE,
                "Log file not found", f"File not found: {target}",
                recommendation="Provide a valid build log file."
            )
            return self._build_result(target)

        content = read_file(target_path)
        lines = content.split("\n")

        # Basic log analysis
        error_lines = []
        warning_lines = []
        for i, line in enumerate(lines, 1):
            lower = line.lower()
            if any(kw in lower for kw in ["error", "err!", "failed", "fatal", "##[error]"]):
                error_lines.append((i, line.strip()))
            elif any(kw in lower for kw in ["warn", "warning", "deprecated"]):
                warning_lines.append((i, line.strip()))

        # Run rules engine
        matches = self.engine.match_content(content, str(target_path))

        for match in matches:
            rule = match["rule"]
            self._add_finding(
                rule.id, rule.severity, rule.category,
                rule.title, rule.message,
                location=str(target_path.name),
                line_number=match["line_number"],
                recommendation=rule.recommendation,
                matched_text=match["match_text"],
            )

        # Add summary findings
        if not error_lines and not matches:
            self._add_finding(
                "PIPE099", Severity.INFO, Category.PIPELINE,
                "No failures detected",
                "Pipeline log appears clean. No known failure patterns found.",
                location=str(target_path.name),
            )

        # Detect pipeline type
        pipeline_type = self._detect_pipeline_type(content)

        return self._build_result(
            target,
            pipeline_type=pipeline_type,
            total_lines=len(lines),
            error_lines=len(error_lines),
            warning_lines=len(warning_lines),
            first_error=error_lines[0] if error_lines else None,
        )

    def _detect_pipeline_type(self, content: str) -> str:
        """Detect the CI/CD platform from log content."""
        lower = content.lower()
        if "##[error]" in lower or "actions/" in lower:
            return "GitHub Actions"
        elif "gitlab-runner" in lower or "gl-" in lower:
            return "GitLab CI"
        elif "jenkins" in lower or "started by" in lower:
            return "Jenkins"
        elif "circleci" in lower:
            return "CircleCI"
        elif "bitbucket" in lower:
            return "Bitbucket Pipelines"
        return "Unknown"
