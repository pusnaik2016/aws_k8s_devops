"""
EBS Cost Optimizer – main CLI entry point.

Usage
-----
python ebs_optimizer.py scan    [OPTIONS]
python ebs_optimizer.py tag     [OPTIONS]
python ebs_optimizer.py report  [OPTIONS]
python ebs_optimizer.py cleanup [OPTIONS]
"""

from __future__ import annotations

import sys
from pathlib import Path

import click
from rich.console import Console

from src.scanner import EBSScanner
from src.tagger import EBSTagger
from src.reporter import EBSReporter
from src.cost_estimator import CostEstimator

console = Console()

# ---------------------------------------------------------------------------
# Shared CLI options
# ---------------------------------------------------------------------------

_region_option = click.option(
    "--region",
    default=None,
    show_default=True,
    help="AWS region (omit to scan ALL regions).",
)
_profile_option = click.option(
    "--profile",
    default=None,
    envvar="AWS_PROFILE",
    help="AWS CLI named profile.",
)
_config_option = click.option(
    "--config",
    "config_path",
    default="config.yaml",
    type=click.Path(exists=False),
    show_default=True,
    help="Path to config.yaml.",
)
_dry_run_option = click.option(
    "--dry-run",
    is_flag=True,
    default=False,
    help="Print what would happen without making any AWS API changes.",
)


# ---------------------------------------------------------------------------
# CLI group
# ---------------------------------------------------------------------------

@click.group()
@click.version_option("1.0.0", prog_name="ebs-optimizer")
def cli() -> None:
    """EBS Cost Optimizer – tag volumes and eliminate wasted EBS spend."""


# ---------------------------------------------------------------------------
# scan
# ---------------------------------------------------------------------------

@cli.command()
@_region_option
@_profile_option
def scan(region: str | None, profile: str | None) -> None:
    """Discover all EBS volumes and print a summary table."""

    scanner = EBSScanner(region=region, profile=profile)

    with console.status("[bold green]Scanning EBS volumes…"):
        volumes = scanner.scan()

    if not volumes:
        console.print("[yellow]No EBS volumes found.[/yellow]")
        return

    estimator = CostEstimator()
    reporter = EBSReporter(volumes=volumes, estimator=estimator)
    reporter.print_summary(console)


# ---------------------------------------------------------------------------
# tag
# ---------------------------------------------------------------------------

@cli.command()
@_region_option
@_profile_option
@_config_option
@_dry_run_option
def tag(
    region: str | None,
    profile: str | None,
    config_path: str,
    dry_run: bool,
) -> None:
    """Apply/enforce cost-allocation tags on EBS volumes."""

    if not Path(config_path).exists():
        console.print(
            f"[red]Config file not found: {config_path}[/red]\n"
            "Copy config.yaml.example → config.yaml and adjust it."
        )
        sys.exit(1)

    scanner = EBSScanner(region=region, profile=profile)
    tagger = EBSTagger(config_path=config_path, profile=profile, dry_run=dry_run)

    with console.status("[bold green]Scanning EBS volumes…"):
        volumes = scanner.scan()

    if not volumes:
        console.print("[yellow]No EBS volumes found.[/yellow]")
        return

    results = tagger.tag_volumes(volumes)

    tagged = sum(1 for r in results if r["action"] == "tagged")
    skipped = sum(1 for r in results if r["action"] == "skipped")
    errors = sum(1 for r in results if r["action"] == "error")

    mode = "[yellow](DRY RUN)[/yellow] " if dry_run else ""
    console.print(
        f"\n{mode}Tagging complete — "
        f"[green]{tagged} tagged[/green]  "
        f"[dim]{skipped} already compliant[/dim]  "
        f"[red]{errors} errors[/red]"
    )


# ---------------------------------------------------------------------------
# report
# ---------------------------------------------------------------------------

