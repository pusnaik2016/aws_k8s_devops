"""YAML-based rules engine for pattern matching across all tools."""

from __future__ import annotations

import re
import yaml
from pathlib import Path
from dataclasses import dataclass
from typing import List, Dict, Any, Optional

from core.analyzer import Severity, Category


@dataclass
class Rule:
    """A single detection rule loaded from YAML."""
    id: str
    title: str
    severity: Severity
    category: Category
    pattern: str          # regex pattern
    message: str
    recommendation: str
    file_types: List[str]  # e.g., [".tf", ".yaml"]
    enabled: bool = True
    negate: bool = False   # True = flag when pattern is NOT found

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "Rule":
        return cls(
            id=data["id"],
            title=data["title"],
            severity=Severity(data.get("severity", "MEDIUM")),
            category=Category(data.get("category", "Best Practice")),
            pattern=data.get("pattern", ""),
            message=data.get("message", ""),
            recommendation=data.get("recommendation", ""),
            file_types=data.get("file_types", []),
            enabled=data.get("enabled", True),
            negate=data.get("negate", False),
        )


class RulesEngine:
    """Load and match rules from YAML definition files."""

    def __init__(self):
        self.rules: List[Rule] = []

    def load_file(self, path: str | Path) -> int:
        """Load rules from a YAML file. Returns count loaded."""
        path = Path(path)
        if not path.exists():
            return 0
        with open(path, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f) or {}
        rules_list = data.get("rules", [])
        for rd in rules_list:
            rule = Rule.from_dict(rd)
            if rule.enabled:
                self.rules.append(rule)
        return len(rules_list)

    def load_directory(self, directory: str | Path) -> int:
        """Load all .yaml/.yml rule files from a directory."""
        directory = Path(directory)
        count = 0
        if directory.is_dir():
            for f in sorted(directory.glob("*.yaml")) + sorted(directory.glob("*.yml")):
                count += self.load_file(f)
        return count

    def match_content(
        self, content: str, filename: str = ""
    ) -> List[Dict[str, Any]]:
        """Run all rules against text content. Returns list of matches."""
        matches = []
        file_ext = Path(filename).suffix if filename else ""

        for rule in self.rules:
            # filter by file type if specified
            if rule.file_types and file_ext and file_ext not in rule.file_types:
                continue

            if not rule.pattern:
                continue

            try:
                found = list(re.finditer(rule.pattern, content, re.MULTILINE | re.IGNORECASE))
            except re.error:
                continue

            if rule.negate:
                if not found:
                    matches.append({
                        "rule": rule,
                        "match_text": "",
                        "line_number": 0,
                    })
            else:
                for m in found:
                    line_num = content[:m.start()].count("\n") + 1
                    matches.append({
                        "rule": rule,
                        "match_text": m.group(0).strip()[:120],
                        "line_number": line_num,
                    })

        return matches

    def get_rules_for_ext(self, ext: str) -> List[Rule]:
        """Get rules applicable to a file extension."""
        return [r for r in self.rules if not r.file_types or ext in r.file_types]
