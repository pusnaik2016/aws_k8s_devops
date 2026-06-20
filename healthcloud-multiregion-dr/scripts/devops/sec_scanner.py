#!/usr/bin/env python3
"""
sec_scanner.py — 5-Engine Security Scanner for Healthcare Infrastructure
=========================================================================
Zero-dependency security scanner that checks for:
  Engine 1: Hardcoded secrets (15+ regex patterns)
  Engine 2: Dockerfile security (image pins, USER, HEALTHCHECK)
  Engine 3: Terraform security (SG, IAM, encryption, public access)
  Engine 4: Kubernetes security (runAsNonRoot, probes, resources)
  Engine 5: CI/CD security (permissions, action pins, OIDC)

Usage:
  python3 sec_scanner.py --path . --format markdown
  python3 sec_scanner.py --path ./terraform --type terraform --format json
  python3 sec_scanner.py --path ./kubernetes --type k8s --format text

Exit codes: 0 = secure, 1 = high findings, 2 = critical findings
"""

import argparse
import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path

# ──────────────────────────────────────────────────────────────────────────────
# Finding data class
# ──────────────────────────────────────────────────────────────────────────────

class Finding:
    def __init__(self, rule_id, severity, category, file, line, description, remediation=""):
        self.rule_id = rule_id
        self.severity = severity  # CRITICAL, HIGH, MEDIUM, LOW, INFO
        self.category = category
        self.file = file
        self.line = line
        self.description = description
        self.remediation = remediation

    def to_dict(self):
        return {
            "rule_id": self.rule_id,
            "severity": self.severity,
            "category": self.category,
            "file": self.file,
            "line": self.line,
            "description": self.description,
            "remediation": self.remediation
        }

# ──────────────────────────────────────────────────────────────────────────────
# Engine 1: Secret Detection (15+ patterns)
# ──────────────────────────────────────────────────────────────────────────────

SECRET_PATTERNS = [
    ("SEC-AWS-001", r'AKIA[0-9A-Z]{16}', "AWS Access Key ID"),
    ("SEC-AWS-002", r'aws_secret_access_key\s*=\s*["\'][^"\']{20,}', "AWS Secret Access Key"),
    ("SEC-AWS-003", r'aws_session_token\s*=\s*["\'][^"\']+', "AWS Session Token"),
    ("SEC-GH-001",  r'ghp_[0-9a-zA-Z]{36}', "GitHub Personal Access Token"),
    ("SEC-GH-002",  r'gho_[0-9a-zA-Z]{36}', "GitHub OAuth Token"),
    ("SEC-GH-003",  r'github_pat_[0-9a-zA-Z]{22}_[0-9a-zA-Z]{59}', "GitHub Fine-grained PAT"),
    ("SEC-KEY-001", r'-----BEGIN (RSA |DSA |EC |OPENSSH )?PRIVATE KEY-----', "Private Key"),
    ("SEC-DB-001",  r'(password|passwd|pwd)\s*=\s*["\'][^"\']{8,}', "Hardcoded Password"),
    ("SEC-DB-002",  r'(mongodb|postgres|mysql|redis)://[^/\s]+:[^@\s]+@', "Database Connection String"),
    ("SEC-AZ-001",  r'DefaultEndpointsProtocol=https;AccountName=', "Azure Storage Connection String"),
    ("SEC-AZ-002",  r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}.*\.(pem|key)', "Azure Service Principal Key"),
    ("SEC-API-001", r'sk-[0-9a-zA-Z]{48}', "OpenAI API Key"),
    ("SEC-API-002", r'Bearer\s+[A-Za-z0-9\-._~+/]+=*', "Bearer Token"),
    ("SEC-JWT-001", r'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}', "JWT Token"),
    ("SEC-SLACK-001", r'xox[baprs]-[0-9a-zA-Z]{10,}', "Slack Token"),
    ("SEC-GENERIC-001", r'(api[_-]?key|apikey|api[_-]?secret)\s*[:=]\s*["\'][^"\']{16,}', "Generic API Key"),
]

SKIP_EXTENSIONS = {'.png', '.jpg', '.jpeg', '.gif', '.ico', '.woff', '.woff2',
                   '.ttf', '.eot', '.svg', '.zip', '.tar', '.gz', '.jar',
                   '.pyc', '.pyo', '.class', '.o', '.so', '.dylib', '.pdf'}

SKIP_DIRS = {'.git', '.terraform', 'node_modules', '.venv', 'venv',
             '__pycache__', '.pytest_cache', '.idea', '.vscode', 'target', 'dist'}

