"""
cost_fetcher.py
---------------
Lambda function that pulls the last N days of AWS cost data from Cost Explorer
and stores it in DynamoDB, using TTL for automatic expiry.

Schedule: 08:00 UTC daily (Cost Explorer has a ~24h lag, so this captures
yesterday's full-day costs reliably).

Environment Variables:
  DYNAMODB_TABLE  – DynamoDB table name
  RETENTION_DAYS  – How many days of history to fetch (default 90)
  LOG_LEVEL       – Python logging level (default INFO)
"""

from __future__ import annotations

import json
import logging
import os
import time
from datetime import date, datetime, timedelta, timezone
from typing import Any

import boto3
from botocore.exceptions import ClientError

###############################################################################
# Configuration
###############################################################################

LOG_LEVEL      = os.environ.get("LOG_LEVEL", "INFO").upper()
TABLE_NAME     = os.environ["DYNAMODB_TABLE"]
RETENTION_DAYS = int(os.environ.get("RETENTION_DAYS", "90"))

logging.basicConfig(
    level=getattr(logging, LOG_LEVEL, logging.INFO),
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
log = logging.getLogger("cost_fetcher")

###############################################################################
# AWS clients (module-level for Lambda container reuse)
###############################################################################

ce_client  = boto3.client("ce")
dynamodb   = boto3.resource("dynamodb")
table      = dynamodb.Table(TABLE_NAME)

###############################################################################
# Core logic
###############################################################################

def fetch_cost_data(start: str, end: str) -> list[dict[str, Any]]:
    """
    Fetch daily cost-by-service from Cost Explorer for [start, end).

    Returns a flat list of dicts:
      { "service": str, "date": str, "amount": float }

    Cost Explorer returns data the day after. 'end' is exclusive.
    """
    log.info("Fetching Cost Explorer data from %s to %s", start, end)

    results: list[dict[str, Any]] = []
    next_page_token: str | None = None

    while True:
        kwargs: dict[str, Any] = {
            "TimePeriod"  : {"Start": start, "End": end},
            "Granularity" : "DAILY",
            "Metrics"     : ["BlendedCost"],
            "GroupBy"     : [{"Type": "DIMENSION", "Key": "SERVICE"}],
        }
        if next_page_token:
            kwargs["NextPageToken"] = next_page_token

        try:
            response = ce_client.get_cost_and_usage(**kwargs)
        except ClientError as exc:
            log.error("Cost Explorer API error: %s", exc)
            raise

        for day_result in response.get("ResultsByTime", []):
            period_start = day_result["TimePeriod"]["Start"]
            for group in day_result.get("Groups", []):
                service = group["Keys"][0]
                amount  = float(group["Metrics"]["BlendedCost"]["Amount"])
                if amount > 0:
                    results.append({
                        "service": service,
                        "date"   : period_start,
                        "amount" : amount,
                    })

        next_page_token = response.get("NextPageToken")
        if not next_page_token:
            break

    log.info("Fetched %d cost records", len(results))
    return results


def compute_expiry_ts(retention_days: int) -> int:
    """Unix timestamp (epoch seconds) after which DynamoDB TTL will delete the item."""
    expiry = datetime.now(tz=timezone.utc) + timedelta(days=retention_days)
    return int(expiry.timestamp())


def upsert_records(records: list[dict[str, Any]]) -> int:
    """
    Batch-write all records to DynamoDB.
    Uses batch_writer for efficiency (25 items per call, auto-batched).
    Returns count of written items.
    """
    expiry_ts = compute_expiry_ts(RETENTION_DAYS)
    written   = 0

    with table.batch_writer() as batch:
        for rec in records:
            item = {
                "service"  : rec["service"],
                "date"     : rec["date"],
                "amount"   : str(rec["amount"]),   # DynamoDB Decimal safety
                "expiry_ts": expiry_ts,
                "updated_at": datetime.now(tz=timezone.utc).isoformat(),
            }
            batch.put_item(Item=item)
            written += 1

    log.info("Wrote %d records to DynamoDB table '%s'", written, TABLE_NAME)
    return written


###############################################################################
# Lambda handler
###############################################################################

def lambda_handler(event: dict, context: Any) -> dict[str, Any]:
    """
    Entry point for the Cost Fetcher Lambda.

    Fetches Cost Explorer data for the last RETENTION_DAYS and upserts
    all records into DynamoDB.
    """
    log.info("Cost Fetcher Lambda started | event=%s", json.dumps(event))

    today = date.today()
    # Cost Explorer end date is exclusive; max reliable date is yesterday.
    end_date   = today.strftime("%Y-%m-%d")
    start_date = (today - timedelta(days=RETENTION_DAYS)).strftime("%Y-%m-%d")

    log.info("Date window: %s → %s (%d days)", start_date, end_date, RETENTION_DAYS)

    try:
        records = fetch_cost_data(start_date, end_date)
        count   = upsert_records(records)
    except Exception as exc:
        log.exception("Fatal error in cost_fetcher: %s", exc)
        raise

    result = {
        "statusCode" : 200,
        "start_date" : start_date,
        "end_date"   : end_date,
        "records"    : count,
    }
    log.info("Cost Fetcher completed: %s", json.dumps(result))
    return result
