#!/usr/bin/env python3
"""
k8s_helper.py — Kubernetes Manifest Diagnostics Engine
========================================================
Performs deep structural and security analysis of Kubernetes YAML manifests.
Checks for:
  • Security contexts (runAsNonRoot, privilege escalation, capabilities)
  • Resource requests/limits
  • Health probes (readiness, liveness, startup)
  • Image tag pinning
  • High availability (replicas, PDB, HPA)
  • Networking (services, ingress, network policies)
  • RBAC and ServiceAccount configuration
  • Namespace hygiene

Author : Pushparaj Naik
Version: 1.0.0

Usage:
    python3 k8s_helper.py --path <dir> [--format text|markdown|json]
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Optional


# ═══════════════════════════════════════════════════════════════════════════════
# Data Models
# ═══════════════════════════════════════════════════════════════════════════════

@dataclass
class DiagnosticItem:
    status: str  # PASS, WARN, FAIL
    category: str
    resource: str  # e.g. "Deployment/backend"
    check: str
    detail: str
    file: str


@dataclass
class WorkloadSummary:
    name: str
    kind: str
    namespace: str
    replicas: int
    has_resources: bool
    has_limits: bool
    has_readiness: bool
    has_liveness: bool
    has_startup: bool
    runs_as_non_root: bool
    no_privilege_escalation: bool
    read_only_root_fs: bool
    images: list
    file: str

    @property
    def security_status(self) -> str:
        if not self.runs_as_non_root or not self.no_privilege_escalation:
            return "FAIL"
        return "PASS"

    @property
    def resource_status(self) -> str:
        if not self.has_resources or not self.has_limits:
            return "FAIL"
        return "PASS"

    @property
    def probe_status(self) -> str:
        if not self.has_readiness or not self.has_liveness:
            return "WARN"
        return "PASS"


@dataclass
class K8sReport:
    scan_path: str
    manifests_analysed: int = 0
    workloads: list = field(default_factory=list)
    diagnostics: list = field(default_factory=list)
    namespaces: set = field(default_factory=set)
    services: list = field(default_factory=list)
    network_policies: list = field(default_factory=list)
    has_pdb: bool = False
    has_hpa: bool = False
    has_rbac: bool = False

    @property
    def pass_count(self) -> int:
        return sum(1 for d in self.diagnostics if d.status == "PASS")

    @property
    def warn_count(self) -> int:
        return sum(1 for d in self.diagnostics if d.status == "WARN")

    @property
    def fail_count(self) -> int:
        return sum(1 for d in self.diagnostics if d.status == "FAIL")

    @property
    def verdict(self) -> str:
        if self.fail_count > 5:
            return "NOT READY"
        if self.fail_count > 0 or self.warn_count > 5:
            return "NEEDS WORK"
        return "PRODUCTION-READY"


# ═══════════════════════════════════════════════════════════════════════════════
# YAML Parser (minimal, no dependencies)
# ═══════════════════════════════════════════════════════════════════════════════

def _read_file(path: Path) -> Optional[str]:
    try:
        with open(path, 'r', encoding='utf-8', errors='ignore') as f:
            return f.read()
    except (PermissionError, OSError):
        return None


def _find_yaml_files(root: Path) -> list[Path]:
    skip_dirs = {'.git', '.terraform', 'node_modules', '__pycache__'}
    files = []
    if root.is_file():
        return [root] if root.suffix in {'.yaml', '.yml'} else []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in skip_dirs]
        for fname in filenames:
            fp = Path(dirpath) / fname
            if fp.suffix in {'.yaml', '.yml'}:
                files.append(fp)
    return files


def _extract_field(doc: str, field_name: str) -> Optional[str]:
    """Extract a simple field value from YAML text."""
    match = re.search(rf'^\s*{field_name}:\s*(.+)', doc, re.MULTILINE)
    return match.group(1).strip() if match else None


def _field_exists(doc: str, field_name: str) -> bool:
    return bool(re.search(rf'^\s*{field_name}:', doc, re.MULTILINE))


# ═══════════════════════════════════════════════════════════════════════════════
# Analysis Engine
# ═══════════════════════════════════════════════════════════════════════════════

def analyse_manifests(root: Path) -> K8sReport:
    report = K8sReport(scan_path=str(root))
    yaml_files = _find_yaml_files(root)

    for fp in yaml_files:
        content = _read_file(fp)
        if content is None:
            continue
        if 'apiVersion:' not in content or 'kind:' not in content:
            continue

        report.manifests_analysed += 1
        documents = content.split('---')

        for doc in documents:
            if not doc.strip():
                continue

            kind = _extract_field(doc, 'kind')
            name = _extract_field(doc, 'name')
            namespace = _extract_field(doc, 'namespace') or 'default'

            if not kind or not name:
                continue

            report.namespaces.add(namespace)
            resource_id = f"{kind}/{name}"

            # ─── Workload Analysis ───
            workload_kinds = {'Deployment', 'StatefulSet', 'DaemonSet', 'Job', 'CronJob'}
            if kind in workload_kinds:
                replicas_match = re.search(r'replicas:\s*(\d+)', doc)
                replicas = int(replicas_match.group(1)) if replicas_match else 1

                has_resources = _field_exists(doc, 'resources')
                has_limits = 'limits:' in doc
                has_requests = 'requests:' in doc
                has_readiness = _field_exists(doc, 'readinessProbe')
                has_liveness = _field_exists(doc, 'livenessProbe')
                has_startup = _field_exists(doc, 'startupProbe')
                runs_non_root = 'runAsNonRoot: true' in doc
                no_priv_esc = 'allowPrivilegeEscalation: false' in doc
                read_only_fs = 'readOnlyRootFilesystem: true' in doc

                images = re.findall(r'image:\s*(\S+)', doc)

                workload = WorkloadSummary(
                    name=name, kind=kind, namespace=namespace,
                    replicas=replicas,
                    has_resources=has_resources, has_limits=has_limits,
                    has_readiness=has_readiness, has_liveness=has_liveness,
                    has_startup=has_startup,
                    runs_as_non_root=runs_non_root,
                    no_privilege_escalation=no_priv_esc,
                    read_only_root_fs=read_only_fs,
                    images=images, file=str(fp),
                )
                report.workloads.append(workload)

                # ── Security Checks ──
                report.diagnostics.append(DiagnosticItem(
                    status="PASS" if runs_non_root else "FAIL",
                    category="Security", resource=resource_id,
                    check="runAsNonRoot",
                    detail="Container runs as non-root" if runs_non_root else "Container may run as root",
                    file=str(fp)))

                report.diagnostics.append(DiagnosticItem(
                    status="PASS" if no_priv_esc else "FAIL",
                    category="Security", resource=resource_id,
                    check="allowPrivilegeEscalation",
                    detail="Privilege escalation disabled" if no_priv_esc else "Privilege escalation not explicitly disabled",
                    file=str(fp)))

                report.diagnostics.append(DiagnosticItem(
                    status="PASS" if read_only_fs else "WARN",
                    category="Security", resource=resource_id,
                    check="readOnlyRootFilesystem",
                    detail="Root filesystem is read-only" if read_only_fs else "Root filesystem is writable",
                    file=str(fp)))

                if 'privileged: true' in doc:
                    report.diagnostics.append(DiagnosticItem(
                        status="FAIL", category="Security", resource=resource_id,
                        check="privileged",
                        detail="Container runs in privileged mode",
                        file=str(fp)))

                if 'hostNetwork: true' in doc:
                    report.diagnostics.append(DiagnosticItem(
                        status="FAIL", category="Security", resource=resource_id,
                        check="hostNetwork",
                        detail="Pod uses host network stack",
                        file=str(fp)))

                # ── Resource Checks ──
                report.diagnostics.append(DiagnosticItem(
                    status="PASS" if has_resources else "FAIL",
                    category="Resources", resource=resource_id,
                    check="Resource requests",
                    detail="Resource requests defined" if has_resources else "No resource requests defined",
                    file=str(fp)))

                report.diagnostics.append(DiagnosticItem(
                    status="PASS" if has_limits else "FAIL",
                    category="Resources", resource=resource_id,
                    check="Resource limits",
                    detail="Resource limits defined" if has_limits else "No resource limits defined",
                    file=str(fp)))

                # ── Probe Checks ──
                if kind in {'Deployment', 'StatefulSet', 'DaemonSet'}:
                    report.diagnostics.append(DiagnosticItem(
                        status="PASS" if has_readiness else "WARN",
                        category="Health", resource=resource_id,
                        check="readinessProbe",
                        detail="Readiness probe configured" if has_readiness else "No readiness probe",
                        file=str(fp)))

                    report.diagnostics.append(DiagnosticItem(
                        status="PASS" if has_liveness else "WARN",
                        category="Health", resource=resource_id,
                        check="livenessProbe",
                        detail="Liveness probe configured" if has_liveness else "No liveness probe",
                        file=str(fp)))

                    report.diagnostics.append(DiagnosticItem(
                        status="PASS" if has_startup else "INFO",
                        category="Health", resource=resource_id,
                        check="startupProbe",
                        detail="Startup probe configured" if has_startup else "No startup probe (recommended for slow apps)",
                        file=str(fp)))

                # ── Image Checks ──
                for img in images:
                    if ':latest' in img:
                        report.diagnostics.append(DiagnosticItem(
                            status="FAIL", category="Image", resource=resource_id,
                            check="Image tag",
                            detail=f"Uses :latest tag — {img}",
                            file=str(fp)))
                    elif ':' not in img and '@' not in img:
                        report.diagnostics.append(DiagnosticItem(
                            status="FAIL", category="Image", resource=resource_id,
                            check="Image tag",
                            detail=f"No tag specified — {img}",
                            file=str(fp)))
                    else:
                        report.diagnostics.append(DiagnosticItem(
                            status="PASS", category="Image", resource=resource_id,
                            check="Image tag",
                            detail=f"Pinned — {img}",
                            file=str(fp)))

                # ── HA Checks ──
                if kind in {'Deployment', 'StatefulSet'} and replicas < 2:
                    report.diagnostics.append(DiagnosticItem(
                        status="WARN", category="HA", resource=resource_id,
                        check="Replica count",
                        detail=f"Only {replicas} replica — consider >= 2 for production",
                        file=str(fp)))

            # ── Service ──
            elif kind == 'Service':
                svc_type = _extract_field(doc, 'type') or 'ClusterIP'
                report.services.append({'name': name, 'namespace': namespace, 'type': svc_type})
                report.diagnostics.append(DiagnosticItem(
                    status="PASS", category="Networking", resource=resource_id,
                    check="Service type",
                    detail=f"Service type: {svc_type}",
                    file=str(fp)))

            # ── NetworkPolicy ──
            elif kind == 'NetworkPolicy':
                report.network_policies.append({'name': name, 'namespace': namespace})

            # ── PDB ──
            elif kind == 'PodDisruptionBudget':
                report.has_pdb = True
                report.diagnostics.append(DiagnosticItem(
                    status="PASS", category="HA", resource=resource_id,
                    check="PodDisruptionBudget",
                    detail="PDB configured for high availability",
                    file=str(fp)))

            # ── HPA ──
            elif kind == 'HorizontalPodAutoscaler':
                report.has_hpa = True
                report.diagnostics.append(DiagnosticItem(
                    status="PASS", category="HA", resource=resource_id,
                    check="HPA",
                    detail="HPA configured for autoscaling",
                    file=str(fp)))

            # ── RBAC ──
            elif kind in {'Role', 'ClusterRole', 'RoleBinding', 'ClusterRoleBinding', 'ServiceAccount'}:
                report.has_rbac = True

            # ── Ingress ──
            elif kind == 'Ingress':
                has_tls = 'tls:' in doc
                report.diagnostics.append(DiagnosticItem(
                    status="PASS" if has_tls else "WARN",
                    category="Networking", resource=resource_id,
                    check="TLS configuration",
                    detail="TLS configured" if has_tls else "No TLS — traffic is unencrypted",
                    file=str(fp)))

    # ── Global Checks ──
    if report.workloads and not report.has_pdb:
        report.diagnostics.append(DiagnosticItem(
            status="WARN", category="HA", resource="Global",
            check="PodDisruptionBudget",
            detail="No PDB found — workloads may be disrupted during node maintenance",
            file=""))

    if report.workloads and not report.has_hpa:
        report.diagnostics.append(DiagnosticItem(
            status="WARN", category="HA", resource="Global",
            check="HPA",
            detail="No HPA found — workloads will not autoscale",
            file=""))

    # Check network policy coverage
    namespaces_with_workloads = {w.namespace for w in report.workloads}
    namespaces_with_netpol = {np['namespace'] for np in report.network_policies}
    uncovered = namespaces_with_workloads - namespaces_with_netpol
    if uncovered:
        for ns in uncovered:
            report.diagnostics.append(DiagnosticItem(
                status="WARN", category="Networking", resource=f"Namespace/{ns}",
                check="NetworkPolicy coverage",
                detail=f"Namespace '{ns}' has workloads but no NetworkPolicy",
                file=""))

    return report


# ═══════════════════════════════════════════════════════════════════════════════
# Formatters
# ═══════════════════════════════════════════════════════════════════════════════

def format_markdown(report: K8sReport) -> str:
    lines = [
        "## 🎯 Kubernetes Diagnostics Report",
        f"**Scan Path:** `{report.scan_path}`",
        f"**Manifests Analysed:** {report.manifests_analysed}",
        f"**Workloads Found:** {len(report.workloads)}",
        f"**Namespaces:** {', '.join(sorted(report.namespaces)) if report.namespaces else 'N/A'}",
        "",
    ]

    # Workload summary table
    if report.workloads:
        lines.extend([
            "### 📦 Workload Summary",
            "",
            "| Workload | Kind | Replicas | Resources | Probes | Security | Images |",
            "|----------|------|----------|-----------|--------|----------|--------|",
        ])
        for w in report.workloads:
            res_icon = "✅" if w.resource_status == "PASS" else "❌"
            probe_icon = "✅" if w.probe_status == "PASS" else "⚠️"
            sec_icon = "✅" if w.security_status == "PASS" else "❌"
            imgs = ", ".join(os.path.basename(i) for i in w.images) if w.images else "N/A"
            lines.append(
                f"| {w.name} | {w.kind} | {w.replicas} | {res_icon} | {probe_icon} | {sec_icon} | `{imgs}` |")
        lines.append("")

    # Diagnostics by category
    categories = {}
    for d in report.diagnostics:
        categories.setdefault(d.category, []).append(d)

    for cat, items in sorted(categories.items()):
        icon_map = {"Security": "🔐", "Resources": "📊", "Health": "❤️",
                     "Image": "🐳", "HA": "📈", "Networking": "🌐"}
        icon = icon_map.get(cat, "📋")
        lines.extend([
            f"### {icon} {cat}",
            "",
            "| Status | Resource | Check | Detail |",
            "|--------|----------|-------|--------|",
        ])
        for item in items:
            status_icon = {"PASS": "✅", "WARN": "⚠️", "FAIL": "❌", "INFO": "ℹ️"}.get(item.status, "❓")
            lines.append(f"| {status_icon} | `{item.resource}` | {item.check} | {item.detail} |")
        lines.append("")

    # Summary
    lines.extend([
        "### 📊 Overall Summary",
        "",
        "| Metric | Value |",
        "|--------|-------|",
        f"| Manifests | {report.manifests_analysed} |",
        f"| Workloads | {len(report.workloads)} |",
        f"| ✅ Passed | {report.pass_count} |",
        f"| ⚠️ Warnings | {report.warn_count} |",
        f"| ❌ Failed | {report.fail_count} |",
        f"| PDB Configured | {'✅' if report.has_pdb else '❌'} |",
        f"| HPA Configured | {'✅' if report.has_hpa else '❌'} |",
        f"| Network Policies | {'✅' if report.network_policies else '❌'} |",
        f"| RBAC | {'✅' if report.has_rbac else '❌'} |",
        "",
        f"### Verdict: {report.verdict}",
    ])

    return '\n'.join(lines)


def format_text(report: K8sReport) -> str:
    lines = [
        "=" * 70,
        "  KUBERNETES DIAGNOSTICS REPORT",
        "=" * 70,
        f"  Path:       {report.scan_path}",
        f"  Manifests:  {report.manifests_analysed}",
        f"  Workloads:  {len(report.workloads)}",
        "=" * 70, "",
    ]

    for d in report.diagnostics:
        icon = {"PASS": "[OK]  ", "WARN": "[WARN]", "FAIL": "[FAIL]", "INFO": "[INFO]"}[d.status]
        lines.append(f"  {icon} [{d.category}] {d.resource}: {d.check} — {d.detail}")

    lines.extend([
        "", "-" * 70,
        f"  VERDICT: {report.verdict}",
        f"  Passed={report.pass_count}  Warnings={report.warn_count}  Failed={report.fail_count}",
        "-" * 70,
    ])
    return '\n'.join(lines)


def format_json(report: K8sReport) -> str:
    return json.dumps({
        "scan_path": report.scan_path,
        "manifests_analysed": report.manifests_analysed,
        "verdict": report.verdict,
        "summary": {
            "workloads": len(report.workloads),
            "passed": report.pass_count,
            "warnings": report.warn_count,
            "failed": report.fail_count,
        },
        "workloads": [
            {"name": w.name, "kind": w.kind, "namespace": w.namespace,
             "replicas": w.replicas, "security": w.security_status,
             "resources": w.resource_status, "probes": w.probe_status,
             "images": w.images}
            for w in report.workloads
        ],
        "diagnostics": [
            {"status": d.status, "category": d.category, "resource": d.resource,
             "check": d.check, "detail": d.detail, "file": d.file}
            for d in report.diagnostics
        ],
    }, indent=2)


# ═══════════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════════

def main():
    parser = argparse.ArgumentParser(
        description="Claude DevOps — Kubernetes Manifest Diagnostics",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument('--path', required=True, help='Path to K8s manifests directory')
    parser.add_argument('--format', default='text', dest='output_format',
                        choices=['text', 'markdown', 'json'])

    args = parser.parse_args()
    root = Path(args.path).resolve()

    if not root.exists():
        print(f"Error: Path '{args.path}' does not exist", file=sys.stderr)
        sys.exit(1)

    report = analyse_manifests(root)

    formatter = {'text': format_text, 'markdown': format_markdown, 'json': format_json}
    print(formatter[args.output_format](report))

    sys.exit(1 if report.fail_count > 0 else 0)


if __name__ == '__main__':
    main()