def scan_secrets(path: str) -> list:
    findings = []
    for root, dirs, files in os.walk(path):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for fname in files:
            fpath = os.path.join(root, fname)
            if Path(fpath).suffix.lower() in SKIP_EXTENSIONS:
                continue
            try:
                with open(fpath, 'r', errors='ignore') as f:
                    for line_num, line in enumerate(f, 1):
                        for rule_id, pattern, desc in SECRET_PATTERNS:
                            if re.search(pattern, line, re.IGNORECASE):
                                # Skip test files and example files with dummy values
                                if 'test' in fpath.lower() or 'example' in fpath.lower():
                                    continue
                                findings.append(Finding(
                                    rule_id=rule_id,
                                    severity="CRITICAL",
                                    category="Secrets",
                                    file=os.path.relpath(fpath, path),
                                    line=line_num,
                                    description=f"{desc} detected",
                                    remediation="Use AWS Secrets Manager or Azure Key Vault"
                                ))
            except (PermissionError, OSError):
                continue
    return findings

# ──────────────────────────────────────────────────────────────────────────────
# Engine 2: Dockerfile Security
# ──────────────────────────────────────────────────────────────────────────────

def scan_dockerfiles(path: str) -> list:
    findings = []
    for root, dirs, files in os.walk(path):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for fname in files:
            if fname.lower() in ('dockerfile', 'dockerfile.dev', 'dockerfile.prod'):
                fpath = os.path.join(root, fname)
                rel = os.path.relpath(fpath, path)
                try:
                    content = open(fpath).read()
                    lines = content.splitlines()
                except (PermissionError, OSError):
                    continue

                # Check :latest tag
                for i, line in enumerate(lines, 1):
                    if re.match(r'^FROM\s+\S+:latest', line, re.IGNORECASE):
                        findings.append(Finding("DOC-TAG-001", "HIGH", "Docker", rel, i,
                            "Image uses :latest tag — pin to specific version or digest",
                            "Use FROM image:1.2.3 or FROM image@sha256:..."))
                    if re.match(r'^FROM\s+\S+\s*$', line) and not line.strip().startswith('#'):
                        if 'scratch' not in line and 'AS' not in line.upper():
                            findings.append(Finding("DOC-TAG-002", "HIGH", "Docker", rel, i,
                                "Image has no tag — defaults to :latest",
                                "Specify explicit version tag"))

                # Check USER directive
                if not re.search(r'^USER\s+', content, re.MULTILINE):
                    findings.append(Finding("DOC-USR-001", "MEDIUM", "Docker", rel, 0,
                        "No USER directive — container runs as root",
                        "Add USER nonroot or USER 1000"))

                # Check HEALTHCHECK
                if not re.search(r'^HEALTHCHECK\s+', content, re.MULTILINE):
                    findings.append(Finding("DOC-HC-001", "MEDIUM", "Docker", rel, 0,
                        "No HEALTHCHECK directive",
                        "Add HEALTHCHECK CMD curl -f http://localhost:8080/health || exit 1"))

                # Check ADD vs COPY
                for i, line in enumerate(lines, 1):
                    if re.match(r'^ADD\s+', line) and not line.strip().endswith('.tar.gz'):
                        findings.append(Finding("DOC-ADD-001", "LOW", "Docker", rel, i,
                            "Use COPY instead of ADD (ADD has implicit URL/tar extraction)",
                            "Replace ADD with COPY"))

                # Check secrets in ENV/ARG
                for i, line in enumerate(lines, 1):
                    if re.match(r'^(ENV|ARG)\s+.*(PASSWORD|SECRET|KEY|TOKEN)', line, re.IGNORECASE):
                        findings.append(Finding("DOC-SEC-001", "HIGH", "Docker", rel, i,
                            "Potential secret in ENV/ARG — visible in image layers",
                            "Use runtime secrets via environment injection"))

                # Check .dockerignore
                dockerignore = os.path.join(os.path.dirname(fpath), '.dockerignore')
                if not os.path.exists(dockerignore):
                    findings.append(Finding("DOC-IGN-001", "MEDIUM", "Docker", rel, 0,
                        ".dockerignore not found — may copy secrets/git into image",
                        "Create .dockerignore excluding .git, .env, secrets, node_modules"))

    return findings

# ──────────────────────────────────────────────────────────────────────────────
# Engine 3: Terraform Security
# ──────────────────────────────────────────────────────────────────────────────

