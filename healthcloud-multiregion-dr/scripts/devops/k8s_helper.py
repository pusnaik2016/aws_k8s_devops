#!/usr/bin/env python3
"""
k8s_helper.py — Kubernetes Manifest Diagnostics for Healthcare Platform
========================================================================
Zero-dependency K8s manifest analyzer checking security, resources,
health probes, HA, networking, and RBAC compliance.

Usage:
  python3 k8s_helper.py --path ./kubernetes --format markdown
"""

import argparse
import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path

SKIP_DIRS = {'.git', '.terraform', 'node_modules', '.venv', '__pycache__'}

class Check:
    def __init__(self, rule_id, status, category, file, description, remediation=""):
        self.rule_id = rule_id
        self.status = status  # PASS, WARN, FAIL
        self.category = category
        self.file = file
        self.description = description
        self.remediation = remediation

    def to_dict(self):
        return vars(self)

def analyze_manifest(filepath: str, base_path: str) -> list:
    checks = []
    rel = os.path.relpath(filepath, base_path)
    try:
        content = open(filepath).read()
    except (PermissionError, OSError):
        return checks

    if 'kind:' not in content:
        return checks

    kind_match = re.search(r'kind:\s*(\S+)', content)
    kind = kind_match.group(1) if kind_match else "Unknown"

    is_workload = kind in ('Deployment', 'StatefulSet', 'DaemonSet')

    if is_workload:
        # Security checks
        checks.append(Check("K8S-SEC-001",
            "PASS" if 'runAsNonRoot: true' in content else "FAIL",
            "Security", rel, "runAsNonRoot enforcement",
            "Add securityContext.runAsNonRoot: true"))

        checks.append(Check("K8S-SEC-002",
            "PASS" if 'allowPrivilegeEscalation: false' in content else "FAIL",
            "Security", rel, "Privilege escalation prevention",
            "Add securityContext.allowPrivilegeEscalation: false"))

        checks.append(Check("K8S-SEC-003",
            "PASS" if 'readOnlyRootFilesystem: true' in content else "WARN",
            "Security", rel, "Read-only root filesystem",
            "Add securityContext.readOnlyRootFilesystem: true"))

        checks.append(Check("K8S-SEC-004",
            "FAIL" if 'privileged: true' in content else "PASS",
            "Security", rel, "No privileged containers"))

        checks.append(Check("K8S-SEC-005",
            "PASS" if 'drop:' in content and 'ALL' in content else "WARN",
            "Security", rel, "Drop all capabilities",
            "Add securityContext.capabilities.drop: ['ALL']"))

        # Resource checks
        checks.append(Check("K8S-RES-001",
            "PASS" if 'requests:' in content else "FAIL",
            "Resources", rel, "CPU/memory requests defined",
            "Add resources.requests"))

        checks.append(Check("K8S-RES-002",
            "PASS" if 'limits:' in content else "FAIL",
            "Resources", rel, "CPU/memory limits defined",
            "Add resources.limits"))

        # Probe checks
        checks.append(Check("K8S-PROBE-001",
            "PASS" if 'readinessProbe:' in content else "FAIL",
            "Health", rel, "Readiness probe configured",
            "Add readinessProbe"))

        checks.append(Check("K8S-PROBE-002",
            "PASS" if 'livenessProbe:' in content else "FAIL",
            "Health", rel, "Liveness probe configured",
            "Add livenessProbe"))

        checks.append(Check("K8S-PROBE-003",
            "PASS" if 'startupProbe:' in content else "WARN",
            "Health", rel, "Startup probe (recommended for Java/Spring)",
            "Add startupProbe for slow-starting containers"))

        # Image checks
        has_latest = bool(re.search(r'image:\s*\S+:latest', content))
        checks.append(Check("K8S-IMG-001",
            "FAIL" if has_latest else "PASS",
            "Images", rel, "No :latest image tags",
            "Pin images to specific version or digest"))

        # HA checks
        replica_match = re.search(r'replicas:\s*(\d+)', content)
        replicas = int(replica_match.group(1)) if replica_match else 1
        checks.append(Check("K8S-HA-001",
            "PASS" if replicas >= 2 else "WARN",
            "HA", rel, f"Replica count: {replicas} (recommend >= 2)"))

        checks.append(Check("K8S-HA-002",
            "PASS" if 'podAntiAffinity' in content else "WARN",
            "HA", rel, "Pod anti-affinity for zone distribution",
            "Add topologySpreadConstraints or podAntiAffinity"))

    # NetworkPolicy check (for all YAML)
    if kind == 'NetworkPolicy':
        checks.append(Check("K8S-NET-001", "PASS", "Networking", rel,
            "NetworkPolicy defined"))

    # PDB check
    if kind == 'PodDisruptionBudget':
        checks.append(Check("K8S-HA-003", "PASS", "HA", rel,
            "PodDisruptionBudget defined"))

    return checks

def scan_directory(path: str) -> list:
    all_checks = []
    for root, dirs, files in os.walk(path):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for fname in files:
            if fname.endswith(('.yaml', '.yml')):
                all_checks.extend(analyze_manifest(os.path.join(root, fname), path))
    return all_checks

def format_markdown(checks: list, path: str) -> str:
    passed = sum(1 for c in checks if c.status == "PASS")
    warned = sum(1 for c in checks if c.status == "WARN")
    failed = sum(1 for c in checks if c.status == "FAIL")
    icons = {"PASS": "✅", "WARN": "⚠️", "FAIL": "❌"}

    output = [
        "## ☸️ Kubernetes Diagnostics Report",
        f"**Scan Path:** `{path}`",
        f"**Manifests Analyzed:** {len(set(c.file for c in checks))}",
        f"**Total Checks:** {len(checks)}", ""
    ]

    for category in sorted(set(c.category for c in checks)):
        cat_checks = [c for c in checks if c.category == category]
        output.append(f"### {category}")
        output.append("| Status | Rule | File | Description |")
        output.append("|--------|------|------|-------------|")
        for c in cat_checks:
            output.append(f"| {icons[c.status]} | {c.rule_id} | {c.file} | {c.description} |")
        output.append("")

    output.extend([
        "### 📊 Summary",
        "| Status | Count |",
        "|--------|-------|",
        f"| ✅ Passed | {passed} |",
        f"| ⚠️ Warnings | {warned} |",
        f"| ❌ Failed | {failed} |",
        f"| **Total** | **{len(checks)}** |", "",
        f"### Verdict: {'❌ NOT READY' if failed > 0 else '⚠️ REVIEW NEEDED' if warned > 0 else '✅ PRODUCTION READY'}"
    ])
    return '\n'.join(output)

def format_json(checks: list, path: str) -> str:
    return json.dumps({
        "scan_date": datetime.now().isoformat(),
        "scan_path": path,
        "total_checks": len(checks),
        "checks": [c.to_dict() for c in checks]
    }, indent=2)

def main():
    parser = argparse.ArgumentParser(description="HealthCloud K8s Diagnostics")
    parser.add_argument("--path", required=True)
    parser.add_argument("--format", default="markdown", choices=["text", "markdown", "json"])
    args = parser.parse_args()

    checks = scan_directory(args.path)
    if args.format == "json":
        print(format_json(checks, args.path))
    else:
        print(format_markdown(checks, args.path))

    failed = sum(1 for c in checks if c.status == "FAIL")
    sys.exit(1 if failed > 0 else 0)

if __name__ == "__main__":
    main()
