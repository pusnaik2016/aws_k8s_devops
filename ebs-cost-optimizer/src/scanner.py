"""
EBS volume scanner.

Queries EC2 for every EBS volume (one region or all) and enriches each
record with the age it has been unattached.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any

import boto3
from botocore.exceptions import ClientError

log = logging.getLogger(__name__)

# Type alias for a volume record dict
VolumeRecord = dict[str, Any]


class EBSScanner:
    """Scans EBS volumes across one region or every enabled region."""

    def __init__(self, region: str | None = None, profile: str | None = None) -> None:
        self._region = region
        self._session = boto3.Session(profile_name=profile)

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def scan(self) -> list[VolumeRecord]:
        """Return enriched volume records for all target regions."""
        regions = [self._region] if self._region else self._all_regions()
        volumes: list[VolumeRecord] = []
        for region in regions:
            try:
                volumes.extend(self._scan_region(region))
            except ClientError as exc:
                log.warning("Skipping region %s: %s", region, exc)
        return volumes

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    def _all_regions(self) -> list[str]:
        ec2 = self._session.client("ec2", region_name="us-east-1")
        resp = ec2.describe_regions(Filters=[{"Name": "opt-in-status", "Values": ["opt-in-not-required", "opted-in"]}])
        return [r["RegionName"] for r in resp["Regions"]]

    def _scan_region(self, region: str) -> list[VolumeRecord]:
        ec2 = self._session.client("ec2", region_name=region)
        instances = self._instance_tag_map(ec2)

        paginator = ec2.get_paginator("describe_volumes")
        records: list[VolumeRecord] = []

        for page in paginator.paginate():
            for vol in page["Volumes"]:
                records.append(self._enrich(vol, region, instances))

        log.info("Region %s: found %d volumes", region, len(records))
        return records

    def _instance_tag_map(self, ec2_client) -> dict[str, list[dict]]:
        """Return {instance_id: [tags]} so we can propagate tags later."""
        mapping: dict[str, list[dict]] = {}
        try:
            paginator = ec2_client.get_paginator("describe_instances")
            for page in paginator.paginate():
                for reservation in page["Reservations"]:
                    for inst in reservation["Instances"]:
                        mapping[inst["InstanceId"]] = inst.get("Tags", [])
        except ClientError as exc:
            log.warning("Could not describe instances: %s", exc)
        return mapping

    @staticmethod
    def _enrich(
        vol: dict,
        region: str,
        instances: dict[str, list[dict]],
    ) -> VolumeRecord:
        attachments = vol.get("Attachments", [])
        attached_to: list[str] = [a["InstanceId"] for a in attachments if a.get("State") == "attached"]
        state: str = vol["State"]

        # Compute how long the volume has been unattached.
        # AWS doesn't record detach time directly; use CreateTime as a proxy for
        # volumes that were never attached, and 0 for currently attached ones.
        now = datetime.now(timezone.utc)
        create_time: datetime = vol["CreateTime"]
        if attached_to:
            unattached_days = 0
        else:
            unattached_days = (now - create_time).days

        # Gather instance tags for propagation decisions (reference only here)
        instance_tags: list[dict] = []
        for iid in attached_to:
            instance_tags.extend(instances.get(iid, []))

        tags: dict[str, str] = {t["Key"]: t["Value"] for t in vol.get("Tags", [])}

        return {
            "volume_id": vol["VolumeId"],
            "region": region,
            "state": state,
            "size_gb": vol["Size"],
            "volume_type": vol["VolumeType"],
            "iops": vol.get("Iops"),
            "throughput": vol.get("Throughput"),
            "encrypted": vol.get("Encrypted", False),
            "availability_zone": vol.get("AvailabilityZone", ""),
            "create_time": create_time.isoformat(),
            "attached_to": attached_to,
            "unattached_days": unattached_days,
            "tags": tags,
            "instance_tags": instance_tags,
            # monthly_cost_usd is filled later by CostEstimator
            "monthly_cost_usd": 0.0,
        }
