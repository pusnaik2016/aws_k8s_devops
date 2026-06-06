#!/usr/bin/env python3
"""
pr_analyser.py — Pull Request Analysis Engine
================================================
Performs comprehensive PR diff analysis, categorising changed files,
assessing risk levels, and generating structured review reports.

Features:
  • Git diff parsing and file categorisation
  • Risk scoring based on file types and change volume
  • Integration hooks for sec_scanner, tf_helper, and k8s_helper
  • Structured report generation (text, markdown, JSON)

Author : Pushparaj Naik
Version: 1.0.0

Usage:
    python3 pr_analyser.py --base main [--format text|markdown|json]
    python3 pr_analyser.py --files file1.tf file2.yaml [--format markdown]
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional


# ═══════════════════════════════════════════════════════════════════════════════
# Data Models
# ═══════════════════════════════════════════════════════════════════════════════

class FileCategory:
    INFRASTRUCTURE = "Infrastructure"
    KUBERNETES = "Kubernetes"
    APPLICATION = "Application"
    CICD = "CI/CD"
    DOCKER = "Docker"
    DOCUMENTATION = "Documentation"
    CONFIGURATION = "Configuration"
    UNKNOWN = "Other"


CATEGORY_MAP = {
    '.tf': FileCategory.INFRASTRUCTURE,
    '.tfvars': FileCategory.INFRASTRUCTURE,
    '.hcl': FileCategory.INFRASTRUCTURE,
    'Dockerfile': FileCategory.DOCKER,
    'Containerfile': FileCategory.DOCKER,
    'docker-compose': FileCategory.DOCKER,
    '.py': FileCategory.APPLICATION,
    '.js': FileCategory.APPLICATION,
    '.ts': FileCategory.APPLICATION,
    '.jsx': FileCategory.APPLICATION,
    '.tsx': FileCategory.APPLICATION,
    '.go': FileCategory.APPLICATION,
    '.java': FileCategory.APPLICATION,
    '.rs': FileCategory.APPLICATION,
    '.md': FileCategory.DOCUMENTATION,
    '.txt': FileCategory.DOCUMENTATION,
    '.rst': FileCategory.DOCUMENTATION,
    '.json': FileCategory.CONFIGURATION,
    '.toml': FileCategory.CONFIGURATION,
    '.ini': FileCategory.CONFIGURATION,
    '.cfg': FileCategory.CONFIGURATION,
    '.env': FileCategory.CONFIGURATION,
    '.sh': FileCategory.APPLICATION,
    '.bash': FileCategory.APPLICATION,
}

# Risk weights by category
RISK_WEIGHTS = {
    FileCategory.INFRASTRUCTURE: 5,
    FileCategory.KUBERNETES: 4,
    FileCategory.CICD: 4,
    FileCategory.DOCKER: 3,
    FileCategory.APPLICATION: 2,
    FileCategory.CONFIGURATION: 3,
    FileCategory.DOCUMENTATION: 1,
    FileCategory.UNKNOWN: 1,
}


@dataclass
class ChangedFile:
    path: str
    category: str
    additions: int = 0
    deletions: int = 0
    risk_score: float = 0.0

    @property
    def total_changes(self) -> int:
        return self.additions + self.deletions


@dataclass
class PRReport:
    base_branch: str
    head_info: str = ""
    changed_files: list = field(default_factory=list)
    total_additions: int = 0
    total_deletions: int = 0
    risk_score: float = 0.0
    categories: dict = field(default_factory=dict)
    recommendations: list = field(default_factory=list)
    warnings: list = field(default_factory=list)

    @property
    def risk_level(self) -> str:
        if self.risk_score > 50:
            return "HIGH"
        if self.risk_score > 20:
            return "MEDIUM"
        return "LOW"

    @property
    def total_files(self) -> int:
        return len(self.changed_files)


# ═══════════════════════════════════════════════════════════════════════════════
# Git Integration
# ═══════════════════════════════════════════════════════════════════════════════

def _run_git(args: list[str]) -> Optional[str]:
    """Run a git command and return stdout."""
    try:
        result = subprocess.run(
            ['git'] + args,
            capture_output=True, text=True, timeout=30,
        )
        if result.returncode == 0:
            return result.stdout.strip()
        return None
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return None


def get_changed_files_from_git(base: str) -> list[ChangedFile]:
    """Get changed files by comparing with a base branch."""
    files = []

    # Try origin/base first, then just base
    diff_output = _run_git(['diff', '--numstat', f'origin/{base}...HEAD'])
    if diff_output is None:
        diff_output = _run_git(['diff', '--numstat', f'{base}...HEAD'])
    if diff_output is None:
        # Fallback: show recent changes
        diff_output = _run_git(['diff', '--numstat', 'HEAD~5', 'HEAD'])
    if diff_output is None:
        # Final fallback: just list tracked files
        diff_output = _run_git(['diff', '--numstat', '--cached'])

    if diff_output:
        for line in diff_output.split('\n'):
            if not line.strip():
                continue
            parts = line.split('\t')
            if len(parts) >= 3:
                adds = int(parts[0]) if parts[0] != '-' else 0
                dels = int(parts[1]) if parts[1] != '-' else 0
                filepath = parts[2]
                category = _categorise_file(filepath)
                risk = (adds + dels) * RISK_WEIGHTS.get(category, 1) * 0.1
                files.append(ChangedFile(
                    path=filepath, category=category,
                    additions=adds, deletions=dels, risk_score=risk))

    return files


def get_changed_files_from_list(file_list: list[str]) -> list[ChangedFile]:
    """Create ChangedFile entries from an explicit file list."""
    files = []
    for fp in file_list:
        if not os.path.exists(fp):
            continue
        category = _categorise_file(fp)
        # Count lines as a proxy for changes
        try:
            with open(fp, 'r', encoding='utf-8', errors='ignore') as f:
                line_count = len(f.readlines())
        except (PermissionError, OSError):
            line_count = 0
        risk = line_count * RISK_WEIGHTS.get(category, 1) * 0.05
        files.append(ChangedFile(
            path=fp, category=category,
            additions=line_count, deletions=0, risk_score=risk))
    return files


def _categorise_file(filepath: str) -> str:
    """Determine file category from path and extension."""
    path = Path(filepath)

    # Check path-based patterns
    path_str = str(path).lower()
    if '.github/workflows/' in path_str:
        return FileCategory.CICD
    if '/k8s/' in path_str or '/kubernetes/' in path_str or '/manifests/' in path_str:
        return FileCategory.KUBERNETES
    if '/infra/' in path_str or '/terraform/' in path_str or '/modules/' in path_str:
        return FileCategory.INFRASTRUCTURE
    if '/argocd/' in path_str:
        return FileCategory.KUBERNETES

    # Check filename patterns
    name = path.name
    for pattern, cat in CATEGORY_MAP.items():
        if name.startswith(pattern) or name.endswith(pattern):
            return cat

    # Check YAML files in k8s-like directories
    if path.suffix in {'.yaml', '.yml'}:
        # Try to detect K8s manifests by content
        try:
            with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                head = f.read(500)
                if 'apiVersion:' in head and 'kind:' in head:
                    return FileCategory.KUBERNETES
        except (PermissionError, OSError):
            pass
        return FileCategory.CONFIGURATION

    # Extension-based lookup
    return CATEGORY_MAP.get(path.suffix, FileCategory.UNKNOWN)


# ═══════════════════════════════════════════════════════════════════════════════
# Analysis Engine
# ═══════════════════════════════════════════════════════════════════════════════

def analyse_pr(base: str, file_list: Optional[list[str]] = None) -> PRReport:
    """Perform comprehensive PR analysis."""
    report = PRReport(base_branch=base)

    # Get changed files
    if file_list:
        report.changed_files = get_changed_files_from_list(file_list)
    else:
        report.changed_files = get_changed_files_from_git(base)

    # Get HEAD info
    head_info = _run_git(['log', '--oneline', '-1'])
    report.head_info = head_info or "Unknown"

    # Aggregate metrics
    for f in report.changed_files:
        report.total_additions += f.additions
        report.total_deletions += f.deletions
        report.risk_score += f.risk_score
        report.categories.setdefault(f.category, []).append(f.path)

    # Generate recommendations
    if FileCategory.INFRASTRUCTURE in report.categories:
        report.recommendations.append(
            "🏗️ Infrastructure changes detected — run `python3 scripts/tf_helper.py --path ./infra --format markdown`")
    if FileCategory.KUBERNETES in report.categories:
        report.recommendations.append(
            "🎯 Kubernetes changes detected — run `python3 scripts/k8s_helper.py --path ./k8s --format markdown`")
    if FileCategory.DOCKER in report.categories:
        report.recommendations.append(
            "🐳 Docker changes detected — verify base image pins and USER directives")
    if FileCategory.CICD in report.categories:
        report.recommendations.append(
            "⚙️ CI/CD changes detected — verify permissions blocks and action version pins")

    # Risk-based warnings
    if report.risk_score > 50:
        report.warnings.append("⚠️ HIGH RISK: Large change set — consider splitting into smaller PRs")
    if report.total_files > 20:
        report.warnings.append("⚠️ Many files changed — thorough review recommended")
    if any(f.total_changes > 500 for f in report.changed_files):
        large_files = [f.path for f in report.changed_files if f.total_changes > 500]
        report.warnings.append(f"⚠️ Large file changes: {', '.join(large_files)}")

    # Always recommend security scan
    report.recommendations.append(
        "🔒 Run security scan: `python3 scripts/sec_scanner.py --path . --format markdown`")

    return report


# ═══════════════════════════════════════════════════════════════════════════════
# Formatters
# ═══════════════════════════════════════════════════════════════════════════════

def format_markdown(report: PRReport) -> str:
    lines = [
        "## 📋 Pull Request Analysis Report",
        f"**Base Branch:** `{report.base_branch}`",
        f"**HEAD:** `{report.head_info}`",
        f"**Risk Level:** {'🔴' if report.risk_level == 'HIGH' else '🟡' if report.risk_level == 'MEDIUM' else '🟢'} {report.risk_level}",
        "",
    ]

    # Category summary
    lines.extend([
        "### 📁 Changes by Category",
        "",
        "| Category | Files Changed | Risk Weight |",
        "|----------|-------------|-------------|",
    ])
    for cat, files in sorted(report.categories.items()):
        weight = RISK_WEIGHTS.get(cat, 1)
        lines.append(f"| {cat} | {len(files)} | {'🔴' * min(weight, 5)} ({weight}/5) |")
    lines.append("")

    # Changed files table
    lines.extend([
        "### 📝 Changed Files",
        "",
        "| File | Category | +Adds | -Dels | Risk |",
        "|------|----------|-------|-------|------|",
    ])
    for f in sorted(report.changed_files, key=lambda x: -x.risk_score):
        risk_bar = '█' * min(int(f.risk_score / 5) + 1, 10)
        lines.append(
            f"| `{os.path.basename(f.path)}` | {f.category} | +{f.additions} | -{f.deletions} | {risk_bar} |")
    lines.append("")

    # Warnings
    if report.warnings:
        lines.extend(["### ⚠️ Warnings", ""])
        for w in report.warnings:
            lines.append(f"- {w}")
        lines.append("")

    # Recommendations
    if report.recommendations:
        lines.extend(["### 💡 Recommended Actions", ""])
        for r in report.recommendations:
            lines.append(f"- {r}")
        lines.append("")

    # Summary
    lines.extend([
        "### 📊 Summary",
        "",
        "| Metric | Value |",
        "|--------|-------|",
        f"| Total Files Changed | {report.total_files} |",
        f"| Lines Added | +{report.total_additions} |",
        f"| Lines Deleted | -{report.total_deletions} |",
        f"| Risk Score | {report.risk_score:.1f} |",
        f"| Risk Level | {report.risk_level} |",
    ])

    return '\n'.join(lines)


def format_text(report: PRReport) -> str:
    lines = [
        "=" * 70,
        "  PULL REQUEST ANALYSIS REPORT",
        "=" * 70,
        f"  Base:  {report.base_branch}",
        f"  HEAD:  {report.head_info}",
        f"  Risk:  {report.risk_level} ({report.risk_score:.1f})",
        f"  Files: {report.total_files}",
        f"  +{report.total_additions} / -{report.total_deletions}",
        "=" * 70, "",
    ]

    for cat, files in sorted(report.categories.items()):
        lines.append(f"  [{cat}] ({len(files)} files)")
        for fp in files:
            lines.append(f"    - {fp}")
        lines.append("")

    if report.warnings:
        lines.append("  WARNINGS:")
        for w in report.warnings:
            lines.append(f"    {w}")
        lines.append("")

    if report.recommendations:
        lines.append("  RECOMMENDED ACTIONS:")
        for r in report.recommendations:
            lines.append(f"    {r}")
        lines.append("")

    lines.extend(["-" * 70])
    return '\n'.join(lines)


def format_json(report: PRReport) -> str:
    return json.dumps({
        "base_branch": report.base_branch,
        "head_info": report.head_info,
        "risk_level": report.risk_level,
        "risk_score": report.risk_score,
        "summary": {
            "total_files": report.total_files,
            "additions": report.total_additions,
            "deletions": report.total_deletions,
        },
        "categories": {k: v for k, v in report.categories.items()},
        "changed_files": [
            {"path": f.path, "category": f.category,
             "additions": f.additions, "deletions": f.deletions,
             "risk_score": f.risk_score}
            for f in report.changed_files
        ],
        "warnings": report.warnings,
        "recommendations": report.recommendations,
    }, indent=2)


# ═══════════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════════

def main():
    parser = argparse.ArgumentParser(
        description="Claude DevOps — Pull Request Analysis Engine",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 pr_analyser.py --base main --format markdown
  python3 pr_analyser.py --files infra/main.tf k8s/backend.yaml --format text
        """,
    )
    parser.add_argument('--base', default='main', help='Base branch to compare against (default: main)')
    parser.add_argument('--files', nargs='+', help='Explicit list of files to analyse (instead of git diff)')
    parser.add_argument('--format', default='text', dest='output_format',
                        choices=['text', 'markdown', 'json'])

    args = parser.parse_args()

    report = analyse_pr(args.base, args.files)

    formatter = {'text': format_text, 'markdown': format_markdown, 'json': format_json}
    print(formatter[args.output_format](report))


if __name__ == '__main__':
    main()
