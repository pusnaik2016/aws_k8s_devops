#!/usr/bin/env python3
"""
tf_helper.py — Terraform Validation Helper for Multi-Cloud Healthcare
=====================================================================
Zero-dependency Terraform structure and compliance validator.

Usage:
  python3 tf_helper.py --path ./terraform --format markdown
"""

import argparse
import json
import os
import re
import sys
from datetime import datetime

SKIP_DIRS = {'.git', '.terraform', 'node_modules', '.venv', '__pycache__'}
REQUIRED_FILES = {'main.tf', 'variables.tf', 'outputs.tf'}
REQUIRED_TAGS = {'Environment', 'Project', 'ManagedBy', 'Owner', 'Compliance', 'DataClassification'}

class Check:
    def __init__(self, rule_id, status, category, module, description, remediation=""):
        self.rule_id = rule_id
        self.status = status
        self.category = category
        self.module = module
        self.description = description
        self.remediation = remediation

    def to_dict(self):
        return vars(self)

def find_tf_modules(path: str) -> list:
    modules = []
    for root, dirs, files in os.walk(path):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        tf_files = [f for f in files if f.endswith('.tf')]
        if tf_files:
            modules.append(root)
    return modules

def validate_module(module_path: str, base_path: str) -> list:
    checks = []
    rel = os.path.relpath(module_path, base_path)
    files = set(os.listdir(module_path))
    tf_files = {f for f in files if f.endswith('.tf')}

    # Structure checks
    for req in REQUIRED_FILES:
        checks.append(Check(
            f"TF-STRUCT-{req.replace('.tf','').upper()}",
            "PASS" if req in tf_files else "WARN",
            "Structure", rel, f"{req} {'exists' if req in tf_files else 'missing'}",
            f"Create {req} in {rel}"))

    # Read all .tf content
    all_content = ""
    for tf in tf_files:
        try:
            all_content += open(os.path.join(module_path, tf)).read() + "\n"
        except (PermissionError, OSError):
            continue

    # Provider version pinning
    if 'required_providers' in all_content or 'provider' in all_content:
        has_version = 'version' in all_content or 'required_version' in all_content
        checks.append(Check("TF-VER-001",
            "PASS" if has_version else "WARN",
            "Versioning", rel, "Provider/Terraform version pinned",
            "Pin provider versions in required_providers block"))

    # Backend configuration
    if 'backend' in all_content:
        checks.append(Check("TF-STATE-001", "PASS", "State", rel,
            "Backend configuration found"))
        if 'encrypt' in all_content or 'encryption' in all_content:
            checks.append(Check("TF-STATE-002", "PASS", "State", rel,
                "State encryption configured"))
        else:
            checks.append(Check("TF-STATE-002", "WARN", "State", rel,
                "State encryption not explicitly configured",
                "Add encrypt = true for S3 backend"))

    # Sensitive variables
    sensitive_vars = re.findall(r'variable\s+"(\w*(?:password|secret|key|token)\w*)"', all_content, re.IGNORECASE)
    for var in sensitive_vars:
        has_sensitive = bool(re.search(rf'variable\s+"{var}"[^{{]*{{[^}}]*sensitive\s*=\s*true', all_content, re.DOTALL))
        checks.append(Check("TF-SENS-001",
            "PASS" if has_sensitive else "FAIL",
            "Security", rel, f"Variable '{var}' marked sensitive",
            f"Add sensitive = true to variable \"{var}\""))

    # Tag compliance (check resource blocks)
    resource_blocks = re.findall(r'resource\s+"(\S+)"\s+"(\S+)"', all_content)
    for rtype, rname in resource_blocks[:5]:  # Check first 5 resources
        # Find resource block and check for tags
        block_match = re.search(rf'resource\s+"{re.escape(rtype)}"\s+"{re.escape(rname)}"' + r'\s*\{([^}]*(?:\{[^}]*\}[^}]*)*)\}', all_content)
        if block_match:
            block = block_match.group(1)
            has_tags = 'tags' in block
            checks.append(Check("TF-TAG-001",
                "PASS" if has_tags else "WARN",
                "Tags", rel, f"{rtype}.{rname} has tags block",
                "Add tags with Environment, Project, ManagedBy, Owner"))

    # Hardcoded values
    hardcoded_regions = re.findall(r'region\s*=\s*"(us-\S+|eu-\S+|ap-\S+)"', all_content)
    for region in hardcoded_regions:
        checks.append(Check("TF-HARD-001", "WARN", "Hardcoding", rel,
            f"Hardcoded region: {region}",
            "Use var.region instead of hardcoded region string"))

    hardcoded_accounts = re.findall(r'\d{12}', all_content)
    for acct in hardcoded_accounts:
        checks.append(Check("TF-HARD-002", "WARN", "Hardcoding", rel,
            f"Possible hardcoded AWS account ID: {acct}",
            "Use data.aws_caller_identity or var.account_id"))

    return checks

def scan_terraform(path: str) -> list:
    modules = find_tf_modules(path)
    all_checks = []
    for mod in modules:
        all_checks.extend(validate_module(mod, path))
    return all_checks

def format_markdown(checks: list, path: str) -> str:
    passed = sum(1 for c in checks if c.status == "PASS")
    warned = sum(1 for c in checks if c.status == "WARN")
    failed = sum(1 for c in checks if c.status == "FAIL")
    icons = {"PASS": "✅", "WARN": "⚠️", "FAIL": "❌"}
    modules = find_tf_modules(path)

    output = [
        "## 🏗️ Terraform Validation Report",
        f"**Scan Path:** `{path}`",
        f"**Modules Found:** {len(modules)}",
        f"**Total Checks:** {len(checks)}", ""
    ]

    for category in sorted(set(c.category for c in checks)):
        cat_checks = [c for c in checks if c.category == category]
        output.append(f"### {category}")
        output.append("| Status | Rule | Module | Description |")
        output.append("|--------|------|--------|-------------|")
        for c in cat_checks:
            output.append(f"| {icons[c.status]} | {c.rule_id} | {c.module} | {c.description} |")
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

def main():
    parser = argparse.ArgumentParser(description="HealthCloud Terraform Validator")
    parser.add_argument("--path", required=True)
    parser.add_argument("--format", default="markdown", choices=["text", "markdown", "json"])
    args = parser.parse_args()

    checks = scan_terraform(args.path)
    if args.format == "json":
        print(json.dumps({"checks": [c.to_dict() for c in checks]}, indent=2))
    else:
        print(format_markdown(checks, args.path))

    sys.exit(1 if any(c.status == "FAIL" for c in checks) else 0)

if __name__ == "__main__":
    main()