def scan_terraform(path: str) -> list:
    findings = []
    for root, dirs, files in os.walk(path):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for fname in files:
            if not fname.endswith('.tf'):
                continue
            fpath = os.path.join(root, fname)
            rel = os.path.relpath(fpath, path)
            try:
                content = open(fpath).read()
                lines = content.splitlines()
            except (PermissionError, OSError):
                continue

            for i, line in enumerate(lines, 1):
                # Open security groups
                if re.search(r'cidr_blocks\s*=\s*\[\s*"0\.0\.0\.0/0"\s*\]', line):
                    # Check if it's port 80 or 443 (allowed)
                    context = '\n'.join(lines[max(0, i-5):i+5])
                    if not re.search(r'(from_port|to_port)\s*=\s*(80|443)', context):
                        findings.append(Finding("TF-SG-001", "CRITICAL", "Terraform", rel, i,
                            "Security Group open to 0.0.0.0/0 on non-standard port",
                            "Restrict CIDR to specific IP ranges"))

                # Azure NSG open
                if re.search(r'source_address_prefix\s*=\s*"\*"', line):
                    findings.append(Finding("TF-NSG-001", "CRITICAL", "Terraform", rel, i,
                        "Azure NSG open to * (all IPs)",
                        "Restrict to specific CIDR ranges"))

                # IAM wildcard actions
                if re.search(r'"Action"\s*:\s*"\*"', line) or re.search(r'actions\s*=\s*\[\s*"\*"\s*\]', line):
                    findings.append(Finding("TF-IAM-001", "CRITICAL", "Terraform", rel, i,
                        "IAM policy with wildcard Action: * (overly permissive)",
                        "Scope to specific actions needed"))

                # IAM wildcard resources
                if re.search(r'"Resource"\s*:\s*"\*"', line) or re.search(r'resources\s*=\s*\[\s*"\*"\s*\]', line):
                    findings.append(Finding("TF-IAM-002", "HIGH", "Terraform", rel, i,
                        "IAM policy with wildcard Resource: *",
                        "Scope to specific resource ARNs"))

                # Unencrypted S3
                if 'aws_s3_bucket' in line and 'server_side_encryption' not in content:
                    findings.append(Finding("TF-S3-001", "HIGH", "Terraform", rel, i,
                        "S3 bucket may not have server-side encryption configured",
                        "Add aws_s3_bucket_server_side_encryption_configuration with KMS"))

                # Public S3
                if re.search(r'acl\s*=\s*"public', line):
                    findings.append(Finding("TF-S3-002", "CRITICAL", "Terraform", rel, i,
                        "S3 bucket with public ACL — PHI data exposure risk",
                        "Use private ACL and block public access"))

                # Unencrypted RDS
                if re.search(r'storage_encrypted\s*=\s*false', line):
                    findings.append(Finding("TF-RDS-001", "CRITICAL", "Terraform", rel, i,
                        "RDS storage encryption disabled — HIPAA violation",
                        "Set storage_encrypted = true with KMS key"))

                # Missing tags
                if re.search(r'resource\s+"aws_', line) or re.search(r'resource\s+"azurerm_', line):
                    # Check if tags block exists in surrounding context
                    block_end = min(i + 30, len(lines))
                    block = '\n'.join(lines[i-1:block_end])
                    if 'tags' not in block and 'tags_all' not in block:
                        findings.append(Finding("TF-TAG-001", "MEDIUM", "Terraform", rel, i,
                            "Resource missing required tags (Environment, Project, Compliance)",
                            "Add tags block with required tag keys"))

    return findings

# ──────────────────────────────────────────────────────────────────────────────
# Engine 4: Kubernetes Security
# ──────────────────────────────────────────────────────────────────────────────

