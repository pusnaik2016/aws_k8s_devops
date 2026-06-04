"""Tool 8: K8s Troubleshooter — Scan K8s manifests for misconfigurations."""

from __future__ import annotations

from pathlib import Path

from core.analyzer import BaseAnalyzer, AnalysisResult, Severity, Category
from core.rules_engine import RulesEngine
from core.file_utils import discover_files, read_file


class K8sTroubleshooter(BaseAnalyzer):
    """Scan Kubernetes YAML manifests for misconfigurations and anti-patterns."""

    name = "K8s Troubleshooter"
    version = "1.0.0"

    def __init__(self):
        super().__init__()
        self.engine = RulesEngine()
        rules_path = Path(__file__).parent.parent / "rules" / "k8s_rules.yaml"
        self.engine.load_file(rules_path)

    def analyze(self, target: str, **kwargs) -> AnalysisResult:
        """Scan K8s manifests for issues."""
        target_path = Path(target)
        extensions = kwargs.get("extensions", [".yaml", ".yml"])

        files = discover_files(target_path, extensions=extensions)
        if not files:
            if target_path.is_file():
                files = [target_path]
            else:
                self._add_finding(
                    "K8S000", Severity.INFO, Category.CONFIGURATION,
                    "No K8s manifests found", f"No YAML files found in {target}",
                )
                return self._build_result(target)

        files_scanned = 0
        for fpath in files:
            content = read_file(fpath)
            # Only scan files that look like K8s manifests
            if "kind:" not in content and "apiVersion:" not in content:
                continue

            matches = self.engine.match_content(content, str(fpath))
            files_scanned += 1
            rel_path = str(fpath.name) if target_path.is_dir() else fpath.name

            for match in matches:
                rule = match["rule"]
                self._add_finding(
                    rule.id, rule.severity, rule.category,
                    rule.title, rule.message,
                    location=rel_path,
                    line_number=match["line_number"],
                    recommendation=rule.recommendation,
                )

        return self._build_result(
            target,
            files_scanned=files_scanned,
            rules_loaded=len(self.engine.rules),
        )
