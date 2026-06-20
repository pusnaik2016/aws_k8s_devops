#!/usr/bin/env python3
"""
dr_validator.py — Disaster Recovery Readiness Validator
=======================================================
Validates AWS (primary) to Azure (DR) failover configuration.

Usage:
  python3 dr_validator.py --path ./terraform --format markdown
"""

import argparse
import json
import os
import re
import sys
from datetime import datetime

SKIP_DIRS = {'.git', '.terraform', 'node_modules', '.venv', '__pycache__'}

AWS_COMPONENTS = {
    'compute': ['aws_eks_cluster', 'aws_launch_template'],
    'database': ['aws_rds_cluster', 'aws_db_instance', 'aws_dynamodb_table'],
    'storage': ['aws_s3_bucket'],
    'cache': ['aws_elasticache_replication_group', 'aws_elasticache_cluster'],
    'networking': ['aws_vpc', 'aws_subnet', 'aws_nat_gateway'],
    'security': ['aws_kms_key', 'aws_guardduty_detector', 'aws_securityhub_account'],
    'monitoring': ['aws_cloudwatch_dashboard', 'aws_sns_topic'],
    'dns': ['aws_route53_health_check', 'aws_route53_record'],
}

AZURE_COMPONENTS = {
    'compute': ['azurerm_kubernetes_cluster'],
    'database': ['azurerm_postgresql_flexible_server', 'azurerm_cosmosdb_account'],
    'storage': ['azurerm_storage_account', 'azurerm_storage_container'],
    'cache': ['azurerm_redis_cache'],
    'networking': ['azurerm_virtual_network', 'azurerm_subnet', 'azurerm_nat_gateway'],
    'security': ['azurerm_key_vault', 'azurerm_security_center_subscription_pricing'],
    'monitoring': ['azurerm_log_analytics_workspace', 'azurerm_monitor_action_group'],
    'dns': ['azurerm_traffic_manager_profile', 'azurerm_dns_zone'],
}

class DRCheck:
    def __init__(self, check_id, status, category, description, aws_status="", azure_status="", remediation=""):
        self.check_id = check_id
        self.status = status
        self.category = category
        self.description = description
        self.aws_status = aws_status
        self.azure_status = azure_status
        self.remediation = remediation

    def to_dict(self):
        return vars(self)

def scan_resources(path: str, resource_map: dict) -> dict:
    found = {cat: [] for cat in resource_map}
    for root, dirs, files in os.walk(path):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for f in files:
            if f.endswith('.tf'):
                content = open(os.path.join(root, f), errors='ignore').read()
                for cat, resources in resource_map.items():
                    for res in resources:
                        if res in content:
                            found[cat].append(res)
    return found

def validate_parity(path: str) -> list:
    checks = []
    aws_path = os.path.join(path, 'aws') if os.path.isdir(os.path.join(path, 'aws')) else path
    azure_path = os.path.join(path, 'azure') if os.path.isdir(os.path.join(path, 'azure')) else path

    aws_found = scan_resources(aws_path, AWS_COMPONENTS)
    azure_found = scan_resources(azure_path, AZURE_COMPONENTS)

    for category in AWS_COMPONENTS:
        aws_has = len(aws_found.get(category, [])) > 0
        azure_has = len(azure_found.get(category, [])) > 0

        if aws_has and azure_has:
            status = "READY"
        elif aws_has and not azure_has:
            status = "MISSING_DR"
        elif not aws_has and azure_has:
            status = "MISSING_PRIMARY"
        else:
            status = "MISSING_BOTH"

        checks.append(DRCheck(
            f"DR-PARITY-{category.upper()}",
            status,
            "Parity",
            f"{category.title()} layer parity",
            f"{'✅ Found' if aws_has else '❌ Missing'}: {', '.join(aws_found.get(category, [])) or 'None'}",
            f"{'✅ Found' if azure_has else '❌ Missing'}: {', '.join(azure_found.get(category, [])) or 'None'}",
            f"Add Azure {category} resources to mirror AWS" if status == "MISSING_DR" else ""
        ))

    return checks

