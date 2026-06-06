#!/usr/bin/env python3
"""Claude DevOps Debug Toolkit — Unified CLI entry point for all 10 tools."""

import sys
import argparse
from pathlib import Path

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent))

from core.reporter import print_terminal, to_json, to_markdown, to_html
from tools.iac_generator import IaCGenerator
from tools.pipeline_debugger import PipelineDebugger
from tools.security_scanner import SecurityScanner
from tools.incident_triage import IncidentTriage
from tools.server_config_analyzer import ServerConfigAnalyzer
from tools.legacy_modernizer import LegacyModernizer
from tools.runbook_generator import RunbookGenerator
from tools.k8s_troubleshooter import K8sTroubleshooter
from tools.release_notes_generator import ReleaseNotesGenerator
from tools.cost_optimizer import CostOptimizer


TOOLS = {
    "iac-gen":       ("IaC Generator",           IaCGenerator),
    "pipeline":      ("CI/CD Pipeline Debugger",  PipelineDebugger),
    "security":      ("Security Scanner",         SecurityScanner),
    "incident":      ("Incident Triage",          IncidentTriage),
    "server-config": ("Server Config Analyzer",   ServerConfigAnalyzer),
    "modernize":     ("Legacy Code Modernizer",   LegacyModernizer),
    "runbook":       ("Runbook Generator",        RunbookGenerator),
    "k8s":           ("K8s Troubleshooter",       K8sTroubleshooter),
    "release":       ("Release Notes Generator",  ReleaseNotesGenerator),
    "cost":          ("Cost Optimizer",            CostOptimizer),
}


def main():
    parser = argparse.ArgumentParser(
        prog="devops-debug",
        description="🔧 Claude DevOps Debug Toolkit — 10-in-1 DevOps Automation",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Available tools:
  iac-gen        Generate Terraform from YAML service descriptions
  pipeline       Debug CI/CD pipeline failures from build logs
  security       Scan IaC files for security violations
  incident       Triage incidents from application logs
  server-config  Validate Nginx/Apache/systemd configurations
  modernize      Detect legacy code patterns and suggest fixes
  runbook        Generate operational runbooks from IaC manifests
  k8s            Troubleshoot Kubernetes manifest issues
  release        Generate release notes from git history
  cost           Identify AWS cost optimization opportunities

Examples:
  python cli.py security samples/terraform/
  python cli.py k8s samples/kubernetes/bad_deployment.yaml
  python cli.py pipeline samples/pipelines/github_actions_fail.log
  python cli.py cost samples/terraform/ --format html --output reports/cost.html
  python cli.py modernize samples/legacy_code/
  python cli.py server-config samples/server_configs/nginx_bad.conf
        """,
    )

    parser.add_argument("tool", choices=TOOLS.keys(), help="Tool to run")
    parser.add_argument("target", help="Target file or directory to analyze")
    parser.add_argument(
        "--format", "-f",
        choices=["terminal", "json", "markdown", "html"],
        default="terminal",
        help="Output format (default: terminal)"
    )
    parser.add_argument("--output", "-o", help="Output file path")
    parser.add_argument("--version", "-v", help="Version tag (for release notes)", default="Unreleased")

    args = parser.parse_args()

    # Instantiate and run the selected tool
    tool_name, tool_class = TOOLS[args.tool]
    analyzer = tool_class()

    print(f"\n🔧 Running: {tool_name}")
    print(f"   Target:  {args.target}\n")

    # Build kwargs based on tool
    kwargs = {}
    if args.tool == "iac-gen":
        kwargs["output_dir"] = args.output or "output"
    elif args.tool == "runbook":
        kwargs["output"] = args.output or "reports/runbook.md"
    elif args.tool == "release":
        kwargs["version"] = args.version
        kwargs["output"] = args.output or "reports/CHANGELOG.md"

    result = analyzer.analyze(args.target, **kwargs)

    # Output
    if args.format == "terminal":
        print_terminal(result)
    elif args.format == "json":
        output = to_json(result, args.output)
        if not args.output:
            print(output)
    elif args.format == "markdown":
        output = to_markdown(result, args.output)
        if not args.output:
            print(output)
    elif args.format == "html":
        output_path = args.output or f"reports/{args.tool}_report.html"
        to_html(result, output_path)
        print(f"📊 HTML report saved to: {output_path}")

    # Exit code based on result
    sys.exit(0 if result.passed else 1)


if __name__ == "__main__":
    main()
