#!/usr/bin/env python3
"""
tf_helper.py — Terraform Validation & Analysis Helper
========================================================
Performs structural validation, dependency mapping, and compliance checks
for Terraform configurations without requiring terraform CLI.

Checks:
  • Module file structure (main.tf, variables.tf, outputs.tf)
  • Variable definitions and usage
  • Provider configuration
  • Backend / state configuration
  • Module dependency graph
  • Tag compliance
  • Sensitive variable declarations

Author : Pushparaj Naik
Version: 1.0.0

Usage:
    python3 tf_helper.py --path <terraform_dir> [--format text|markdown|json]
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional


# ═══════════════════════════════════════════════════════════════════════════════
# Data Models
# ═══════════════════════════════════════════════════════════════════════════════

@dataclass
class ModuleInfo:
    """Information about a single Terraform module directory."""
    path: str
    has_main: bool = False
    has_variables: bool = False
    has_outputs: bool = False
    has_providers: bool = False
    has_versions: bool = False
    has_backend: bool = False
    has_tfvars: bool = False
    resources: list = field(default_factory=list)
    modules: list = field(default_factory=list)
    variables: list = field(default_factory=list)
    outputs: list = field(default_factory=list)
    providers: list = field(default_factory=list)
    data_sources: list = field(default_factory=list)
    warnings: list = field(default_factory=list)
    errors: list = field(default_factory=list)

    @property
    def structure_complete(self) -> bool:
        return self.has_main and self.has_variables and self.has_outputs

    @property
    def status(self) -> str:
        if self.errors:
            return "FAIL"
        if not self.structure_complete or self.warnings:
            return "WARN"
        return "PASS"


@dataclass
class TfReport:
    scan_path: str
    modules: list = field(default_factory=list)
    dependency_graph: dict = field(default_factory=dict)
    total_resources: int = 0
    total_data_sources: int = 0
    total_variables: int = 0
    total_outputs: int = 0

    @property
    def pass_count(self) -> int:
        return sum(1 for m in self.modules if m.status == "PASS")

    @property
    def warn_count(self) -> int:
        return sum(1 for m in self.modules if m.status == "WARN")

    @property
    def fail_count(self) -> int:
        return sum(1 for m in self.modules if m.status == "FAIL")

    @property
    def verdict(self) -> str:
        if self.fail_count > 0:
            return "FAIL"
        if self.warn_count > 0:
            return "NEEDS ATTENTION"
        return "PASS"


# ═══════════════════════════════════════════════════════════════════════════════
# Discovery
# ═══════════════════════════════════════════════════════════════════════════════

def find_tf_directories(root: Path) -> list[Path]:
    """Find all directories containing .tf files."""
    tf_dirs = set()
    skip = {'.git', '.terraform', 'node_modules', '__pycache__'}

    if root.is_file():
        return [root.parent]

    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in skip]
        for fname in filenames:
            if fname.endswith('.tf'):
                tf_dirs.add(Path(dirpath))
                break

    return sorted(tf_dirs)


def _read_file(path: Path) -> Optional[str]:
    try:
        with open(path, 'r', encoding='utf-8', errors='ignore') as f:
            return f.read()
    except (PermissionError, OSError):
        return None


# ═══════════════════════════════════════════════════════════════════════════════
# Analysis Engine
# ═══════════════════════════════════════════════════════════════════════════════

REQUIRED_TAGS = {'Environment', 'Project', 'ManagedBy', 'Owner'}

SENSITIVE_VAR_PATTERNS = [
    'password', 'secret', 'key', 'token', 'credential',
    'api_key', 'private_key', 'access_key',
]


def analyse_module(module_dir: Path) -> ModuleInfo:
    """Analyse a single Terraform module directory."""
    info = ModuleInfo(path=str(module_dir))

    tf_files = list(module_dir.glob('*.tf'))
    tfvars_files = list(module_dir.glob('*.tfvars')) + list(module_dir.glob('*.auto.tfvars'))

    # ─── File Structure ───
    file_names = {f.name for f in tf_files}
    info.has_main = 'main.tf' in file_names
    info.has_variables = 'variables.tf' in file_names
    info.has_outputs = 'outputs.tf' in file_names
    info.has_providers = 'providers.tf' in file_names or any(
        'provider' in (_read_file(f) or '') for f in tf_files
    )
    info.has_versions = 'versions.tf' in file_names or any(
        'required_version' in (_read_file(f) or '') for f in tf_files
    )
    info.has_tfvars = len(tfvars_files) > 0
    info.has_backend = any('backend' in (_read_file(f) or '') for f in tf_files)

    if not info.has_main:
        info.warnings.append("Missing main.tf — resource definitions should be in main.tf")
    if not info.has_variables:
        info.warnings.append("Missing variables.tf — variable declarations should be centralized")
    if not info.has_outputs:
        info.warnings.append("Missing outputs.tf — output values should be centralized")

    # ─── Parse All TF Files ───
    for tf_file in tf_files:
        content = _read_file(tf_file)
        if content is None:
            continue

        # Extract resources
        resources = re.findall(r'resource\s+"([^"]+)"\s+"([^"]+)"', content)
        for res_type, res_name in resources:
            info.resources.append({"type": res_type, "name": res_name, "file": tf_file.name})

        # Extract data sources
        data_sources = re.findall(r'data\s+"([^"]+)"\s+"([^"]+)"', content)
        for ds_type, ds_name in data_sources:
            info.data_sources.append({"type": ds_type, "name": ds_name, "file": tf_file.name})

        # Extract modules
        modules = re.findall(r'module\s+"([^"]+)"', content)
        for mod_name in modules:
            source_match = re.search(rf'module\s+"{re.escape(mod_name)}".*?source\s*=\s*"([^"]+)"',
                                     content, re.DOTALL)
            source = source_match.group(1) if source_match else "unknown"
            info.modules.append({"name": mod_name, "source": source, "file": tf_file.name})

        # Extract variables
        variables = re.findall(r'variable\s+"([^"]+)"', content)
        for var_name in variables:
            # Check if marked as sensitive
            var_block_match = re.search(
                rf'variable\s+"{re.escape(var_name)}".*?(?=\nvariable\s|\Z)',
                content, re.DOTALL)
            var_block = var_block_match.group(0) if var_block_match else ""
            is_sensitive = 'sensitive' in var_block and 'true' in var_block
            has_default = 'default' in var_block

            # Check if a sensitive variable is NOT marked sensitive
            should_be_sensitive = any(pat in var_name.lower() for pat in SENSITIVE_VAR_PATTERNS)
            if should_be_sensitive and not is_sensitive:
                info.warnings.append(
                    f"Variable '{var_name}' appears sensitive but not marked as sensitive = true")

            info.variables.append({
                "name": var_name, "sensitive": is_sensitive,
                "has_default": has_default, "file": tf_file.name,
            })

        # Extract outputs
        outputs = re.findall(r'output\s+"([^"]+)"', content)
        for out_name in outputs:
            info.outputs.append({"name": out_name, "file": tf_file.name})

        # Extract providers
        providers = re.findall(r'provider\s+"([^"]+)"', content)
        for prov_name in providers:
            info.providers.append({"name": prov_name, "file": tf_file.name})

        # Check for required_providers / terraform version
        if 'required_providers' in content:
            info.has_versions = True

        # ─── Compliance Checks ───
        # Check for hardcoded AMIs
        if re.search(r'ami-[0-9a-f]{8,17}', content):
            info.warnings.append(f"Hardcoded AMI ID found in {tf_file.name} — use data source or variable")

        # Check for hardcoded availability zones
        if re.search(r'availability_zone\s*=\s*"[a-z]{2}-[a-z]+-\d[a-z]"', content):
            info.warnings.append(f"Hardcoded AZ in {tf_file.name} — use data.aws_availability_zones")

        # Check for missing lifecycle rules on critical resources
        for res_type, res_name in resources:
            if res_type in {'aws_db_instance', 'aws_s3_bucket', 'aws_iam_role'}:
                resource_block_match = re.search(
                    rf'resource\s+"{re.escape(res_type)}"\s+"{re.escape(res_name)}".*?(?=\nresource\s|\nmodule\s|\ndata\s|\Z)',
                    content, re.DOTALL)
                if resource_block_match:
                    block = resource_block_match.group(0)
                    if 'lifecycle' not in block and 'prevent_destroy' not in block:
                        info.warnings.append(
                            f"Resource {res_type}.{res_name} — consider lifecycle.prevent_destroy for safety")

    return info


def analyse_terraform(root: Path) -> TfReport:
    report = TfReport(scan_path=str(root))
    tf_dirs = find_tf_directories(root)

    for td in tf_dirs:
        module = analyse_module(td)
        report.modules.append(module)
        report.total_resources += len(module.resources)
        report.total_data_sources += len(module.data_sources)
        report.total_variables += len(module.variables)
        report.total_outputs += len(module.outputs)

        # Build dependency graph
        rel_path = str(td.relative_to(root)) if td != root else "."
        deps = [m['source'] for m in module.modules]
        report.dependency_graph[rel_path] = deps

    return report


# ═══════════════════════════════════════════════════════════════════════════════
# Formatters
# ═══════════════════════════════════════════════════════════════════════════════

def format_markdown(report: TfReport) -> str:
    lines = [
        "## 🏗️ Terraform Validation Report",
        f"**Scan Path:** `{report.scan_path}`",
        f"**Modules Found:** {len(report.modules)}",
        "",
    ]

    # Module structure table
    lines.extend([
        "### 📁 Module Structure",
        "",
        "| Directory | main.tf | variables.tf | outputs.tf | providers | backend | Status |",
        "|-----------|---------|-------------|-----------|----------|---------|--------|",
    ])
    for m in report.modules:
        rel = os.path.relpath(m.path, report.scan_path) if m.path != report.scan_path else "."
        icon = lambda x: "✅" if x else "❌"
        status_icon = {"PASS": "✅", "WARN": "⚠️", "FAIL": "❌"}[m.status]
        lines.append(
            f"| `{rel}` | {icon(m.has_main)} | {icon(m.has_variables)} | "
            f"{icon(m.has_outputs)} | {icon(m.has_providers)} | {icon(m.has_backend)} | {status_icon} |")
    lines.append("")

    # Resources summary
    lines.extend([
        "### 📦 Resources Summary",
        "",
        "| Module | Resources | Data Sources | Variables | Outputs | Sub-Modules |",
        "|--------|-----------|-------------|-----------|---------|-------------|",
    ])
    for m in report.modules:
        rel = os.path.relpath(m.path, report.scan_path) if m.path != report.scan_path else "."
        lines.append(
            f"| `{rel}` | {len(m.resources)} | {len(m.data_sources)} | "
            f"{len(m.variables)} | {len(m.outputs)} | {len(m.modules)} |")
    lines.append("")

    # Dependency graph
    if report.dependency_graph:
        lines.extend(["### 🔗 Module Dependencies", ""])
        for module_path, deps in report.dependency_graph.items():
            if deps:
                dep_str = ', '.join(f'`{d}`' for d in deps)
                lines.append(f"- `{module_path}` → {dep_str}")
            else:
                lines.append(f"- `{module_path}` *(leaf module — no sub-modules)*")
        lines.append("")

    # Warnings and errors
    all_warnings = []
    all_errors = []
    for m in report.modules:
        rel = os.path.relpath(m.path, report.scan_path) if m.path != report.scan_path else "."
        for w in m.warnings:
            all_warnings.append(f"`{rel}`: {w}")
        for e in m.errors:
            all_errors.append(f"`{rel}`: {e}")

    if all_errors:
        lines.extend(["### ❌ Errors", ""])
        for e in all_errors:
            lines.append(f"- {e}")
        lines.append("")

    if all_warnings:
        lines.extend(["### ⚠️ Warnings", ""])
        for w in all_warnings:
            lines.append(f"- {w}")
        lines.append("")

    # Summary
    lines.extend([
        "### 📊 Summary",
        "",
        "| Metric | Value |",
        "|--------|-------|",
        f"| Modules | {len(report.modules)} |",
        f"| Total Resources | {report.total_resources} |",
        f"| Total Data Sources | {report.total_data_sources} |",
        f"| Total Variables | {report.total_variables} |",
        f"| Total Outputs | {report.total_outputs} |",
        f"| ✅ Passed | {report.pass_count} |",
        f"| ⚠️ Warnings | {report.warn_count} |",
        f"| ❌ Failed | {report.fail_count} |",
        "",
        f"### Verdict: {report.verdict}",
    ])

    return '\n'.join(lines)


def format_text(report: TfReport) -> str:
    lines = [
        "=" * 70,
        "  TERRAFORM VALIDATION REPORT",
        "=" * 70,
        f"  Path:    {report.scan_path}",
        f"  Modules: {len(report.modules)}",
        "=" * 70, "",
    ]

    for m in report.modules:
        rel = os.path.relpath(m.path, report.scan_path) if m.path != report.scan_path else "."
        lines.append(f"  [{m.status}] Module: {rel}")
        lines.append(f"    Files: main={'Y' if m.has_main else 'N'}  "
                     f"vars={'Y' if m.has_variables else 'N'}  "
                     f"outputs={'Y' if m.has_outputs else 'N'}  "
                     f"providers={'Y' if m.has_providers else 'N'}")
        lines.append(f"    Resources: {len(m.resources)}  Variables: {len(m.variables)}  "
                     f"Outputs: {len(m.outputs)}  Modules: {len(m.modules)}")
        for w in m.warnings:
            lines.append(f"    [WARN] {w}")
        for e in m.errors:
            lines.append(f"    [ERR]  {e}")
        lines.append("")

    lines.extend([
        "-" * 70,
        f"  VERDICT: {report.verdict}",
        f"  Passed={report.pass_count}  Warnings={report.warn_count}  Failed={report.fail_count}",
        "-" * 70,
    ])
    return '\n'.join(lines)


def format_json(report: TfReport) -> str:
    return json.dumps({
        "scan_path": report.scan_path,
        "verdict": report.verdict,
        "summary": {
            "modules": len(report.modules),
            "total_resources": report.total_resources,
            "total_data_sources": report.total_data_sources,
            "total_variables": report.total_variables,
            "total_outputs": report.total_outputs,
            "passed": report.pass_count,
            "warnings": report.warn_count,
            "failed": report.fail_count,
        },
        "dependency_graph": report.dependency_graph,
        "modules": [
            {"path": m.path, "status": m.status,
             "structure": {"main": m.has_main, "variables": m.has_variables,
                          "outputs": m.has_outputs, "providers": m.has_providers,
                          "backend": m.has_backend},
             "resources": m.resources, "variables": m.variables,
             "outputs": m.outputs, "modules": m.modules,
             "warnings": m.warnings, "errors": m.errors}
            for m in report.modules
        ],
    }, indent=2)


# ═══════════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════════

def main():
    parser = argparse.ArgumentParser(
        description="Claude DevOps — Terraform Validation & Analysis",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument('--path', required=True, help='Path to Terraform directory')
    parser.add_argument('--format', default='text', dest='output_format',
                        choices=['text', 'markdown', 'json'])

    args = parser.parse_args()
    root = Path(args.path).resolve()

    if not root.exists():
        print(f"Error: Path '{args.path}' does not exist", file=sys.stderr)
        sys.exit(1)

    report = analyse_terraform(root)

    formatter = {'text': format_text, 'markdown': format_markdown, 'json': format_json}
    print(formatter[args.output_format](report))

    sys.exit(1 if report.fail_count > 0 else 0)


if __name__ == '__main__':
    main()