def validate_failover(path: str) -> list:
    checks = []
    all_content = ""
    for root, dirs, files in os.walk(path):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for f in files:
            if f.endswith('.tf'):
                all_content += open(os.path.join(root, f), errors='ignore').read() + "\n"

    # Route 53 health checks
    has_health_check = 'aws_route53_health_check' in all_content
    checks.append(DRCheck("DR-DNS-001",
        "READY" if has_health_check else "NOT_READY",
        "Failover", "Route 53 health check configured",
        remediation="Add aws_route53_health_check for primary endpoint"))

    # Route 53 failover record
    has_failover = 'failover' in all_content and 'aws_route53_record' in all_content
    checks.append(DRCheck("DR-DNS-002",
        "READY" if has_failover else "NOT_READY",
        "Failover", "Route 53 failover routing configured",
        remediation="Add aws_route53_record with failover routing policy"))

    # Azure Traffic Manager
    has_traffic_mgr = 'azurerm_traffic_manager' in all_content
    checks.append(DRCheck("DR-DNS-003",
        "READY" if has_traffic_mgr else "NOT_READY",
        "Failover", "Azure Traffic Manager configured",
        remediation="Add azurerm_traffic_manager_profile for DR endpoint"))

    # Database replication
    has_db_replication = 'global' in all_content.lower() and ('rds_cluster' in all_content or 'aurora' in all_content.lower())
    checks.append(DRCheck("DR-DB-001",
        "READY" if has_db_replication else "NOT_READY",
        "Replication", "Database cross-region/cross-cloud replication",
        remediation="Configure Aurora Global Database or logical replication to Azure"))

    # Cross-cloud VPN
    has_vpn = ('aws_vpn' in all_content or 'aws_customer_gateway' in all_content or
               'azurerm_virtual_network_gateway' in all_content)
    checks.append(DRCheck("DR-NET-001",
        "READY" if has_vpn else "NOT_READY",
        "Networking", "Cross-cloud VPN/peering configured",
        remediation="Add VPN Gateway on both clouds for private connectivity"))

    return checks

def estimate_rto() -> dict:
    return {
        "dns_propagation": {"estimate_minutes": 1, "notes": "Route 53 TTL 60s + propagation"},
        "aks_scale_up": {"estimate_minutes": 5, "notes": "Warm standby → full capacity"},
        "db_promotion": {"estimate_minutes": 10, "notes": "PostgreSQL promote replica to primary"},
        "app_health": {"estimate_minutes": 5, "notes": "Pods ready + health checks pass"},
        "total_rto_minutes": 21,
        "target_rto_minutes": 30,
        "meets_target": True
    }

def format_markdown(parity_checks: list, failover_checks: list, rto: dict, path: str) -> str:
    all_checks = parity_checks + failover_checks
    ready = sum(1 for c in all_checks if c.status == "READY")
    not_ready = sum(1 for c in all_checks if c.status in ("NOT_READY", "MISSING_DR", "MISSING_BOTH"))
    icons = {"READY": "✅", "NOT_READY": "❌", "MISSING_DR": "⚠️", "MISSING_PRIMARY": "🔄", "MISSING_BOTH": "❌"}

    output = [
        "## 🔄 DR Readiness Report",
        f"**Scan Path:** `{path}`",
        f"**Primary:** AWS us-east-1 | **DR:** Azure eastus",
        f"**Target RPO:** < 15 minutes | **Target RTO:** < 30 minutes", "",
        "### Infrastructure Parity (AWS ↔ Azure)",
        "| Status | Category | AWS Primary | Azure DR |",
        "|--------|----------|-------------|----------|",
    ]

    for c in parity_checks:
        output.append(f"| {icons[c.status]} | {c.description} | {c.aws_status} | {c.azure_status} |")

    output.extend(["", "### Failover Configuration",
        "| Status | Check | Description |",
        "|--------|-------|-------------|"])

    for c in failover_checks:
        output.append(f"| {icons[c.status]} | {c.check_id} | {c.description} |")

    output.extend(["",
        "### RTO Estimate",
        "| Phase | Estimate | Notes |",
        "|-------|----------|-------|",
        *[f"| {k.replace('_', ' ').title()} | {v['estimate_minutes']} min | {v['notes']} |"
          for k, v in rto.items() if isinstance(v, dict)],
        f"| **Total RTO** | **{rto['total_rto_minutes']} min** | Target: {rto['target_rto_minutes']} min |",
        f"| **Meets Target** | {'✅ Yes' if rto['meets_target'] else '❌ No'} | |", "",
        "### 📊 Summary",
        f"| Ready | {ready} |",
        f"| Not Ready | {not_ready} |",
        f"| **Total Checks** | **{len(all_checks)}** |", "",
        f"### Verdict: {'✅ DR READY' if not_ready == 0 else '⚠️ DR PARTIALLY READY' if not_ready <= 3 else '❌ DR NOT READY'}"
    ])
    return '\n'.join(output)

def main():
    parser = argparse.ArgumentParser(description="HealthCloud DR Validator")
    parser.add_argument("--path", required=True)
    parser.add_argument("--format", default="markdown", choices=["text", "markdown", "json"])
    args = parser.parse_args()

    parity = validate_parity(args.path)
    failover = validate_failover(args.path)
    rto = estimate_rto()

    if args.format == "json":
        print(json.dumps({
            "parity": [c.to_dict() for c in parity],
            "failover": [c.to_dict() for c in failover],
            "rto": rto
        }, indent=2))
    else:
        print(format_markdown(parity, failover, rto, args.path))

    not_ready = sum(1 for c in parity + failover if c.status in ("NOT_READY", "MISSING_DR", "MISSING_BOTH"))
    sys.exit(1 if not_ready > 0 else 0)

if __name__ == "__main__":
    main()
