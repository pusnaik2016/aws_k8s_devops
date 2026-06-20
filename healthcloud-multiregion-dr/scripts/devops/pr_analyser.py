#!/usr/bin/env python3
"""
pr_analyser.py — Git Diff Analysis & Risk Scoring for PR Reviews
================================================================
Usage:
  python3 pr_analyser.py --base main --format markdown
  python3 pr_analyser.py --files terraform/aws/eks/main.tf kubernetes/apps/patient-service/deployment.yaml --format json
"""

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import datetime
from collections import defaultdict

CATEGORIES = {
    '.tf': 'Infrastructure',
    '.yaml': 'Kubernetes',
    '.yml': 'Kubernetes',
    'Dockerfile': 'Docker',
    '.py': 'Application',
    '.java': 'Application',
    '.md': 'Documentation',
    '.sh': 'Scripts',
}

RISK_WEIGHTS = {
    'Infrastructure': 3,
    'Kubernetes': 2,
    'Docker': 2,
    'CI/CD': 3,
    'Application': 1,
    'Documentation': 0,
    'Scripts': 1,
}

def categorize_file(filepath: str) -> str:
    if '.github/workflows' in filepath:
        return 'CI/CD'
    base = os.path.basename(filepath)
    if base in ('Dockerfile', 'Dockerfile.dev', 'Dockerfile.prod'):
        return 'Docker'
    ext = os.path.splitext(filepath)[1]
    return CATEGORIES.get(ext, 'Other')

def get_diff_files(base_branch: str) -> list:
    try:
        result = subprocess.run(
            ['git', 'diff', '--name-only', base_branch],
            capture_output=True, text=True, check=True
        )
        return [f.strip() for f in result.stdout.strip().split('\n') if f.strip()]
    except subprocess.CalledProcessError:
        return []

def get_diff_stats(base_branch: str) -> dict:
    try:
        result = subprocess.run(
            ['git', 'diff', '--stat', base_branch],
            capture_output=True, text=True, check=True
        )
        return {'raw': result.stdout}
    except subprocess.CalledProcessError:
        return {'raw': 'Unable to get diff stats'}

def analyze_files(files: list) -> dict:
    by_category = defaultdict(list)
    for f in files:
        by_category[categorize_file(f)].append(f)

    total_risk = sum(RISK_WEIGHTS.get(cat, 1) * len(fls) for cat, fls in by_category.items())
    risk_level = "LOW" if total_risk < 5 else "MEDIUM" if total_risk < 15 else "HIGH" if total_risk < 30 else "CRITICAL"

    return {
        'total_files': len(files),
        'by_category': dict(by_category),
        'risk_score': total_risk,
        'risk_level': risk_level,
    }

def format_markdown(analysis: dict, base: str) -> str:
    icons = {"Infrastructure": "🏗️", "Kubernetes": "☸️", "Docker": "🐳",
             "CI/CD": "⚙️", "Application": "💻", "Documentation": "📝",
             "Scripts": "📜", "Other": "📁"}
    risk_icons = {"LOW": "🟢", "MEDIUM": "🟡", "HIGH": "🟠", "CRITICAL": "🔴"}

    output = [
        "## 📋 PR Analysis Report",
        f"**Base Branch:** `{base}`",
        f"**Analysis Date:** {datetime.now().strftime('%Y-%m-%d %H:%M')}",
        f"**Total Changed Files:** {analysis['total_files']}",
        f"**Risk Level:** {risk_icons[analysis['risk_level']]} {analysis['risk_level']} (score: {analysis['risk_score']})", "",
        "### Changed Files by Category", ""
    ]

    for cat, files in sorted(analysis['by_category'].items()):
        icon = icons.get(cat, "📁")
        output.append(f"#### {icon} {cat} ({len(files)} files)")
        for f in files:
            output.append(f"- `{f}`")
        output.append("")

    output.extend([
        "### 🎯 Review Focus",
        f"- **Highest risk:** {max(analysis['by_category'].keys(), key=lambda c: RISK_WEIGHTS.get(c, 0)) if analysis['by_category'] else 'None'}",
        f"- **Infrastructure changes:** {'⚠️ Yes — requires careful review' if 'Infrastructure' in analysis['by_category'] else '✅ None'}",
        f"- **CI/CD changes:** {'⚠️ Yes — verify pipeline security' if 'CI/CD' in analysis['by_category'] else '✅ None'}",
        f"- **DR impact:** {'⚠️ Check Azure DR parity' if any('azure' in f.lower() for files in analysis['by_category'].values() for f in files) else '✅ No Azure changes'}", ""
    ])

    return '\n'.join(output)

def main():
    parser = argparse.ArgumentParser(description="HealthCloud PR Analyser")
    parser.add_argument("--base", default="main", help="Base branch to diff against")
    parser.add_argument("--files", nargs="+", help="Specific files to analyze")
    parser.add_argument("--format", default="markdown", choices=["text", "markdown", "json"])
    args = parser.parse_args()

    files = args.files if args.files else get_diff_files(args.base)
    if not files:
        print("No changed files found." if args.format != "json" else '{"files": [], "risk_level": "NONE"}')
        sys.exit(0)

    analysis = analyze_files(files)

    if args.format == "json":
        print(json.dumps(analysis, indent=2))
    else:
        print(format_markdown(analysis, args.base))

if __name__ == "__main__":
    main()