def scan_kubernetes(path: str) -> list:
    findings = []
    for root, dirs, files in os.walk(path):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for fname in files:
            if not fname.endswith(('.yaml', '.yml')):
                continue
            fpath = os.path.join(root, fname)
            rel = os.path.relpath(fpath, path)
            try:
                content = open(fpath).read()
                lines = content.splitlines()
            except (PermissionError, OSError):
                continue

            # Skip non-K8s YAML
            if 'kind:' not in content:
                continue

            is_deployment = bool(re.search(r'kind:\s*(Deployment|StatefulSet|DaemonSet)', content))

            if is_deployment:
                # runAsNonRoot
                if 'runAsNonRoot: true' not in content:
                    findings.append(Finding("K8S-SEC-001", "HIGH", "Kubernetes", rel, 0,
                        "Missing runAsNonRoot: true — container may run as root",
                        "Add securityContext.runAsNonRoot: true"))

                # allowPrivilegeEscalation
                if 'allowPrivilegeEscalation: false' not in content:
                    findings.append(Finding("K8S-SEC-002", "HIGH", "Kubernetes", rel, 0,
                        "Missing allowPrivilegeEscalation: false",
                        "Add securityContext.allowPrivilegeEscalation: false"))

                # readOnlyRootFilesystem
                if 'readOnlyRootFilesystem: true' not in content:
                    findings.append(Finding("K8S-SEC-003", "MEDIUM", "Kubernetes", rel, 0,
                        "Missing readOnlyRootFilesystem: true",
                        "Add securityContext.readOnlyRootFilesystem: true"))

                # Resource limits
                if 'limits:' not in content:
                    findings.append(Finding("K8S-RES-001", "HIGH", "Kubernetes", rel, 0,
                        "Missing resource limits — unbounded resource usage",
                        "Add resources.limits for cpu and memory"))

                if 'requests:' not in content:
                    findings.append(Finding("K8S-RES-002", "HIGH", "Kubernetes", rel, 0,
                        "Missing resource requests — scheduler cannot optimize",
                        "Add resources.requests for cpu and memory"))

                # Probes
                if 'readinessProbe:' not in content:
                    findings.append(Finding("K8S-PROBE-001", "HIGH", "Kubernetes", rel, 0,
                        "Missing readinessProbe — traffic routed to unready pods",
                        "Add readinessProbe with httpGet or exec"))

                if 'livenessProbe:' not in content:
                    findings.append(Finding("K8S-PROBE-002", "HIGH", "Kubernetes", rel, 0,
                        "Missing livenessProbe — hung pods not restarted",
                        "Add livenessProbe with httpGet or exec"))

                # Image tags
                for i, line in enumerate(lines, 1):
                    if re.search(r'image:\s*\S+:latest', line):
                        findings.append(Finding("K8S-IMG-001", "HIGH", "Kubernetes", rel, i,
                            "Image uses :latest tag",
                            "Pin to specific version or digest"))

                # Privileged containers
                if 'privileged: true' in content:
                    findings.append(Finding("K8S-SEC-004", "CRITICAL", "Kubernetes", rel, 0,
                        "Container running in privileged mode — full host access",
                        "Remove privileged: true; use specific capabilities"))

    return findings

# ──────────────────────────────────────────────────────────────────────────────
# Engine 5: CI/CD Security
# ──────────────────────────────────────────────────────────────────────────────

def scan_cicd(path: str) -> list:
    findings = []
    workflows_dir = os.path.join(path, '.github', 'workflows')
    if not os.path.isdir(workflows_dir):
        return findings

    for fname in os.listdir(workflows_dir):
        if not fname.endswith(('.yaml', '.yml')):
            continue
        fpath = os.path.join(workflows_dir, fname)
        rel = os.path.relpath(fpath, path)
        try:
            content = open(fpath).read()
            lines = content.splitlines()
        except (PermissionError, OSError):
            continue

        # Permissions block
        if 'permissions:' not in content:
            findings.append(Finding("CICD-PERM-001", "HIGH", "CI/CD", rel, 0,
                "Missing permissions block — workflow has elevated default permissions",
                "Add permissions: block with least-privilege scoping"))

        # Unpinned actions
        for i, line in enumerate(lines, 1):
            if re.search(r'uses:\s*\S+@(main|master|v\d+)$', line.strip()):
                if not re.search(r'uses:\s*\S+@[a-f0-9]{40}', line):
                    findings.append(Finding("CICD-PIN-001", "MEDIUM", "CI/CD", rel, i,
                        "GitHub Action not pinned to SHA — supply chain risk",
                        "Pin to full commit SHA: uses: action@sha256"))

        # Hardcoded secrets
        for i, line in enumerate(lines, 1):
            if re.search(r'(AWS_ACCESS_KEY|AWS_SECRET|AZURE_CLIENT_SECRET)\s*:', line):
                if '${{' not in line:
                    findings.append(Finding("CICD-SEC-001", "CRITICAL", "CI/CD", rel, i,
                        "Hardcoded credential in workflow — use GitHub Secrets",
                        "Use ${{ secrets.SECRET_NAME }}"))

        # OIDC check
        if 'aws-actions/configure-aws-credentials' in content:
            if 'role-to-assume' not in content:
                findings.append(Finding("CICD-OIDC-001", "HIGH", "CI/CD", rel, 0,
                    "AWS credentials without OIDC role assumption",
                    "Use role-to-assume with OIDC instead of static credentials"))

    return findings

