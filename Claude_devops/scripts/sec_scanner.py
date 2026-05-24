#!/usr/bin/env python3
"""
sec_scanner.py — Comprehensive Security Scanner
=================================================
A self-contained, dependency-free static security analyser for:
  • Secrets / credentials in any file type
  • Dockerfile security best-practices
  • Terraform IaC misconfigurations
  • Kubernetes manifest security posture
  • GitHub Actions pipeline hygiene

Author : Pushparaj Naik
Version: 1.0.0
License: MIT

Usage:
    python3 sec_scanner.py --path <dir_or_file> [--type all|terraform|k8s|docker|secrets|cicd] [--format text|markdown|json]
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass, field, asdict
from enum import Enum
from pathlib import Path
from typing import List, Optional


# ═══════════════════════════════════════════════════════════════════════════════
# Constants & Configuration
# ═══════════════════════════════════════════════════════════════════════════════

class Severity(str, Enum):
    CRITICAL = "CRITICAL"
    HIGH = "HIGH"
    MEDIUM = "MEDIUM"
    LOW = "LOW"
    INFO = "INFO"


@dataclass
class Finding:
    """Represents a single security finding."""
    severity: Severity
    category: str
    file: str
    line: int
    description: str
    recommendation: str
    rule_id: str

    def to_dict(self) -> dict:
        d = asdict(self)
        d["severity"] = self.severity.value
        return d


@dataclass
class ScanReport:
    """Aggregated scan report."""
    scan_path: str
    files_scanned: int = 0
    findings: List[Finding] = field(default_factory=list)

    @property
    def critical_count(self) -> int:
        return sum(1 for f in self.findings if f.severity == Severity.CRITICAL)

    @property
    def high_count(self) -> int:
        return sum(1 for f in self.findings if f.severity == Severity.HIGH)

    @property
    def medium_count(self) -> int:
        return sum(1 for f in self.findings if f.severity == Severity.MEDIUM)

    @property
    def low_count(self) -> int:
        return sum(1 for f in self.findings if f.severity == Severity.LOW)

    @property
    def info_count(self) -> int:
        return sum(1 for f in self.findings if f.severity == Severity.INFO)

    @property
    def verdict(self) -> str:
        if self.critical_count > 0:
            return "CRITICAL"
        if self.high_count > 0:
            return "AT RISK"
        return "SECURE"


# ═══════════════════════════════════════════════════════════════════════════════
# Secret Detection Rules
# ═══════════════════════════════════════════════════════════════════════════════

SECRET_PATTERNS: list[tuple[str, str, Severity, str]] = [
    # (regex, description, severity, rule_id)
    (r'AKIA[0-9A-Z]{16}', "AWS Access Key ID detected", Severity.CRITICAL, "SEC-AWS-001"),
    (r'(?<![A-Za-z0-9/+=])[A-Za-z0-9/+=]{40}(?![A-Za-z0-9/+=])(?=.*(?:aws|secret|key))',
     "Possible AWS Secret Access Key", Severity.HIGH, "SEC-AWS-002"),
    (r'ghp_[A-Za-z0-9]{36}', "GitHub Personal Access Token", Severity.CRITICAL, "SEC-GH-001"),
    (r'gho_[A-Za-z0-9]{36}', "GitHub OAuth Token", Severity.CRITICAL, "SEC-GH-002"),
    (r'ghs_[A-Za-z0-9]{36}', "GitHub Server Token", Severity.CRITICAL, "SEC-GH-003"),
    (r'ghr_[A-Za-z0-9]{36}', "GitHub Refresh Token", Severity.CRITICAL, "SEC-GH-004"),
    (r'xox[baprs]-[A-Za-z0-9\-]{10,}', "Slack Token", Severity.CRITICAL, "SEC-SLACK-001"),
    (r'sk-[A-Za-z0-9]{20,}', "Possible API Key (sk- prefix)", Severity.HIGH, "SEC-API-001"),
    (r'-----BEGIN (?:RSA |EC |DSA )?PRIVATE KEY-----', "Private Key detected", Severity.CRITICAL, "SEC-KEY-001"),
    (r'-----BEGIN OPENSSH PRIVATE KEY-----', "OpenSSH Private Key", Severity.CRITICAL, "SEC-KEY-002"),
    (r'(?i)password\s*[=:]\s*["\'][^"\']{4,}["\']', "Hardcoded password", Severity.HIGH, "SEC-PWD-001"),
    (r'(?i)(?:api_?key|apikey|api_?secret)\s*[=:]\s*["\'][A-Za-z0-9_\-]{8,}["\']',
     "Hardcoded API key/secret", Severity.HIGH, "SEC-API-002"),
    (r'(?i)(?:db_password|database_password|mysql_pwd|pg_password)\s*[=:]\s*["\'][^"\']+["\']',
     "Database password in plaintext", Severity.CRITICAL, "SEC-DB-001"),
    (r'mongodb(?:\+srv)?://[^/\s]+:[^@/\s]+@', "MongoDB connection string with credentials", Severity.CRITICAL, "SEC-DB-002"),
    (r'postgres(?:ql)?://[^/\s]+:[^@/\s]+@', "PostgreSQL connection string with credentials", Severity.CRITICAL, "SEC-DB-003"),
    (r'mysql://[^/\s]+:[^@/\s]+@', "MySQL connection string with credentials", Severity.CRITICAL, "SEC-DB-004"),
]

# Files / directories to always skip
SKIP_DIRS = {'.git', '.terraform', 'node_modules', '__pycache__', '.venv', 'venv', '.tox', '.mypy_cache'}
SKIP_EXTENSIONS = {'.png', '.jpg', '.jpeg', '.gif', '.ico', '.svg', '.woff', '.woff2', '.ttf',
                   '.eot', '.mp4', '.webm', '.zip', '.tar', '.gz', '.bz2', '.lock', '.pyc'}
MAX_FILE_SIZE = 1_000_000  # 1 MB


# ═══════════════════════════════════════════════════════════════════════════════
# Scanner Engines
# ═══════════════════════════════════════════════════════════════════════════════

def _iter_files(root: Path) -> list[Path]:
    """Recursively yield files, respecting skip rules."""
    files: list[Path] = []
    if root.is_file():
        return [root]
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for fname in filenames:
            fp = Path(dirpath) / fname
            if fp.suffix.lower() in SKIP_EXTENSIONS:
                continue
            if fp.stat().st_size > MAX_FILE_SIZE:
                continue
            files.append(fp)
    return files


def _read_file(path: Path) -> Optional[list[str]]:
    try:
        with open(path, 'r', encoding='utf-8', errors='ignore') as f:
            return f.readlines()
    except (PermissionError, OSError):
        return None


# ─────────────────────────────────────────────────────────────────────────────
# Engine 1: Secret Scanner
# ─────────────────────────────────────────────────────────────────────────────

def scan_secrets(root: Path) -> list[Finding]:
    findings: list[Finding] = []
    for fp in _iter_files(root):
        # Skip binary-ish and state files
        if fp.name in {'terraform.tfstate', 'terraform.tfstate.backup'}:
            findings.append(Finding(
                severity=Severity.CRITICAL, category="Secrets",
                file=str(fp), line=0,
                description="Terraform state file found in repository — may contain secrets",
                recommendation="Add terraform.tfstate* to .gitignore and use remote state",
                rule_id="SEC-STATE-001"))
            continue
        if fp.name == '.env':
            findings.append(Finding(
                severity=Severity.HIGH, category="Secrets",
                file=str(fp), line=0,
                description=".env file found — may contain secrets",
                recommendation="Add .env to .gitignore and use secret management",
                rule_id="SEC-ENV-001"))
            continue

        lines = _read_file(fp)
        if lines is None:
            continue
        for i, line in enumerate(lines, start=1):
            stripped = line.strip()
            # Skip comments in most languages
            if stripped.startswith('#') or stripped.startswith('//') or stripped.startswith('--'):
                # Still scan for actual key patterns in comments (copy-paste errors)
                pass
            for pattern, desc, severity, rule_id in SECRET_PATTERNS:
                if re.search(pattern, line):
                    findings.append(Finding(
                        severity=severity, category="Secrets",
                        file=str(fp), line=i,
                        description=desc,
                        recommendation="Remove secret and use environment variables or a secrets manager",
                        rule_id=rule_id))
    return findings


# ─────────────────────────────────────────────────────────────────────────────
# Engine 2: Dockerfile Scanner
# ─────────────────────────────────────────────────────────────────────────────

def scan_dockerfiles(root: Path) -> list[Finding]:
    findings: list[Finding] = []
    docker_files = [f for f in _iter_files(root) if f.name.startswith('Dockerfile') or f.name == 'Containerfile']

    for fp in docker_files:
        lines = _read_file(fp)
        if lines is None:
            continue

        has_user = False
        has_healthcheck = False
        uses_add = False
        from_lines: list[tuple[int, str]] = []

        for i, line in enumerate(lines, start=1):
            stripped = line.strip()
            upper = stripped.upper()

            # FROM image check
            if upper.startswith('FROM '):
                image_ref = stripped.split()[1] if len(stripped.split()) > 1 else ""
                from_lines.append((i, image_ref))
                if ':latest' in image_ref or (':' not in image_ref and '@sha256:' not in image_ref):
                    findings.append(Finding(
                        severity=Severity.HIGH, category="Docker",
                        file=str(fp), line=i,
                        description=f"Unpinned base image: {image_ref}",
                        recommendation="Pin image to specific version or SHA digest",
                        rule_id="DOC-IMG-001"))

            if upper.startswith('USER '):
                has_user = True

            if upper.startswith('HEALTHCHECK '):
                has_healthcheck = True

            if upper.startswith('ADD ') and not any(x in stripped for x in ['--chown', '.tar']):
                findings.append(Finding(
                    severity=Severity.MEDIUM, category="Docker",
                    file=str(fp), line=i,
                    description="ADD instruction used — prefer COPY for local files",
                    recommendation="Replace ADD with COPY unless extracting archives or fetching URLs",
                    rule_id="DOC-ADD-001"))

            # Secrets in ARG / ENV
            if re.match(r'(?i)^(?:ARG|ENV)\s+\S*(?:password|secret|key|token)\s*=', stripped):
                findings.append(Finding(
                    severity=Severity.HIGH, category="Docker",
                    file=str(fp), line=i,
                    description="Secret passed via ARG/ENV instruction",
                    recommendation="Use Docker BuildKit secrets or runtime injection",
                    rule_id="DOC-SEC-001"))

        if not has_user:
            findings.append(Finding(
                severity=Severity.MEDIUM, category="Docker",
                file=str(fp), line=0,
                description="No USER directive — container runs as root",
                recommendation="Add USER directive to run as non-root",
                rule_id="DOC-USR-001"))

        if not has_healthcheck:
            findings.append(Finding(
                severity=Severity.LOW, category="Docker",
                file=str(fp), line=0,
                description="No HEALTHCHECK instruction defined",
                recommendation="Add HEALTHCHECK for orchestrator health monitoring",
                rule_id="DOC-HC-001"))

        # Check for .dockerignore
        dockerignore = fp.parent / '.dockerignore'
        if not dockerignore.exists():
            findings.append(Finding(
                severity=Severity.MEDIUM, category="Docker",
                file=str(fp), line=0,
                description=".dockerignore not found alongside Dockerfile",
                recommendation="Create .dockerignore to exclude sensitive/unnecessary files",
                rule_id="DOC-IGN-001"))

    return findings


# ─────────────────────────────────────────────────────────────────────────────
# Engine 3: Terraform Scanner
# ─────────────────────────────────────────────────────────────────────────────

def scan_terraform(root: Path) -> list[Finding]:
    findings: list[Finding] = []
    tf_files = [f for f in _iter_files(root) if f.suffix == '.tf' or f.suffix == '.tfvars']

    for fp in tf_files:
        lines = _read_file(fp)
        if lines is None:
            continue
        content = ''.join(lines)

        for i, line in enumerate(lines, start=1):
            stripped = line.strip()

            # Wide-open security groups
            if re.search(r'cidr_blocks\s*=\s*\[\s*"0\.0\.0\.0/0"\s*\]', stripped):
                findings.append(Finding(
                    severity=Severity.HIGH, category="Terraform",
                    file=str(fp), line=i,
                    description="Security group allows ingress from 0.0.0.0/0",
                    recommendation="Restrict CIDR to specific IP ranges unless public HTTP(S)",
                    rule_id="TF-SG-001"))

            # IAM wildcard actions
            if re.search(r'(?i)actions?\s*=\s*\[\s*"\*"\s*\]', stripped):
                findings.append(Finding(
                    severity=Severity.CRITICAL, category="Terraform",
                    file=str(fp), line=i,
                    description="IAM policy uses wildcard action (*)",
                    recommendation="Scope IAM actions to least-privilege",
                    rule_id="TF-IAM-001"))

            # IAM wildcard resources
            if re.search(r'(?i)resources?\s*=\s*\[\s*"\*"\s*\]', stripped):
                findings.append(Finding(
                    severity=Severity.HIGH, category="Terraform",
                    file=str(fp), line=i,
                    description="IAM policy uses wildcard resource (*)",
                    recommendation="Scope IAM resources to specific ARNs",
                    rule_id="TF-IAM-002"))

            # Hardcoded AWS account IDs
            if re.search(r'\b\d{12}\b', stripped) and 'account_id' not in stripped.lower():
                # Heuristic: 12-digit numbers that look like account IDs
                if any(kw in stripped.lower() for kw in ['arn:', 'account', 'aws']):
                    findings.append(Finding(
                        severity=Severity.MEDIUM, category="Terraform",
                        file=str(fp), line=i,
                        description="Possible hardcoded AWS account ID",
                        recommendation="Use data.aws_caller_identity.current.account_id",
                        rule_id="TF-HC-001"))

            # HTTP instead of HTTPS
            if re.search(r'(?i)protocol\s*=\s*"HTTP"', stripped) and 'redirect' not in stripped.lower():
                findings.append(Finding(
                    severity=Severity.MEDIUM, category="Terraform",
                    file=str(fp), line=i,
                    description="HTTP protocol specified — consider HTTPS",
                    recommendation="Use HTTPS for encrypted communications",
                    rule_id="TF-TLS-001"))

            # Missing encryption
            if re.search(r'(?i)encrypted\s*=\s*false', stripped):
                findings.append(Finding(
                    severity=Severity.HIGH, category="Terraform",
                    file=str(fp), line=i,
                    description="Encryption explicitly disabled",
                    recommendation="Enable encryption at rest for data protection",
                    rule_id="TF-ENC-001"))

            # Public S3 bucket ACL
            if re.search(r'(?i)acl\s*=\s*"public-read"', stripped):
                findings.append(Finding(
                    severity=Severity.CRITICAL, category="Terraform",
                    file=str(fp), line=i,
                    description="S3 bucket set to public-read ACL",
                    recommendation="Use private ACL and CloudFront for public content",
                    rule_id="TF-S3-001"))

        # Check for required tags at the module/resource level
        if fp.suffix == '.tf':
            resource_blocks = re.findall(r'resource\s+"([^"]+)"\s+"([^"]+)"', content)
            required_tags = {'Environment', 'Project', 'ManagedBy', 'Owner'}
            for res_type, res_name in resource_blocks:
                # Find the tags block for this resource
                tag_pattern = rf'resource\s+"{re.escape(res_type)}"\s+"{re.escape(res_name)}".*?tags\s*=\s*\{{([^}}]*)\}}'
                tag_match = re.search(tag_pattern, content, re.DOTALL)
                if tag_match:
                    tags_block = tag_match.group(1)
                    for tag in required_tags:
                        if tag not in tags_block:
                            findings.append(Finding(
                                severity=Severity.LOW, category="Terraform",
                                file=str(fp), line=0,
                                description=f"Resource {res_type}.{res_name} missing tag: {tag}",
                                recommendation=f"Add '{tag}' tag to comply with tagging policy",
                                rule_id="TF-TAG-001"))
                else:
                    # Skip data sources and resources that don't support tags
                    if not any(x in res_type for x in ['aws_iam_policy_document',
                                                        'aws_iam_role_policy_attachment',
                                                        'aws_route_table_association',
                                                        'aws_security_group_rule',
                                                        'helm_release',
                                                        'kubernetes_',
                                                        'null_resource']):
                        findings.append(Finding(
                            severity=Severity.LOW, category="Terraform",
                            file=str(fp), line=0,
                            description=f"Resource {res_type}.{res_name} has no tags block",
                            recommendation="Add tags block with required tags",
                            rule_id="TF-TAG-002"))

    return findings


# ─────────────────────────────────────────────────────────────────────────────
# Engine 4: Kubernetes Manifest Scanner
# ─────────────────────────────────────────────────────────────────────────────

def scan_kubernetes(root: Path) -> list[Finding]:
    findings: list[Finding] = []
    yaml_files = [f for f in _iter_files(root) if f.suffix in {'.yaml', '.yml'}]

    for fp in yaml_files:
        lines = _read_file(fp)
        if lines is None:
            continue
        content = ''.join(lines)

        # Quick check: is this a K8s manifest?
        if 'apiVersion:' not in content or 'kind:' not in content:
            continue

        # Split multi-document YAML
        documents = content.split('---')
        line_offset = 0

        for doc in documents:
            doc_lines = doc.split('\n')

            # Extract kind and name
            kind_match = re.search(r'kind:\s*(\S+)', doc)
            name_match = re.search(r'name:\s*(\S+)', doc)
            kind = kind_match.group(1) if kind_match else "Unknown"
            name = name_match.group(1) if name_match else "Unknown"

            workload_kinds = {'Deployment', 'StatefulSet', 'DaemonSet', 'Job', 'CronJob'}

            if kind in workload_kinds:
                # Check security context
                if 'runAsNonRoot: true' not in doc:
                    findings.append(Finding(
                        severity=Severity.HIGH, category="Kubernetes",
                        file=str(fp), line=0,
                        description=f"{kind}/{name}: runAsNonRoot not set to true",
                        recommendation="Set securityContext.runAsNonRoot: true",
                        rule_id="K8S-SEC-001"))

                if 'allowPrivilegeEscalation: false' not in doc:
                    findings.append(Finding(
                        severity=Severity.HIGH, category="Kubernetes",
                        file=str(fp), line=0,
                        description=f"{kind}/{name}: allowPrivilegeEscalation not explicitly disabled",
                        recommendation="Set securityContext.allowPrivilegeEscalation: false",
                        rule_id="K8S-SEC-002"))

                if 'privileged: true' in doc:
                    findings.append(Finding(
                        severity=Severity.CRITICAL, category="Kubernetes",
                        file=str(fp), line=0,
                        description=f"{kind}/{name}: Container running in privileged mode",
                        recommendation="Remove privileged: true — containers should not be privileged",
                        rule_id="K8S-SEC-003"))

                if 'hostNetwork: true' in doc:
                    findings.append(Finding(
                        severity=Severity.HIGH, category="Kubernetes",
                        file=str(fp), line=0,
                        description=f"{kind}/{name}: hostNetwork enabled",
                        recommendation="Avoid hostNetwork unless absolutely necessary",
                        rule_id="K8S-SEC-004"))

                # Check resource limits
                if 'resources:' not in doc:
                    findings.append(Finding(
                        severity=Severity.HIGH, category="Kubernetes",
                        file=str(fp), line=0,
                        description=f"{kind}/{name}: No resource requests/limits defined",
                        recommendation="Define resources.requests and resources.limits",
                        rule_id="K8S-RES-001"))
                else:
                    if 'limits:' not in doc:
                        findings.append(Finding(
                            severity=Severity.MEDIUM, category="Kubernetes",
                            file=str(fp), line=0,
                            description=f"{kind}/{name}: Resource limits not defined",
                            recommendation="Define resources.limits for CPU and memory",
                            rule_id="K8S-RES-002"))

                # Check probes
                if kind in {'Deployment', 'StatefulSet', 'DaemonSet'}:
                    if 'readinessProbe:' not in doc:
                        findings.append(Finding(
                            severity=Severity.MEDIUM, category="Kubernetes",
                            file=str(fp), line=0,
                            description=f"{kind}/{name}: No readinessProbe configured",
                            recommendation="Add readinessProbe for traffic routing",
                            rule_id="K8S-PROBE-001"))
                    if 'livenessProbe:' not in doc:
                        findings.append(Finding(
                            severity=Severity.MEDIUM, category="Kubernetes",
                            file=str(fp), line=0,
                            description=f"{kind}/{name}: No livenessProbe configured",
                            recommendation="Add livenessProbe for automatic recovery",
                            rule_id="K8S-PROBE-002"))

                # Check image tags
                image_matches = re.findall(r'image:\s*(\S+)', doc)
                for img in image_matches:
                    if ':latest' in img:
                        findings.append(Finding(
                            severity=Severity.HIGH, category="Kubernetes",
                            file=str(fp), line=0,
                            description=f"{kind}/{name}: Image uses :latest tag — {img}",
                            recommendation="Pin image to specific version or SHA digest",
                            rule_id="K8S-IMG-001"))
                    if ':' not in img and '@' not in img:
                        findings.append(Finding(
                            severity=Severity.HIGH, category="Kubernetes",
                            file=str(fp), line=0,
                            description=f"{kind}/{name}: Image has no tag — {img}",
                            recommendation="Specify explicit image tag",
                            rule_id="K8S-IMG-002"))

                # Check replicas
                replicas_match = re.search(r'replicas:\s*(\d+)', doc)
                if replicas_match and int(replicas_match.group(1)) < 2:
                    findings.append(Finding(
                        severity=Severity.LOW, category="Kubernetes",
                        file=str(fp), line=0,
                        description=f"{kind}/{name}: Only {replicas_match.group(1)} replica configured",
                        recommendation="Use at least 2 replicas for high availability",
                        rule_id="K8S-HA-001"))

            # Check for plaintext secrets
            if kind == 'Secret':
                if 'stringData:' in doc:
                    findings.append(Finding(
                        severity=Severity.MEDIUM, category="Kubernetes",
                        file=str(fp), line=0,
                        description=f"Secret/{name}: Using stringData (plaintext) — should use ExternalSecrets in production",
                        recommendation="Use ExternalSecrets Operator or SealedSecrets for production",
                        rule_id="K8S-SECRET-001"))

            line_offset += len(doc_lines)

    return findings


# ─────────────────────────────────────────────────────────────────────────────
# Engine 5: CI/CD Pipeline Scanner
# ─────────────────────────────────────────────────────────────────────────────

def scan_cicd(root: Path) -> list[Finding]:
    findings: list[Finding] = []
    # GitHub Actions
    workflows_dir = root / '.github' / 'workflows'
    if not workflows_dir.exists():
        # Search recursively
        for fp in _iter_files(root):
            if '.github/workflows/' in str(fp) and fp.suffix in {'.yml', '.yaml'}:
                findings.extend(_scan_github_action(fp))
    else:
        for fp in workflows_dir.iterdir():
            if fp.suffix in {'.yml', '.yaml'}:
                findings.extend(_scan_github_action(fp))
    return findings


def _scan_github_action(fp: Path) -> list[Finding]:
    findings: list[Finding] = []
    lines = _read_file(fp)
    if lines is None:
        return findings
    content = ''.join(lines)

    # Check for permissions block
    if 'permissions:' not in content:
        findings.append(Finding(
            severity=Severity.MEDIUM, category="CI/CD",
            file=str(fp), line=0,
            description="GitHub Actions workflow missing 'permissions' block",
            recommendation="Add explicit permissions block with least-privilege scopes",
            rule_id="CI-PERM-001"))

    for i, line in enumerate(lines, start=1):
        stripped = line.strip()

        # Actions pinned to branch instead of SHA
        uses_match = re.match(r'- uses:\s*(\S+)', stripped) or re.match(r'uses:\s*(\S+)', stripped)
        if uses_match:
            action_ref = uses_match.group(1)
            if '@main' in action_ref or '@master' in action_ref:
                findings.append(Finding(
                    severity=Severity.MEDIUM, category="CI/CD",
                    file=str(fp), line=i,
                    description=f"Action pinned to mutable branch: {action_ref}",
                    recommendation="Pin actions to SHA or specific release tag",
                    rule_id="CI-PIN-001"))

        # Echoing secrets
        if re.search(r'echo\s+.*\$\{\{\s*secrets\.', stripped):
            findings.append(Finding(
                severity=Severity.CRITICAL, category="CI/CD",
                file=str(fp), line=i,
                description="Secret potentially logged via echo command",
                recommendation="Never echo secrets — they may appear in logs",
                rule_id="CI-SEC-001"))

        # Hardcoded credentials in env
        if re.search(r'(?i)(?:AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY)\s*:', stripped):
            if 'secrets.' not in stripped:
                findings.append(Finding(
                    severity=Severity.CRITICAL, category="CI/CD",
                    file=str(fp), line=i,
                    description="AWS credentials may be hardcoded in workflow",
                    recommendation="Use OIDC or GitHub Secrets for AWS credentials",
                    rule_id="CI-CRED-001"))

    return findings


# ═══════════════════════════════════════════════════════════════════════════════
# Report Formatters
# ═══════════════════════════════════════════════════════════════════════════════

def format_markdown(report: ScanReport) -> str:
    lines = [
        f"## 🔒 Security Scan Report",
        f"**Scan Path:** `{report.scan_path}`",
        f"**Files Scanned:** {report.files_scanned}",
        f"**Total Findings:** {len(report.findings)}",
        "",
    ]

    # Group by severity
    for severity in [Severity.CRITICAL, Severity.HIGH, Severity.MEDIUM, Severity.LOW, Severity.INFO]:
        items = [f for f in report.findings if f.severity == severity]
        if not items:
            continue
        icon = {"CRITICAL": "🚨", "HIGH": "⚠️", "MEDIUM": "📝", "LOW": "💡", "INFO": "ℹ️"}[severity.value]
        lines.append(f"### {icon} {severity.value} ({len(items)})")
        lines.append("")
        lines.append("| # | Rule | Category | File | Line | Description |")
        lines.append("|---|------|----------|------|------|-------------|")
        for idx, f in enumerate(items, 1):
            safe_file = os.path.basename(f.file)
            lines.append(f"| {idx} | `{f.rule_id}` | {f.category} | `{safe_file}` | {f.line} | {f.description} |")
        lines.append("")

    # Summary table
    lines.extend([
        "### 📊 Summary",
        "",
        "| Severity | Count |",
        "|----------|-------|",
        f"| 🚨 Critical | {report.critical_count} |",
        f"| ⚠️ High | {report.high_count} |",
        f"| 📝 Medium | {report.medium_count} |",
        f"| 💡 Low | {report.low_count} |",
        f"| ℹ️ Info | {report.info_count} |",
        f"| **Total** | **{len(report.findings)}** |",
        "",
        f"### Verdict: {report.verdict}",
    ])

    return '\n'.join(lines)


def format_text(report: ScanReport) -> str:
    lines = [
        "=" * 70,
        "  SECURITY SCAN REPORT",
        "=" * 70,
        f"  Path:     {report.scan_path}",
        f"  Files:    {report.files_scanned}",
        f"  Findings: {len(report.findings)}",
        "=" * 70, "",
    ]

    for f in sorted(report.findings, key=lambda x: list(Severity).index(x.severity)):
        lines.append(f"  [{f.severity.value}] {f.rule_id}")
        lines.append(f"    Category: {f.category}")
        lines.append(f"    File:     {f.file}:{f.line}")
        lines.append(f"    Issue:    {f.description}")
        lines.append(f"    Fix:      {f.recommendation}")
        lines.append("")

    lines.extend([
        "-" * 70,
        f"  VERDICT: {report.verdict}",
        f"  Critical={report.critical_count}  High={report.high_count}  "
        f"Medium={report.medium_count}  Low={report.low_count}  Info={report.info_count}",
        "-" * 70,
    ])
    return '\n'.join(lines)


def format_json(report: ScanReport) -> str:
    return json.dumps({
        "scan_path": report.scan_path,
        "files_scanned": report.files_scanned,
        "verdict": report.verdict,
        "summary": {
            "critical": report.critical_count,
            "high": report.high_count,
            "medium": report.medium_count,
            "low": report.low_count,
            "info": report.info_count,
            "total": len(report.findings),
        },
        "findings": [f.to_dict() for f in report.findings],
    }, indent=2)


# ═══════════════════════════════════════════════════════════════════════════════
# Main Entry Point
# ═══════════════════════════════════════════════════════════════════════════════

def main():
    parser = argparse.ArgumentParser(
        description="Claude DevOps Security Scanner — static analysis for IaC, containers, and CI/CD",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 sec_scanner.py --path ./infra --type terraform
  python3 sec_scanner.py --path . --format markdown
  python3 sec_scanner.py --path ./k8s --type k8s --format json
        """,
    )
    parser.add_argument('--path', required=True, help='Path to scan (file or directory)')
    parser.add_argument('--type', default='all',
                        choices=['all', 'secrets', 'terraform', 'k8s', 'docker', 'cicd'],
                        help='Type of scan to perform (default: all)')
    parser.add_argument('--format', default='text', dest='output_format',
                        choices=['text', 'markdown', 'json'],
                        help='Output format (default: text)')

    args = parser.parse_args()
    root = Path(args.path).resolve()

    if not root.exists():
        print(f"Error: Path '{args.path}' does not exist", file=sys.stderr)
        sys.exit(1)

    report = ScanReport(scan_path=str(root))
    report.files_scanned = len(_iter_files(root))

    scan_type = args.type

    if scan_type in ('all', 'secrets'):
        report.findings.extend(scan_secrets(root))
    if scan_type in ('all', 'terraform'):
        report.findings.extend(scan_terraform(root))
    if scan_type in ('all', 'k8s'):
        report.findings.extend(scan_kubernetes(root))
    if scan_type in ('all', 'docker'):
        report.findings.extend(scan_dockerfiles(root))
    if scan_type in ('all', 'cicd'):
        report.findings.extend(scan_cicd(root))

    formatter = {'text': format_text, 'markdown': format_markdown, 'json': format_json}
    print(formatter[args.output_format](report))

    # Exit code: 2 for critical, 1 for high, 0 otherwise
    if report.critical_count > 0:
        sys.exit(2)
    elif report.high_count > 0:
        sys.exit(1)
    else:
        sys.exit(0)


if __name__ == '__main__':
    main()
