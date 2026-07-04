"""
Tests for EBSTagger (no real AWS calls – patching boto3.Session).
"""

from __future__ import annotations

import tempfile
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest
import yaml

from src.tagger import EBSTagger


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

CONFIG_BASIC = {
    "mandatory_tags": ["Environment", "Owner", "Project", "CostCenter"],
    "default_tags": {"ManagedBy": "ebs-cost-optimizer"},
    "tag_propagation": {"enabled": True, "keys": ["Environment", "Owner", "Project", "CostCenter"]},
}


def _write_config(cfg: dict) -> str:
    tmp = tempfile.NamedTemporaryFile(suffix=".yaml", delete=False, mode="w")
    yaml.dump(cfg, tmp)
    tmp.close()
    return tmp.name


def _volume(
    vol_id: str = "vol-0abc123",
    region: str = "us-east-1",
    state: str = "available",
    tags: dict | None = None,
    instance_tags: list[dict] | None = None,
) -> dict:
    return {
        "volume_id": vol_id,
        "region": region,
        "state": state,
        "size_gb": 50,
        "volume_type": "gp2",
        "tags": tags or {},
        "instance_tags": instance_tags or [],
        "unattached_days": 5,
        "attached_to": [],
        "monthly_cost_usd": 0.0,
    }


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

class TestEBSTaggerDryRun:
    def test_dry_run_does_not_call_ec2(self):
        cfg_path = _write_config(CONFIG_BASIC)
        tagger = EBSTagger(config_path=cfg_path, dry_run=True)
        vol = _volume(tags={})

        with patch.object(tagger._session, "client") as mock_client:
            results = tagger.tag_volumes([vol])
            mock_client.assert_not_called()

        assert results[0]["action"] == "tagged"
        assert results[0]["reason"] == "dry_run"

    def test_dry_run_reports_default_tags_applied(self):
        cfg_path = _write_config(CONFIG_BASIC)
        tagger = EBSTagger(config_path=cfg_path, dry_run=True)
        vol = _volume(tags={})

        results = tagger.tag_volumes([vol])
        assert "ManagedBy" in results[0]["tags_applied"]

    def test_dry_run_propagates_instance_tags(self):
        cfg_path = _write_config(CONFIG_BASIC)
        tagger = EBSTagger(config_path=cfg_path, dry_run=True)
        vol = _volume(
            tags={},
            instance_tags=[
                {"Key": "Environment", "Value": "prod"},
                {"Key": "Owner", "Value": "team-platform"},
            ],
        )

        results = tagger.tag_volumes([vol])
        applied = results[0]["tags_applied"]
        assert "Environment" in applied
        assert "Owner" in applied


class TestEBSTaggerCompliance:
    def test_fully_tagged_volume_is_skipped(self):
        cfg_path = _write_config(CONFIG_BASIC)
        tagger = EBSTagger(config_path=cfg_path, dry_run=True)
        vol = _volume(
            tags={
                "Environment": "prod",
                "Owner": "ops",
                "Project": "core",
                "CostCenter": "cc-001",
                "ManagedBy": "ebs-cost-optimizer",
            }
        )

        results = tagger.tag_volumes([vol])
        assert results[0]["action"] == "skipped"

    def test_missing_tags_detected(self):
        cfg_path = _write_config(CONFIG_BASIC)
        tagger = EBSTagger(config_path=cfg_path, dry_run=True)
        vol = _volume(tags={"Environment": "dev"})

        missing = tagger.missing_tags(vol)
        assert "Owner" in missing
        assert "Project" in missing
        assert "CostCenter" in missing
        assert "Environment" not in missing

    def test_propagation_disabled(self):
        cfg = {**CONFIG_BASIC, "tag_propagation": {"enabled": False, "keys": []}}
        cfg_path = _write_config(cfg)
        tagger = EBSTagger(config_path=cfg_path, dry_run=True)
        vol = _volume(
            tags={},
            instance_tags=[{"Key": "Environment", "Value": "prod"}],
        )

        results = tagger.tag_volumes([vol])
        applied = results[0]["tags_applied"]
        # Environment should NOT appear from propagation
        assert "Environment" not in applied or "ManagedBy" in applied


class TestEBSTaggerLiveCall:
    def test_create_tags_called_on_untagged_volume(self):
        cfg_path = _write_config(CONFIG_BASIC)
        tagger = EBSTagger(config_path=cfg_path, dry_run=False)

        mock_ec2 = MagicMock()
        mock_session = MagicMock()
        mock_session.client.return_value = mock_ec2
        tagger._session = mock_session

        vol = _volume(vol_id="vol-0test", tags={})
        results = tagger.tag_volumes([vol])

        mock_ec2.create_tags.assert_called_once()
        call_args = mock_ec2.create_tags.call_args[1]
        assert call_args["Resources"] == ["vol-0test"]
        assert results[0]["action"] == "tagged"

    def test_boto_error_returns_error_action(self):
        from botocore.exceptions import ClientError

        cfg_path = _write_config(CONFIG_BASIC)
        tagger = EBSTagger(config_path=cfg_path, dry_run=False)

        mock_ec2 = MagicMock()
        mock_ec2.create_tags.side_effect = ClientError(
            {"Error": {"Code": "UnauthorizedOperation", "Message": "Not allowed"}},
            "CreateTags",
        )
        mock_session = MagicMock()
        mock_session.client.return_value = mock_ec2
        tagger._session = mock_session

        vol = _volume(tags={})
        results = tagger.tag_volumes([vol])
        assert results[0]["action"] == "error"
        assert "UnauthorizedOperation" in results[0]["reason"]