# ──────────────────────────────────────────────────────────────────────────────
# Aggregator & Formatters
# ──────────────────────────────────────────────────────────────────────────────

SCAN_TYPES = {
    "secrets": scan_secrets,
    "docker": scan_dockerfiles,
    "terraform": scan_terraform,
    "k8s": scan_kubernetes,
    "cicd": scan_cicd,
}

def run_scan(path: str, scan_type: str = "all") -> list:
    findings = []
    if scan_type == "all":
        for engine in SCAN_TYPES.values():
            findings.extend(engine(path))
    elif scan_type in SCAN_TYPES:
        findings.extend(SCAN_TYPES[scan_type](path))
    return sorted(findings, key=lambda f: {"CRITICAL": 0, "HIGH": 1, "MEDIUM": 2, "LOW": 3, "INFO": 4}[f.severity])

def count_files(path: str) -> int:
    count = 0
    for root, dirs, files in os.walk(path):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        count += len(files)
    return count

def format_text(findings: list, path: str) -> str:
    output = [f"Security Scan Report — {datetime.now().strftime('%Y-%m-%d %H:%M')}",
              f"Scan Path: {path}", f"Files Scanned: {count_files(path)}",
              f"Total Findings: {len(findings)}", ""]
    for f in findings:
        output.append(f"[{f.severity}] {f.rule_id} | {f.category} | {f.file}:{f.line} | {f.description}")
    return '\n'.join(output)

def format_markdown(findings: list, path: str) -> str:
    severity_icons = {"CRITICAL": "🚨", "HIGH": "⚠️", "MEDIUM": "📝", "LOW": "💡", "INFO": "ℹ️"}
    counts = {s: sum(1 for f in findings if f.severity == s) for s in severity_icons}

    output = [f"## 🔒 Security Scan Report",
              f"**Scan Path:** `{path}`",
              f"**Files Scanned:** {count_files(path)}",
              f"**Total Findings:** {len(findings)}", ""]

    for severity in ["CRITICAL", "HIGH", "MEDIUM", "LOW", "INFO"]:
        sev_findings = [f for f in findings if f.severity == severity]
        if sev_findings:
            output.append(f"### {severity_icons[severity]} {severity} ({len(sev_findings)})")
            output.append("| # | Rule | Category | File | Line | Description |")
            output.append("|---|------|----------|------|------|-------------|")
            for idx, f in enumerate(sev_findings, 1):
                output.append(f"| {idx} | {f.rule_id} | {f.category} | {f.file} | {f.line} | {f.description} |")
            output.append("")

    output.extend([
        "### 📊 Summary",
        "| Severity | Count |",
        "|----------|-------|",
        *[f"| {severity_icons[s]} {s} | {counts[s]} |" for s in severity_icons],
        f"| **Total** | **{len(findings)}** |", "",
        f"### Verdict: {'❌ AT RISK' if counts.get('CRITICAL', 0) > 0 else '⚠️ NEEDS REVIEW' if counts.get('HIGH', 0) > 0 else '✅ SECURE'}",
    ])
    return '\n'.join(output)

def format_json(findings: list, path: str) -> str:
    return json.dumps({
        "scan_date": datetime.now().isoformat(),
        "scan_path": path,
        "files_scanned": count_files(path),
        "total_findings": len(findings),
        "findings": [f.to_dict() for f in findings]
    }, indent=2)

# ──────────────────────────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="HealthCloud Security Scanner")
    parser.add_argument("--path", required=True, help="Path to scan")
    parser.add_argument("--type", default="all", choices=["all", *SCAN_TYPES.keys()], help="Scan type")
    parser.add_argument("--format", default="markdown", choices=["text", "markdown", "json"], help="Output format")
    args = parser.parse_args()

    if not os.path.exists(args.path):
        print(f"Error: Path '{args.path}' does not exist", file=sys.stderr)
        sys.exit(1)

    findings = run_scan(args.path, args.type)

    formatters = {"text": format_text, "markdown": format_markdown, "json": format_json}
    print(formatters[args.format](findings, args.path))

    critical = sum(1 for f in findings if f.severity == "CRITICAL")
    high = sum(1 for f in findings if f.severity == "HIGH")
    sys.exit(2 if critical > 0 else 1 if high > 0 else 0)

if __name__ == "__main__":
    main()
