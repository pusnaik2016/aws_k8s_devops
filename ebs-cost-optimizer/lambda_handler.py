"""
AWS Lambda handler for the EBS Cost Optimizer.

Triggered nightly by EventBridge.  Reads config from the CONFIG_YAML_B64
environment variable (base64-encoded YAML), runs the scanner + tagger,
and publishes a savings summary to SNS.
"""

from __future__ import annotations

import base64
import json
import logging
import os
import tempfile

import boto3

log = logging.getLogger()
log.setLevel(logging.INFO)


def handler(event: dict, context) -> dict:  # noqa: ANN001
    """Lambda entry point."""

    # ------------------------------------------------------------------ config
    config_b64: str = os.environ.get("CONFIG_YAML_B64", "")
    dry_run: bool = os.environ.get("DRY_RUN", "false").lower() == "true"
    sns_topic_arn: str = os.environ.get("SNS_TOPIC_ARN", "")
    region: str | None = os.environ.get("AWS_DEFAULT_REGION") or None

    # Write config to a temp file so the existing modules can read it
    cfg_path = ""
    if config_b64:
        cfg_bytes = base64.b64decode(config_b64)
        tmp = tempfile.NamedTemporaryFile(suffix=".yaml", delete=False)
        tmp.write(cfg_bytes)
        tmp.close()
        cfg_path = tmp.name
    else:
        # Use defaults baked into the package
        cfg_path = "/var/task/config.yaml.example"

    # --------------------------------------------------------------- scan + tag
    from src.scanner import EBSScanner  # noqa: PLC0415
    from src.tagger import EBSTagger  # noqa: PLC0415
    from src.cost_estimator import CostEstimator  # noqa: PLC0415
    from src.reporter import EBSReporter  # noqa: PLC0415

    scanner = EBSScanner(region=region)
    volumes = scanner.scan()
    log.info("Scanned %d volumes", len(volumes))

    tagger = EBSTagger(config_path=cfg_path, dry_run=dry_run)
    tag_results = tagger.tag_volumes(volumes)
    tagged = sum(1 for r in tag_results if r["action"] == "tagged")
    errors = sum(1 for r in tag_results if r["action"] == "error")
    log.info("Tagged %d volumes, %d errors", tagged, errors)

    import yaml  # noqa: PLC0415

    with open(cfg_path) as fh:
        cfg = yaml.safe_load(fh) or {}
    mandatory_tags = cfg.get("mandatory_tags", [])

    estimator = CostEstimator()
    reporter = EBSReporter(volumes=volumes, estimator=estimator, mandatory_tags=mandatory_tags)
    total_savings = reporter.total_monthly_savings_usd()

    unattached = [v for v in volumes if v["state"] == "available"]
    untagged = [v for v in volumes if v.get("missing_tags")]

    summary = {
        "total_volumes": len(volumes),
        "tagged_this_run": tagged,
        "tag_errors": errors,
        "unattached_volumes": len(unattached),
        "untagged_volumes": len(untagged),
        "estimated_monthly_savings_usd": total_savings,
        "dry_run": dry_run,
    }

    log.info("Summary: %s", json.dumps(summary))

    # --------------------------------------------------------------- SNS digest
    if sns_topic_arn:
        message = (
            f"EBS Cost Optimizer – Nightly Report\n"
            f"{'=' * 45}\n"
            f"  Total volumes scanned  : {summary['total_volumes']}\n"
            f"  Volumes tagged         : {summary['tagged_this_run']}\n"
            f"  Unattached volumes     : {summary['unattached_volumes']}\n"
            f"  Untagged volumes       : {summary['untagged_volumes']}\n"
            f"  Est. monthly savings   : ${total_savings:,.2f}\n"
            f"  Dry run mode           : {dry_run}\n"
        )
        boto3.client("sns", region_name=region).publish(
            TopicArn=sns_topic_arn,
            Subject="EBS Cost Optimizer – Nightly Savings Digest",
            Message=message,
        )
        log.info("SNS digest published to %s", sns_topic_arn)

    return {"statusCode": 200, "body": json.dumps(summary)}
