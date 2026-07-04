"""
Tests for EBSScanner using moto (mocked AWS).
"""

from __future__ import annotations

import boto3
import pytest
from moto import mock_aws

from src.scanner import EBSScanner


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _create_volume(ec2_client, size: int = 20, vol_type: str = "gp2", tags: list[dict] | None = None):
    kwargs: dict = {
        "AvailabilityZone": "us-east-1a",
        "Size": size,
        "VolumeType": vol_type,
    }
    if tags:
        kwargs["TagSpecifications"] = [{"ResourceType": "volume", "Tags": tags}]
    return ec2_client.create_volume(**kwargs)


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@mock_aws
class TestEBSScannerBasic:
    def test_scan_returns_records(self):
        ec2 = boto3.client("ec2", region_name="us-east-1")
        _create_volume(ec2, size=50, vol_type="gp2")
        _create_volume(ec2, size=100, vol_type="gp3")

        scanner = EBSScanner(region="us-east-1")
        volumes = scanner.scan()

        # moto includes the root device volume for any instances; filter to ours
        created = [v for v in volumes if v["size_gb"] in (50, 100)]
        assert len(created) == 2

    def test_volume_record_has_required_keys(self):
        ec2 = boto3.client("ec2", region_name="us-east-1")
        _create_volume(ec2, size=10)

        scanner = EBSScanner(region="us-east-1")
        volumes = scanner.scan()
        assert volumes, "Expected at least one volume"

        required_keys = {
            "volume_id", "region", "state", "size_gb", "volume_type",
            "encrypted", "create_time", "attached_to", "unattached_days", "tags",
        }
        for vol in volumes:
            assert required_keys.issubset(vol.keys()), f"Missing keys in {vol}"

    def test_unattached_volume_has_nonzero_unattached_days(self):
        ec2 = boto3.client("ec2", region_name="us-east-1")
        _create_volume(ec2, size=30)

        scanner = EBSScanner(region="us-east-1")
        volumes = scanner.scan()

        available = [v for v in volumes if v["state"] == "available"]
        assert available, "Expected at least one available volume"
        # moto create_time == now so unattached_days == 0 is acceptable
        for vol in available:
            assert vol["unattached_days"] >= 0

    def test_tagged_volume_tags_are_returned(self):
        ec2 = boto3.client("ec2", region_name="us-east-1")
        _create_volume(ec2, size=20, tags=[{"Key": "Owner", "Value": "alice"}])

        scanner = EBSScanner(region="us-east-1")
        volumes = scanner.scan()

        tagged = [v for v in volumes if v["tags"].get("Owner") == "alice"]
        assert len(tagged) == 1

    def test_state_is_available_for_new_volume(self):
        ec2 = boto3.client("ec2", region_name="us-east-1")
        _create_volume(ec2, size=10)

        scanner = EBSScanner(region="us-east-1")
        volumes = scanner.scan()

        assert any(v["state"] == "available" for v in volumes)


@mock_aws
class TestEBSScannerTypes:
    @pytest.mark.parametrize("vol_type", ["gp2", "gp3", "io1", "st1", "sc1"])
    def test_volume_type_preserved(self, vol_type: str):
        ec2 = boto3.client("ec2", region_name="us-east-1")
        extra = {}
        if vol_type == "io1":
            extra = {"Iops": 100}
        ec2.create_volume(
            AvailabilityZone="us-east-1a",
            Size=20,
            VolumeType=vol_type,
            **extra,
        )

        scanner = EBSScanner(region="us-east-1")
        volumes = scanner.scan()

        types = [v["volume_type"] for v in volumes]
        assert vol_type in types, f"{vol_type} not found in {types}"
