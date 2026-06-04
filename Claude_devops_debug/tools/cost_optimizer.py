"""Tool 10: Cost Optimizer — Analyze Terraform for cost optimization opportunities."""

from __future__ import annotations

from pathlib import Path

from core.analyzer import BaseAnalyzer, AnalysisResult, Severity, Category
from core.rules_engine import RulesEngine
from core.file_utils import discover_files, read_file


class CostOptimizer(BaseAnalyzer):
    """Analyze Terraform configs for AWS cost optimization opportunities."""

    name = "Cost Optimizer"
    version = "1.0.0"

    def __init__(self):
        super().__init__()
        self.engine = RulesEngine()
        rules_path = Path(__file__).parent.parent / "rules" / "cost_rules.yaml"
        self.engine.load_file(rules_path)

    def analyze(self, target: str, **kwargs) -> AnalysisResult:
        """Scan Terraform files for cost optimization opportunities."""
        target_path = Path(target)
        extensions = kwargs.get("extensions", [".tf"])

        files = discover_files(target_path, extensions=extensions)
        if not files:
            if target_path.is_file():
                files = [target_path]
            else:
                self._add_finding(
                    "COST000", Severity.INFO, Category.COST,
                    "No Terraform files found", f"No .tf files found in {target}",
                )
                return self._build_result(target)

        files_scanned = 0
        estimated_monthly_savings = 0.0

        for fpath in files:
            content = read_file(fpath)
            matches = self.engine.match_content(content, str(fpath))
            files_scanned += 1
            rel_path = str(fpath.name) if target_path.is_dir() else fpath.name

            for match in matches:
                rule = match["rule"]
                savings = self._estimate_savings(rule.id)
                estimated_monthly_savings += savings

                self._add_finding(
                    rule.id, rule.severity, rule.category,
                    rule.title,
                    f"{rule.message} (Est. savings: ${savings:.0f}/mo)" if savings > 0 else rule.message,
                    location=rel_path,
                    line_number=match["line_number"],
                    recommendation=rule.recommendation,
                    estimated_savings=savings,
                )

        return self._build_result(
            target,
            files_scanned=files_scanned,
            rules_loaded=len(self.engine.rules),
            estimated_monthly_savings=f"${estimated_monthly_savings:.0f}",
        )

    def _estimate_savings(self, rule_id: str) -> float:
        """Rough monthly savings estimate per rule."""
        estimates = {
            "COST001": 150.0,   # Right-sizing large instance
            "COST002": 30.0,    # Newer generation (better price-performance)
            "COST003": 20.0,    # gp2 → gp3 per volume
            "COST004": 32.0,    # NAT Gateway
            "COST005": 15.0,    # S3 lifecycle
            "COST006": 80.0,    # Spot/RI savings
            "COST007": 3.65,    # Unused EIP
            "COST008": 200.0,   # Multi-AZ in non-prod
            "COST009": 100.0,   # Auto-scaling savings
            "COST010": 5.0,     # Log retention
        }
        return estimates.get(rule_id, 0.0)
