"""Base analyzer framework and Finding model for all DevOps tools."""

from __future__ import annotations

import json
from dataclasses import dataclass, field, asdict
from enum import Enum
from typing import List, Optional, Dict, Any
from pathlib import Path


class Severity(Enum):
    """Finding severity levels."""
    CRITICAL = "CRITICAL"
    HIGH = "HIGH"
    MEDIUM = "MEDIUM"
    LOW = "LOW"
    INFO = "INFO"

    @property
    def weight(self) -> int:
        return {"CRITICAL": 5, "HIGH": 4, "MEDIUM": 3, "LOW": 2, "INFO": 1}[self.value]

    def __lt__(self, other):
        if isinstance(other, Severity):
            return self.weight < other.weight
        return NotImplemented


class Category(Enum):
    """Finding categories across all tools."""
    SECURITY = "Security"
    PERFORMANCE = "Performance"
    RELIABILITY = "Reliability"
    COST = "Cost"
    COMPLIANCE = "Compliance"
    BEST_PRACTICE = "Best Practice"
    CONFIGURATION = "Configuration"
    NETWORKING = "Networking"
    STORAGE = "Storage"
    OBSERVABILITY = "Observability"
    MODERNIZATION = "Modernization"
    PIPELINE = "Pipeline"
    INCIDENT = "Incident"


@dataclass
class Finding:
    """A single finding from any analyzer tool."""
    rule_id: str
    severity: Severity
    category: Category
    title: str
    message: str
    location: str = ""
    line_number: int = 0
    recommendation: str = ""
    metadata: Dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> Dict[str, Any]:
        d = asdict(self)
        d["severity"] = self.severity.value
        d["category"] = self.category.value
        return d


@dataclass
class AnalysisResult:
    """Complete result from an analyzer run."""
    tool_name: str
    tool_version: str
    target: str
    findings: List[Finding] = field(default_factory=list)
    summary: Dict[str, Any] = field(default_factory=dict)
    metadata: Dict[str, Any] = field(default_factory=dict)

    @property
    def passed(self) -> bool:
        return not any(
            f.severity in (Severity.CRITICAL, Severity.HIGH) for f in self.findings
        )

    @property
    def severity_counts(self) -> Dict[str, int]:
        counts = {s.value: 0 for s in Severity}
        for f in self.findings:
            counts[f.severity.value] += 1
        return counts

    @property
    def category_counts(self) -> Dict[str, int]:
        counts: Dict[str, int] = {}
        for f in self.findings:
            cat = f.category.value
            counts[cat] = counts.get(cat, 0) + 1
        return counts

    def to_dict(self) -> Dict[str, Any]:
        return {
            "tool_name": self.tool_name,
            "tool_version": self.tool_version,
            "target": self.target,
            "passed": self.passed,
            "total_findings": len(self.findings),
            "severity_counts": self.severity_counts,
            "category_counts": self.category_counts,
            "findings": [f.to_dict() for f in self.findings],
            "summary": self.summary,
            "metadata": self.metadata,
        }

    def to_json(self, indent: int = 2) -> str:
        return json.dumps(self.to_dict(), indent=indent, default=str)


class BaseAnalyzer:
    """Base class for all analyzer tools.

    Subclasses must implement:
      - name: str
      - version: str
      - analyze(target: str, **kwargs) -> AnalysisResult
    """

    name: str = "base"
    version: str = "1.0.0"

    def __init__(self):
        self._findings: List[Finding] = []

    def _add_finding(
        self,
        rule_id: str,
        severity: Severity,
        category: Category,
        title: str,
        message: str,
        location: str = "",
        line_number: int = 0,
        recommendation: str = "",
        **metadata,
    ):
        self._findings.append(
            Finding(
                rule_id=rule_id,
                severity=severity,
                category=category,
                title=title,
                message=message,
                location=location,
                line_number=line_number,
                recommendation=recommendation,
                metadata=metadata,
            )
        )

    def _build_result(self, target: str, **extra_summary) -> AnalysisResult:
        result = AnalysisResult(
            tool_name=self.name,
            tool_version=self.version,
            target=str(target),
            findings=sorted(self._findings, key=lambda f: f.severity, reverse=True),
            summary=extra_summary,
        )
        self._findings = []  # reset for next run
        return result

    def analyze(self, target: str, **kwargs) -> AnalysisResult:
        raise NotImplementedError("Subclasses must implement analyze()")
