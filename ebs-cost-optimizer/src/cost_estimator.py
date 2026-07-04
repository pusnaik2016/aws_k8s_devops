"""
EBS cost estimator.

Uses static regional pricing (per-GB/month) rather than live Pricing API
calls so that the tool works without pricing:GetProducts permission and
returns results instantly.  Prices are approximate us-east-1 list prices
(July 2025).  Override via subclass or update the PRICE_TABLE below.
"""

from __future__ import annotations

from typing import Any

# ---------------------------------------------------------------------------
# Static price table  ($/GB/month)
# ---------------------------------------------------------------------------
# Per AWS public pricing: https://aws.amazon.com/ebs/pricing/
# gp3 baseline; io1/io2 storage portion only (IOPS billed separately).
PRICE_PER_GB: dict[str, float] = {
    "gp2": 0.10,
    "gp3": 0.08,
    "io1": 0.125,
    "io2": 0.125,
    "st1": 0.045,
    "sc1": 0.025,
    "standard": 0.05,   # magnetic
}

# Extra IOPS cost ($/provisioned IOPS/month) for io1/io2
PRICE_PER_IOPS: dict[str, float] = {
    "io1": 0.065,
    "io2": 0.065,
}

VolumeRecord = dict[str, Any]


class CostEstimator:
    """Estimate EBS monthly cost and potential savings."""

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def monthly_cost_usd(self, volume: VolumeRecord) -> float:
        """Return the estimated monthly cost for a single volume (USD)."""
        vol_type = volume.get("volume_type", "gp2")
        size_gb: int = volume.get("size_gb", 0)

        storage_cost = PRICE_PER_GB.get(vol_type, 0.10) * size_gb

        iops_cost = 0.0
        if vol_type in PRICE_PER_IOPS and volume.get("iops"):
            iops_cost = PRICE_PER_IOPS[vol_type] * int(volume["iops"])

        return round(storage_cost + iops_cost, 4)

    def gp3_savings_usd(self, volume: VolumeRecord) -> float:
        """
        Return monthly savings if a gp2 volume were migrated to gp3.
        Returns 0.0 for any other volume type.
        """
        if volume.get("volume_type") != "gp2":
            return 0.0
        size_gb: int = volume.get("size_gb", 0)
        gp2_cost = PRICE_PER_GB["gp2"] * size_gb
        gp3_cost = PRICE_PER_GB["gp3"] * size_gb
        return round(gp2_cost - gp3_cost, 4)

    def recommendation(self, volume: VolumeRecord, missing_tags: list[str]) -> str:
        """Return a short recommendation string for the report."""
        if volume.get("state") == "available":
            return "DELETE"                          # unattached → delete
        if volume.get("volume_type") == "gp2":
            return "MIGRATE_TO_GP3"                  # migrate for savings
        if missing_tags:
            return "ADD_TAGS"
        return "COMPLIANT"

    def enrich(self, volumes: list[VolumeRecord]) -> None:
        """Mutate each record in-place: add monthly_cost_usd."""
        for vol in volumes:
            vol["monthly_cost_usd"] = self.monthly_cost_usd(vol)
