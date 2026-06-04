"""Tool 3: Security Scanner — Scan IaC files for security violations."""

from __future__ import annotations

from pathlib import Path

from core.analyzer import BaseAnalyzer, AnalysisResult, Severity, Category
from core.rules_engine import RulesEngine
from core.file_utils import discover_files, read_file


class SecurityScanner(BaseAnalyzer):
    """Scan Terraform and IaC files for security violations."""

    name = "Security Scanner"
    version = "1.0.0"

    def __init__(self):
        super().__init__()
        self.engine = RulesEngine()
        rules_path = Path(__file__).parent.parent / "rules" / "security_rules.yaml"
        self.engine.load_file(rules_path)

    def analyze(self, target: str, **kwargs) -> AnalysisResult:
        """Scan files for security issues."""
        target_path = Path(target)
        extensions = kwargs.get("extensions", [".tf", ".yaml", ".yml", ".json"])

        files = discover_files(target_path, extensions=extensions)
        if not files:
            self._add_finding(
                "SEC000", Severity.INFO, Category.SECURITY,
                "No scannable files found",
                f"No files with extensions {extensions} found in {target}",
                recommendation="Provide a directory or file with Terraform/YAML configs."
            )
            return self._build_result(target)

        files_scanned = 0
        for fpath in files:
            content = read_file(fpath)
            matches = self.engine.match_content(content, str(fpath))
            files_scanned += 1

            for match in matches:
                rule = match["rule"]
                rel_path = str(fpath.relative_to(target_path)) if target_path.is_dir() else fpath.name
                self._add_finding(
                    rule.id, rule.severity, rule.category,
                    rule.title, rule.message,
                    location=rel_path,
                    line_number=match["line_number"],
                    recommendation=rule.recommendation,
                    matched_text=match["match_text"],
                )

        return self._build_result(
            target,
            files_scanned=files_scanned,
            rules_loaded=len(self.engine.rules),
        )