@cli.command()
@_region_option
@_profile_option
@_config_option
@click.option(
    "--output",
    default="reports/ebs_report.csv",
    show_default=True,
    help="Output file path (.csv or .json).",
)
def report(
    region: str | None,
    profile: str | None,
    config_path: str,
    output: str,
) -> None:
    """Generate a cost-savings report for all EBS volumes."""

    scanner = EBSScanner(region=region, profile=profile)

    with console.status("[bold green]Scanning EBS volumes…"):
        volumes = scanner.scan()

    estimator = CostEstimator()
    mandatory_tags: list[str] = []

    if Path(config_path).exists():
        import yaml  # noqa: PLC0415

        with open(config_path) as fh:
            cfg = yaml.safe_load(fh) or {}
        mandatory_tags = cfg.get("mandatory_tags", [])

    reporter = EBSReporter(
        volumes=volumes,
        estimator=estimator,
        mandatory_tags=mandatory_tags,
    )
    reporter.print_summary(console)

    out_path = Path(output)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    if output.endswith(".json"):
        reporter.write_json(out_path)
    else:
        reporter.write_csv(out_path)

    total_savings = reporter.total_monthly_savings_usd()
    console.print(
        f"\n[bold]Report saved → {out_path}[/bold]\n"
        f"[green]Estimated monthly savings if all recommendations applied: "
        f"${total_savings:,.2f}[/green]"
    )


# ---------------------------------------------------------------------------
# cleanup
# ---------------------------------------------------------------------------

@cli.command()
@_region_option
@_profile_option
@_config_option
@_dry_run_option
def cleanup(
    region: str | None,
    profile: str | None,
    config_path: str,
    dry_run: bool,
) -> None:
    """Snapshot and delete unattached EBS volumes older than min_unattached_days."""

    if not Path(config_path).exists():
        console.print(
            f"[red]Config file not found: {config_path}[/red]\n"
            "Copy config.yaml.example → config.yaml and adjust it."
        )
        sys.exit(1)

    import yaml  # noqa: PLC0415

    with open(config_path) as fh:
        cfg = yaml.safe_load(fh) or {}

    cleanup_cfg = cfg.get("cleanup", {})
    min_days: int = int(cleanup_cfg.get("min_unattached_days", 14))
    snapshot_first: bool = bool(cleanup_cfg.get("snapshot_before_delete", True))
    snap_tag: dict = cleanup_cfg.get("snapshot_tag", {"CreatedBy": "ebs-cost-optimizer-cleanup"})

    scanner = EBSScanner(region=region, profile=profile)

    with console.status("[bold green]Scanning EBS volumes…"):
        volumes = scanner.scan()

    candidates = [v for v in volumes if v["state"] == "available" and v["unattached_days"] >= min_days]

    if not candidates:
        console.print("[green]No volumes qualify for cleanup.[/green]")
        return

    console.print(f"\n[bold]{len(candidates)} volume(s) qualify for cleanup (unattached ≥ {min_days} days):[/bold]")
    for vol in candidates:
        console.print(
            f"  [cyan]{vol['volume_id']}[/cyan]  "
            f"{vol['size_gb']} GB  {vol['volume_type']}  "
            f"unattached {vol['unattached_days']} days  "
            f"~${vol.get('monthly_cost_usd', 0):.2f}/mo"
        )

    if dry_run:
        console.print("\n[yellow](DRY RUN) – no changes made.[/yellow]")
        return

    if not click.confirm(f"\nDelete {len(candidates)} volume(s)?", default=False):
        console.print("Aborted.")
        return

    import boto3  # noqa: PLC0415

    session = boto3.Session(profile_name=profile)
    deleted = 0
    snapped = 0

    for vol in candidates:
        ec2 = session.client("ec2", region_name=vol["region"])
        vol_id = vol["volume_id"]
        try:
            if snapshot_first:
                snap = ec2.create_snapshot(
                    VolumeId=vol_id,
                    Description=f"ebs-cost-optimizer pre-delete backup of {vol_id}",
                    TagSpecifications=[
                        {
                            "ResourceType": "snapshot",
                            "Tags": [{"Key": k, "Value": v} for k, v in snap_tag.items()]
                            + [{"Key": "SourceVolumeId", "Value": vol_id}],
                        }
                    ],
                )
                console.print(f"  [dim]Snapshot {snap['SnapshotId']} created for {vol_id}[/dim]")
                snapped += 1

            ec2.delete_volume(VolumeId=vol_id)
            console.print(f"  [red]Deleted {vol_id}[/red]")
            deleted += 1

        except Exception as exc:  # noqa: BLE001
            console.print(f"  [red]ERROR {vol_id}: {exc}[/red]")

    console.print(
        f"\n[bold]Cleanup complete — {deleted} deleted, {snapped} snapshots created.[/bold]"
    )


# ---------------------------------------------------------------------------

if __name__ == "__main__":
    cli()
