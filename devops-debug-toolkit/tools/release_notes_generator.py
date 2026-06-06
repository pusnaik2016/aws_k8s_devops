"""Tool 9: Release Notes Generator — Generate CHANGELOG from git history."""

from __future__ import annotations

import re
from pathlib import Path
from typing import List, Dict
from datetime import datetime

from core.analyzer import BaseAnalyzer, AnalysisResult, Severity, Category
from core.file_utils import get_git_log


# Conventional commit type mapping
COMMIT_TYPES = {
    "feat": ("🚀 Features", "feature"),
    "fix": ("🐛 Bug Fixes", "bugfix"),
    "perf": ("⚡ Performance", "performance"),
    "refactor": ("♻️ Refactoring", "refactor"),
    "docs": ("📚 Documentation", "docs"),
    "test": ("✅ Tests", "test"),
    "ci": ("🔧 CI/CD", "ci"),
    "chore": ("🧹 Chores", "chore"),
    "build": ("📦 Build", "build"),
    "style": ("💄 Style", "style"),
    "infra": ("🏗️ Infrastructure", "infra"),
    "security": ("🔒 Security", "security"),
}

BREAKING_PATTERN = re.compile(r"(?:BREAKING[\s_-]?CHANGE|!:)", re.IGNORECASE)
CONVENTIONAL_PATTERN = re.compile(
    r"^(?P<type>\w+)(?:\((?P<scope>[^)]+)\))?\s*!?\s*:\s*(?P<description>.+)$"
)


class ReleaseNotesGenerator(BaseAnalyzer):
    """Generate structured release notes from git history."""

    name = "Release Notes Generator"
    version = "1.0.0"

    def analyze(self, target: str, **kwargs) -> AnalysisResult:
        """Generate release notes from a git repository."""
        target_path = Path(target)
        max_commits = kwargs.get("max_commits", 50)
        since = kwargs.get("since")
        version = kwargs.get("version", "Unreleased")
        output_path = kwargs.get("output", "reports/CHANGELOG.md")

        commits = get_git_log(target_path, max_commits=max_commits, since=since)

        if not commits:
            # If not a git repo, try parsing a provided log file
            if target_path.is_file():
                commits = self._parse_log_file(target_path)

        if not commits:
            self._add_finding(
                "REL000", Severity.INFO, Category.CONFIGURATION,
                "No commits found",
                f"No git history found at {target}. Ensure it's a git repository.",
                recommendation="Run from a git repository root, or provide a git log file."
            )
            return self._build_result(target)

        # Categorize commits
        categorized = self._categorize_commits(commits)
        changelog = self._render_changelog(categorized, version)

        Path(output_path).parent.mkdir(parents=True, exist_ok=True)
        Path(output_path).write_text(changelog, encoding="utf-8")

        self._add_finding(
            "REL100", Severity.INFO, Category.CONFIGURATION,
            "Release notes generated",
            f"Generated changelog with {len(commits)} commits in {len(categorized)} categories.",
            location=output_path,
        )

        return self._build_result(
            target,
            total_commits=len(commits),
            categories=len(categorized),
            output_file=output_path,
            breaking_changes=sum(1 for c in commits if BREAKING_PATTERN.search(c.get("message", ""))),
        )

    def _parse_log_file(self, path: Path) -> List[Dict]:
        """Parse a text file as commit messages (one per line)."""
        content = path.read_text(encoding="utf-8")
        commits = []
        for i, line in enumerate(content.strip().split("\n")):
            if line.strip():
                commits.append({
                    "hash": f"log-{i:04d}",
                    "short_hash": f"l{i:04d}",
                    "author": "Unknown",
                    "email": "",
                    "date": datetime.now().isoformat(),
                    "message": line.strip(),
                })
        return commits

    def _categorize_commits(self, commits: List[Dict]) -> Dict[str, List]:
        """Categorize commits by conventional commit type."""
        categorized: Dict[str, List] = {}

        for commit in commits:
            msg = commit.get("message", "")
            match = CONVENTIONAL_PATTERN.match(msg)

            if match:
                ctype = match.group("type").lower()
                scope = match.group("scope") or ""
                desc = match.group("description")
            else:
                # Non-conventional commit — put in "Other"
                ctype = "other"
                scope = ""
                desc = msg

            # Check for breaking changes
            is_breaking = bool(BREAKING_PATTERN.search(msg))

            if is_breaking:
                category = "💥 Breaking Changes"
            elif ctype in COMMIT_TYPES:
                category = COMMIT_TYPES[ctype][0]
            else:
                category = "📝 Other Changes"

            if category not in categorized:
                categorized[category] = []

            categorized[category].append({
                "description": desc,
                "scope": scope,
                "hash": commit.get("short_hash", ""),
                "author": commit.get("author", ""),
            })

        return categorized

    def _render_changelog(self, categorized: Dict[str, List], version: str) -> str:
        """Render categorized commits as a markdown changelog."""
        lines = [
            f"# Changelog",
            "",
            f"## [{version}] — {datetime.now().strftime('%Y-%m-%d')}",
            "",
        ]

        # Ensure breaking changes come first
        ordered_categories = sorted(
            categorized.keys(),
            key=lambda k: (0 if "Breaking" in k else 1, k)
        )

        for category in ordered_categories:
            entries = categorized[category]
            lines.append(f"### {category}")
            lines.append("")
            for entry in entries:
                scope_str = f"**{entry['scope']}:** " if entry["scope"] else ""
                hash_str = f" (`{entry['hash']}`)" if entry["hash"] else ""
                lines.append(f"- {scope_str}{entry['description']}{hash_str}")
            lines.append("")

        return "\n".join(lines)
