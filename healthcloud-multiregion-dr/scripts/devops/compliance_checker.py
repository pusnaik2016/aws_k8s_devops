#!/usr/bin/env python3
"""
compliance_checker.py — HIPAA/GDPR Compliance Checker for Healthcare Platform
==============================================================================
Validates infrastructure and application code for healthcare compliance.

Usage:
  python3 compliance_checker.py --path . --format markdown
"""

import argparse
import json
import os
import re
import sys
from datetime import datetime

SKIP_DIRS = {'.git', '.terraform', 'node_modules', '.venv', '__pycache__', '.pytest_cache'}

class ComplianceCheck:
    def __init__(self, control_id, framework, status, description, evidence="", remediation=""):
        self.control_id = control_id
        self.framework = framework  # HIPAA, GDPR, SOC2
        self.status = status  # COMPLIANT, NON_COMPLIANT, PARTIAL, NOT_ASSESSED
        self.description = description
        self.evidence = evidence
        self.remediation = remediation

    def to_dict(self):
        return vars(self)

def check_encryption_at_rest(path: str) -> list:
    checks = []
    has_kms = False
    has_keyvault = False
    for root, dirs, files in os.walk(path):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for f in files:
            if f.endswith('.tf'):
                content = open(os.path.join(root, f), errors='ignore').read()
                if 'aws_kms_key' in content or 'kms_key_id' in content:
                    has_kms = True
                if 'azurerm_key_vault' in content or 'key_vault_key_id' in content:
                    has_keyvault = True

    checks.append(ComplianceCheck("HIPAA-164.312(a)(2)(iv)", "HIPAA",
        "COMPLIANT" if has_kms else "NON_COMPLIANT",
        "Encryption at rest (AWS KMS)",
        f"KMS key references found: {has_kms}",
        "Add aws_kms_key and reference in storage/database resources"))

    checks.append(ComplianceCheck("HIPAA-164.312(a)(2)(iv)-AZ", "HIPAA",
        "COMPLIANT" if has_keyvault else "NON_COMPLIANT",
        "Encryption at rest (Azure Key Vault)",
        f"Key Vault references found: {has_keyvault}",
        "Add azurerm_key_vault and CMK for Azure resources"))

    return checks

def check_encryption_in_transit(path: str) -> list:
    checks = []
    has_tls = False
    has_mtls = False
    for root, dirs, files in os.walk(path):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for f in files:
            fpath = os.path.join(root, f)
            if f.endswith(('.tf', '.yaml', '.yml')):
                content = open(fpath, errors='ignore').read()
                if 'ssl_policy' in content or 'tls' in content.lower():
                    has_tls = True
                if 'PeerAuthentication' in content and 'STRICT' in content:
                    has_mtls = True

    checks.append(ComplianceCheck("HIPAA-164.312(e)(1)", "HIPAA",
        "COMPLIANT" if has_tls else "NON_COMPLIANT",
        "Encryption in transit (TLS)",
        f"TLS configuration found: {has_tls}"))

    checks.append(ComplianceCheck("HIPAA-164.312(e)(1)-MESH", "HIPAA",
        "COMPLIANT" if has_mtls else "PARTIAL",
        "Service-to-service mTLS (Istio STRICT)",
        f"mTLS STRICT mode found: {has_mtls}",
        "Deploy Istio PeerAuthentication with STRICT mTLS"))

    return checks

def check_audit_logging(path: str) -> list:
    checks = []
    has_cloudtrail = False
    has_azure_log = False
    for root, dirs, files in os.walk(path):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for f in files:
            if f.endswith('.tf'):
                content = open(os.path.join(root, f), errors='ignore').read()
                if 'aws_cloudtrail' in content:
                    has_cloudtrail = True
                if 'azurerm_monitor_diagnostic_setting' in content or 'azurerm_log_analytics' in content:
                    has_azure_log = True

    checks.append(ComplianceCheck("HIPAA-164.312(b)", "HIPAA",
        "COMPLIANT" if has_cloudtrail else "NON_COMPLIANT",
        "Audit logging (AWS CloudTrail)",
        f"CloudTrail configured: {has_cloudtrail}",
        "Add aws_cloudtrail resource with S3 storage"))

    checks.append(ComplianceCheck("HIPAA-164.312(b)-AZ", "HIPAA",
        "COMPLIANT" if has_azure_log else "NON_COMPLIANT",
        "Audit logging (Azure Monitor/Log Analytics)",
        f"Azure logging configured: {has_azure_log}"))

    return checks

def check_access_controls(path: str) -> list:
    checks = []
    has_rbac = False
    has_network_policy = False
    for root, dirs, files in os.walk(path):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for f in files:
            if f.endswith(('.yaml', '.yml')):
                content = open(os.path.join(root, f), errors='ignore').read()
                if 'kind: Role' in content or 'kind: ClusterRole' in content:
                    has_rbac = True
                if 'kind: NetworkPolicy' in content:
                    has_network_policy = True

    checks.append(ComplianceCheck("HIPAA-164.312(a)(1)", "HIPAA",
        "COMPLIANT" if has_rbac else "NON_COMPLIANT",
        "Access controls (K8s RBAC)",
        f"RBAC definitions found: {has_rbac}"))

    checks.append(ComplianceCheck("HIPAA-164.312(a)(1)-NET", "HIPAA",
        "COMPLIANT" if has_network_policy else "NON_COMPLIANT",
        "Network segmentation (NetworkPolicy)",
        f"NetworkPolicy found: {has_network_policy}",
        "Add default-deny NetworkPolicy for all namespaces"))

    return checks

