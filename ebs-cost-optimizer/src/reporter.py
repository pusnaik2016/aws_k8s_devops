"""
EBS reporter.

Renders a Rich summary table to stdout and writes CSV / JSON artefacts.
"""

from __future__ import annotations

import csv
import json
import logging
from pathlib import Path
from typing import Any

from rich.console import Console
from rich.table import Table

from src.cost_estimator import CostEstimator

log = logging.getLogger(__name__)

VolumeRecord = dict[str, Any]


class EBSReporter:
    """Formats and persists EBS scan results."""

    def __init__(
        self,
        volumes: list[VolumeRecord],
        estimator: CostEstimator,
        mandatory_tags: list[str] | None = None,
    ) -> None:
        self._estimator = estimator
        self._mandatory = mandatory_tags or []

        # Enrich every volume with cost and recommendation
        estimator.enrich(volumes)
        for vol in volumes:
            missing = self._missing_tags(vol)
            vol["missing_tags"] = missing
            vol["recommendation"] = estimator.recommendation(vol, missing)
            vol["gp3_savings_usd"] = estimator.gp3_savings_usd(vol)

        self._volumes = volumes

    # ------------------------------------------------------------------
    # Console output
    # ------------------------------------------------------------------

    def print_summary(self, console: Console) -> None:
        table = Table(
            title="EBS Volumes",
            show_lines=False,
            highlight=True,
        )
        table.add_column("Volume ID", style="cyan", no_wrap=True)
        table.add_column("Region", style="dim")
        table.add_column("State")
        table.add_column("GB", justify="right")
        table.add_column("Type")
        table.add_column("Unattached\nDays", justify="right")
        table.add_column("$/mo", justify="right", style="yellow")
        table.add_column("Missing Tags", style="red")
        table.add_column("Recommendation", style="bold")

        for vol in self._volumes:
            state_color = "green" if vol["state"] == "in-use" else "red"
            table.add_row(
                vol["volume_id"],
                vol["region"],
                f"[{state_color}]{vol['state']}[/{state_color}]",
                str(vol["size_gb"]),
                vol["volume_type"],
                str(vol["unattached_days"]),
                f"${vol['monthly_cost_usd']:.2f}",
                ", ".join(vol["missing_tags"]) if vol["missing_tags"] else "[green]✓[/green]",
                self._rec_styled(vol["recommendation"]),
            )

        console.print(table)
        self._print_totals(console)

    def _print_totals(self, console: Console) -> None:
        total_cost = sum(v["monthly_cost_usd"] for v in self._volumes)
        unattached_cost = sum(
            v["monthly_cost_usd"] for v in self._volumes if v["state"] == "available"
        )
        gp3_savings = sum(v["gp3_savings_usd"] for v in self._volumes)
        untagged = sum(1 for v in self._volumes if v["missing_tags"])

        console.print(
            f"\n[bold]Totals:[/bold]  "
            f"Volumes: {len(self._volumes)}  │  "
            f"Total monthly cost: [yellow]${total_cost:,.2f}[/yellow]  │  "
            f"Unattached waste: [red]${unattached_cost:,.2f}/mo[/red]  │  "
            f"gp2→gp3 savings: [green]${gp3_savings:,.2f}/mo[/green]  │  "
            f"Untagged: [red]{untagged}[/red]"
        )

    @staticmethod
    def _rec_styled(rec: str) -> str:
        mapping = {
            "DELETE": "[red]DELETE[/red]",
            "MIGRATE_TO_GP3": "[yellow]MIGRATE_TO_GP3[/yellow]",
            "ADD_TAGS": "[magenta]ADD_TAGS[/magenta]",
            "COMPLIANT": "[green]COMPLIANT[/green]",
        }
        return mapping.get(rec, rec)

    # ------------------------------------------------------------------
    # File output
    # ------------------------------------------------------------------

    _CSV_FIELDS = [
        "volume_id",
        "region",
        "state",
        "size_gb",
        "volume_type",
        "availability_zone",
        "encrypted",
        "attached_to",
        "unattached_days",
        "monthly_cost_usd",
        "gp3_savings_usd",
        "missing_tags",
        "recommendation",
        "create_time",
    ]

    def write_csv(self, path: Path) -> None:
        with path.open("w", newline="") as fh:
            writer = csv.DictWriter(fh, fieldnames=self._CSV_FIELDS, extrasaction="ignore")
            writer.writeheader()
            for vol in self._volumes:
                row = vol.copy()
                row["attached_to"] = "|".join(row.get("attached_to") or [])
                row["missing_tags"] = "|".join(row.get("missing_tags") or [])
                writer.writerow(row)
        log.info("CSV written to %s", path)

    def write_json(self, path: Path) -> None:
        output = []
        for vol in self._volumes:
            record = {k: vol[k] for k in self._CSV_FIELDS if k in vol}
            output.append(record)
        with path.open("w") as fh:
            json.dump(output, fh, indent=2, default=str)
        log.info("JSON written to %s", path)

    # ------------------------------------------------------------------
    # Aggregates
    # ------------------------------------------------------------------

    def total_monthly_savings_usd(self) -> float:
        """Sum of unattached volume costs + gp2→gp3 savings."""
        unattached = sum(
            v["monthly_cost_usd"] for v in self._volumes if v["state"] == "available"
        )
        gp3 = sum(v["gp3_savings_usd"] for v in self._volumes)
        return round(unattached + gp3, 2)

    # ------------------------------------------------------------------
    # Internal
    # ------------------------------------------------------------------

    def _missing_tags(self, vol: VolumeRecord) -> list[str]:
        if not self._mandatory:
            return []
        existing = set(vol.get("tags", {}).keys())
        return [t for t in self._mandatory if t not in existing]
