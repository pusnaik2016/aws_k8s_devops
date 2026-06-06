"""Tool 5: Server Config Analyzer — Validate Nginx, Apache, systemd configs."""

from __future__ import annotations

from pathlib import Path

from core.analyzer import BaseAnalyzer, AnalysisResult, Severity, Category
from core.rules_engine import RulesEngine
from core.file_utils import discover_files, read_file


class ServerConfigAnalyzer(BaseAnalyzer):
    """Validate server configuration files for security and best practices."""

    name = "Server Config Analyzer"
    version = "1.0.0"

    def __init__(self):
        super().__init__()
        self.engine = RulesEngine()
        rules_path = Path(__file__).parent.parent / "rules" / "server_config_rules.yaml"
        self.engine.load_file(rules_path)

    def analyze(self, target: str, **kwargs) -> AnalysisResult:
        """Analyze server configuration files."""
        target_path = Path(target)
        extensions = kwargs.get("extensions", [".conf", ".service", ".cfg"])

        files = discover_files(target_path, extensions=extensions)
        if not files:
            # Try the target as a single file regardless of extension
            if target_path.is_file():
                files = [target_path]
            else:
                self._add_finding(
                    "SRV000", Severity.INFO, Category.CONFIGURATION,
                    "No config files found",
                    f"No server config files found in {target}",
                    recommendation="Provide .conf, .service, or .cfg files."
                )
                return self._build_result(target)

        files_scanned = 0
        for fpath in files:
            content = read_file(fpath)
            matches = self.engine.match_content(content, str(fpath))
            files_scanned += 1

            # Detect server type
            server_type = self._detect_server_type(content, fpath.name)

            for match in matches:
                rule = match["rule"]
                rel_path = str(fpath.name)
                self._add_finding(
                    rule.id, rule.severity, rule.category,
                    rule.title, rule.message,
                    location=rel_path,
                    line_number=match["line_number"],
                    recommendation=rule.recommendation,
                    server_type=server_type,
                )

        return self._build_result(
            target,
            files_scanned=files_scanned,
            rules_loaded=len(self.engine.rules),
        )

    def _detect_server_type(self, content: str, filename: str) -> str:
        """Detect the server type from content or filename."""
        lower = content.lower()
        fname = filename.lower()
        if "nginx" in fname or "worker_processes" in lower:
            return "Nginx"
        elif "apache" in fname or "ServerRoot" in content:
            return "Apache"
        elif "[Service]" in content or fname.endswith(".service"):
            return "Systemd"
        return "Unknown"