def check_phi_handling(path: str) -> list:
    checks = []
    phi_in_code = False
    for root, dirs, files in os.walk(path):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for f in files:
            if f.endswith(('.py', '.java', '.yaml', '.yml', '.tf')):
                fpath = os.path.join(root, f)
                if 'docs/' in fpath or 'README' in f or 'ARCHITECTURE' in f:
                    continue
                content = open(fpath, errors='ignore').read()
                phi_patterns = ['patient_name', 'social_security', 'ssn',
                               'medical_record_number', 'health_insurance_id']
                for pattern in phi_patterns:
                    if re.search(pattern, content, re.IGNORECASE):
                        if 'variable' not in content[:content.find(pattern)+len(pattern)].split('\n')[-1]:
                            phi_in_code = True

    checks.append(ComplianceCheck("HIPAA-164.502", "HIPAA",
        "NON_COMPLIANT" if phi_in_code else "COMPLIANT",
        "No PHI in application/infrastructure code",
        f"PHI patterns in code: {phi_in_code}",
        "Use tokenization and reference PHI by ID only"))

    return checks

def check_data_residency(path: str) -> list:
    checks = []
    has_scp = False
    has_policy = False
    for root, dirs, files in os.walk(path):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for f in files:
            if f.endswith('.tf'):
                content = open(os.path.join(root, f), errors='ignore').read()
                if 'aws_organizations_policy' in content and 'deny' in content.lower():
                    has_scp = True
                if 'azurerm_policy_assignment' in content:
                    has_policy = True

    checks.append(ComplianceCheck("GDPR-Art44", "GDPR",
        "COMPLIANT" if has_scp or has_policy else "PARTIAL",
        "Data residency enforcement (SCP/Azure Policy)",
        f"SCP: {has_scp}, Azure Policy: {has_policy}",
        "Add SCPs to restrict data to approved regions"))

    return checks

def run_compliance_audit(path: str) -> list:
    all_checks = []
    all_checks.extend(check_encryption_at_rest(path))
    all_checks.extend(check_encryption_in_transit(path))
    all_checks.extend(check_audit_logging(path))
    all_checks.extend(check_access_controls(path))
    all_checks.extend(check_phi_handling(path))
    all_checks.extend(check_data_residency(path))
    return all_checks

def format_markdown(checks: list, path: str) -> str:
    compliant = sum(1 for c in checks if c.status == "COMPLIANT")
    non_compliant = sum(1 for c in checks if c.status == "NON_COMPLIANT")
    partial = sum(1 for c in checks if c.status == "PARTIAL")
    icons = {"COMPLIANT": "✅", "NON_COMPLIANT": "❌", "PARTIAL": "⚠️", "NOT_ASSESSED": "⏭️"}

    score = int((compliant / max(len(checks), 1)) * 100)

    output = [
        "## 🏥 Healthcare Compliance Report",
        f"**Scan Path:** `{path}`",
        f"**Compliance Score:** {score}%",
        f"**Frameworks:** HIPAA, GDPR, SOC 2", ""
    ]

    for framework in sorted(set(c.framework for c in checks)):
        fw_checks = [c for c in checks if c.framework == framework]
        output.append(f"### {framework} Controls")
        output.append("| Status | Control ID | Description | Evidence |")
        output.append("|--------|-----------|-------------|----------|")
        for c in fw_checks:
            output.append(f"| {icons[c.status]} | {c.control_id} | {c.description} | {c.evidence} |")
        output.append("")

    output.extend([
        "### 📊 Summary",
        "| Status | Count |",
        "|--------|-------|",
        f"| ✅ Compliant | {compliant} |",
        f"| ⚠️ Partial | {partial} |",
        f"| ❌ Non-Compliant | {non_compliant} |",
        f"| **Compliance Score** | **{score}%** |", "",
        f"### Verdict: {'✅ COMPLIANT' if non_compliant == 0 else '⚠️ PARTIALLY COMPLIANT' if non_compliant <= 2 else '❌ NON-COMPLIANT'}"
    ])
    return '\n'.join(output)

def main():
    parser = argparse.ArgumentParser(description="HealthCloud Compliance Checker")
    parser.add_argument("--path", required=True)
    parser.add_argument("--format", default="markdown", choices=["text", "markdown", "json"])
    args = parser.parse_args()

    checks = run_compliance_audit(args.path)
    if args.format == "json":
        print(json.dumps({"checks": [c.to_dict() for c in checks]}, indent=2))
    else:
        print(format_markdown(checks, args.path))

    non_compliant = sum(1 for c in checks if c.status == "NON_COMPLIANT")
    sys.exit(1 if non_compliant > 0 else 0)

if __name__ == "__main__":
    main()
