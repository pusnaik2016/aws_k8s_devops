"""
EBS volume tagger.

Applies mandatory tags to EBS volumes:
  1. Propagates matching tags from the attached EC2 instance.
  2. Falls back to default_tags defined in config.yaml.
"""

from __future__ import annotations

import logging
from typing import Any

import boto3
import yaml
from botocore.exceptions import ClientError

log = logging.getLogger(__name__)

VolumeRecord = dict[str, Any]
TagResult = dict[str, str]  # {"volume_id", "action", "tags_applied", "reason"}


class EBSTagger:
    """Tags EBS volumes according to the rules in config.yaml."""

    def __init__(
        self,
        config_path: str = "config.yaml",
        profile: str | None = None,
        dry_run: bool = False,
    ) -> None:
        self._dry_run = dry_run
        self._session = boto3.Session(profile_name=profile)
        self._cfg = self._load_config(config_path)

        self._mandatory: list[str] = self._cfg.get("mandatory_tags", [])
        self._defaults: dict[str, str] = self._cfg.get("default_tags", {})
        self._propagation_enabled: bool = self._cfg.get("tag_propagation", {}).get("enabled", True)
        self._propagation_keys: list[str] = self._cfg.get("tag_propagation", {}).get("keys", [])

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def tag_volumes(self, volumes: list[VolumeRecord]) -> list[TagResult]:
        results: list[TagResult] = []
        for vol in volumes:
            results.append(self._process(vol))
        return results

    def missing_tags(self, volume: VolumeRecord) -> list[str]:
        """Return the list of mandatory tags missing from this volume."""
        existing = set(volume["tags"].keys())
        return [t for t in self._mandatory if t not in existing]

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _load_config(path: str) -> dict:
        with open(path) as fh:
            return yaml.safe_load(fh) or {}

    def _process(self, vol: VolumeRecord) -> TagResult:
        vol_id = vol["volume_id"]
        region = vol["region"]
        current_tags: dict[str, str] = vol["tags"].copy()

        # 1. Propagate tags from the attached EC2 instance
        new_tags: dict[str, str] = {}
        if self._propagation_enabled and vol.get("instance_tags"):
            for tag in vol["instance_tags"]:
                key, value = tag["Key"], tag["Value"]
                if key in self._propagation_keys and key not in current_tags:
                    new_tags[key] = value

        # 2. Apply default_tags for any still-missing mandatory tags
        for key, value in self._defaults.items():
            if key not in current_tags and key not in new_tags:
                new_tags[key] = value

        if not new_tags:
            return {"volume_id": vol_id, "action": "skipped", "tags_applied": "", "reason": "already compliant"}

        tag_list = [{"Key": k, "Value": v} for k, v in new_tags.items()]

        if self._dry_run:
            log.info("[DRY RUN] Would tag %s with %s", vol_id, new_tags)
            return {
                "volume_id": vol_id,
                "action": "tagged",
                "tags_applied": str(new_tags),
                "reason": "dry_run",
            }

        try:
            ec2 = self._session.client("ec2", region_name=region)
            ec2.create_tags(Resources=[vol_id], Tags=tag_list)
            log.info("Tagged %s with %s", vol_id, new_tags)
            return {
                "volume_id": vol_id,
                "action": "tagged",
                "tags_applied": str(new_tags),
                "reason": "ok",
            }
        except ClientError as exc:
            log.error("Failed to tag %s: %s", vol_id, exc)
            return {
                "volume_id": vol_id,
                "action": "error",
                "tags_applied": "",
                "reason": str(exc),
            }
