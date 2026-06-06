"""
anomaly_detector.py
-------------------
Lambda function that reads 90-day cost history from DynamoDB, calculates
Z-scores per service, identifies statistical anomalies, submits them to
Amazon Bedrock (Claude 3.5 Sonnet) for intelligent analysis, and publishes
a structured alert email via SNS.

Schedule: 08:10 UTC daily (10 min after Cost Fetcher completes).

Environment Variables:
  DYNAMODB_TABLE    – DynamoDB table name
  SNS_TOPIC_ARN     – SNS topic ARN for publishing alerts
  BEDROCK_MODEL_ID  – Bedrock model ID (e.g. anthropic.claude-3-5-sonnet-...)
  ZSCORE_THRESHOLD  – Anomaly detection threshold (default 2.5)
  MIN_HISTORY_DAYS  – Minimum days of history required per service (default 14)
  AWS_REGION_NAME   – AWS region for Bedrock client
  LOG_LEVEL         – Python logging level (default INFO)
"""

from __future__ import annotations

import json
import logging
import math
import os
from datetime import date, datetime, timezone
from decimal import Decimal
from typing import Any

import boto3
from botocore.exceptions import ClientError

###############################################################################
# Configuration
###############################################################################

LOG_LEVEL         = os.environ.get("LOG_LEVEL", "INFO").upper()
TABLE_NAME        = os.environ["DYNAMODB_TABLE"]
SNS_TOPIC_ARN     = os.environ["SNS_TOPIC_ARN"]
BEDROCK_MODEL_ID  = os.environ["BEDROCK_MODEL_ID"]
ZSCORE_THRESHOLD  = float(os.environ.get("ZSCORE_THRESHOLD", "2.5"))
MIN_HISTORY_DAYS  = int(os.environ.get("MIN_HISTORY_DAYS", "14"))
AWS_REGION_NAME   = os.environ.get("AWS_REGION_NAME", "us-east-1")

logging.basicConfig(
    level=getattr(logging, LOG_LEVEL, logging.INFO),
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
log = logging.getLogger("anomaly_detector")

###############################################################################
# AWS clients
###############################################################################

dynamodb = boto3.resource("dynamodb")
table    = dynamodb.Table(TABLE_NAME)

sns_client = boto3.client("sns")

bedrock_client = boto3.client(
    "bedrock-runtime",
    region_name=AWS_REGION_NAME,
)

###############################################################################
# Statistical helpers
###############################################################################

def zscore(value: float, history: list[float]) -> float:
    """
    Calculate the Z-score of `value` relative to `history`.

    Z = (value - mean) / std_dev

    Returns 0.0 if history is empty or std_dev is zero (constant costs).
    """
    n = len(history)
    if n == 0:
        return 0.0

    mean = sum(history) / n
    variance = sum((x - mean) ** 2 for x in history) / n
    std = math.sqrt(variance)

    return (value - mean) / std if std > 0 else 0.0


###############################################################################
# DynamoDB helpers
###############################################################################

def load_history() -> dict[str, list[tuple[str, float]]]:
    """
    Scan DynamoDB for all cost records.

    Returns a dict:
      { service_name: [(date_str, amount_float), ...] }

    Sorted ascending by date so the last element is always the most recent.
    """
    log.info("Loading cost history from DynamoDB table '%s'", TABLE_NAME)

    history: dict[str, list[tuple[str, float]]] = {}
    scan_kwargs: dict[str, Any] = {}

    while True:
        response = table.scan(**scan_kwargs)

        for item in response.get("Items", []):
            service = item["service"]
            date_   = item["date"]
            amount  = float(item["amount"])  # stored as string for Decimal safety

            if service not in history:
                history[service] = []
            history[service].append((date_, amount))

        last_key = response.get("LastEvaluatedKey")
        if not last_key:
            break
        scan_kwargs["ExclusiveStartKey"] = last_key

    # Sort each service's history by date (ascending)
    for service in history:
        history[service].sort(key=lambda t: t[0])

    log.info("Loaded history for %d services", len(history))
    return history


###############################################################################
# Anomaly detection
###############################################################################

def detect_anomalies(history: dict[str, list[tuple[str, float]]]) -> list[dict]:
    """
    Detect cost anomalies using Z-score analysis.

    Rules:
    - Baseline excludes today (last entry) to prevent the anomaly from
      contaminating its own detection threshold.
    - Requires MIN_HISTORY_DAYS entries before evaluating a service.
    - Returns results sorted by |Z-score| descending (worst first).
    """
    anomalies: list[dict] = []

    for service, entries in history.items():
        if len(entries) < MIN_HISTORY_DAYS + 1:
            log.debug(
                "Skipping '%s': only %d days of history (need %d)",
                service, len(entries), MIN_HISTORY_DAYS + 1,
            )
            continue

        dates  = [e[0] for e in entries]
        costs  = [e[1] for e in entries]
        latest = costs[-1]
        baseline_costs = costs[:-1]  # Exclude today from baseline

        z    = zscore(latest, baseline_costs)
        mean = sum(baseline_costs) / len(baseline_costs)

        if abs(z) >= ZSCORE_THRESHOLD:
            delta_pct = ((latest - mean) / mean * 100) if mean > 0 else 0.0
            anomalies.append({
                "service"    : service,
                "date"       : dates[-1],
                "cost_usd"   : round(latest, 4),
                "mean_usd"   : round(mean, 4),
                "delta_pct"  : round(delta_pct, 1),
                "zscore"     : round(z, 2),
                # Last 30 days of trend (excluding today) for Bedrock context
                "history_30d": [round(c, 4) for c in baseline_costs[-30:]],
            })

    anomalies.sort(key=lambda x: abs(x["zscore"]), reverse=True)
    log.info("Detected %d anomalies (threshold=%.1f)", len(anomalies), ZSCORE_THRESHOLD)
    return anomalies


###############################################################################
# Bedrock prompt engineering
###############################################################################

def build_prompt(anomalies: list[dict]) -> str:
    """
    Build a structured FinOps analysis prompt for Claude.

    We constrain the LLM to be specific, technical, and actionable to prevent
    generic or hallucinated advice. We provide exact numbers and trends.
    """
    lines = [
        "You are a senior AWS FinOps architect with deep expertise in cost "
        "optimization and cloud infrastructure.\n"
        "Below is a list of AWS services where today's cost is a statistical anomaly "
        f"compared to the historical 90-day baseline (Z-score threshold: {ZSCORE_THRESHOLD}).\n\n"
        "For EACH service, provide exactly:\n"
        "1. SEVERITY: Choose one of: LOW / MEDIUM / HIGH / CRITICAL\n"
        "   (CRITICAL = Z-score > 10 or Delta > 500%, HIGH = Z-score 5-10, "
        "MEDIUM = Z-score 3-5, LOW = below that)\n"
        "2. WHAT HAPPENED: One sentence describing the cost movement direction and magnitude.\n"
        "3. LIKELY CAUSE: Specific technical root cause — mention instance types, "
        "API calls, data transfer patterns, Reserved Instance changes, NAT Gateway, "
        "S3 lifecycle, etc. Be as precise as the data allows.\n"
        "4. ACTION: One concrete next step. Include the exact AWS CLI command or "
        "console path to investigate (e.g. `aws ce get-cost-and-usage ...`, "
        "`aws logs filter-log-events ...`, or Billing Dashboard → Cost Explorer → "
        "Filter: Service).\n\n"
        "FORMAT RULES:\n"
        "- Plain text only. No markdown. No bullet points. No headers.\n"
        "- Separate each service analysis with a line of 60 dashes: "
        "------------------------------------------------------------\n"
        "- Label each field clearly: SEVERITY: / WHAT HAPPENED: / LIKELY CAUSE: / ACTION:\n\n"
        "DETECTED ANOMALIES:\n"
    ]

    for idx, a in enumerate(anomalies, start=1):
        lines.append(
            f"\n[Anomaly {idx}]\n"
            f"Service     : {a['service']}\n"
            f"Date        : {a['date']}\n"
            f"Cost today  : ${a['cost_usd']:.4f}\n"
            f"90-day mean : ${a['mean_usd']:.4f}\n"
            f"Delta       : {a['delta_pct']:+.1f}%\n"
            f"Z-score     : {a['zscore']:.2f}\n"
            f"30-day trend: {a['history_30d']}\n"
        )

    return "\n".join(lines)


###############################################################################
# Bedrock invocation
###############################################################################

def invoke_bedrock(prompt: str) -> str:
    """
    Invoke the configured Claude model via Amazon Bedrock.

    Uses the Messages API format for Claude 3.x models.
    Returns the plain-text response content.
    """
    log.info("Invoking Bedrock model: %s", BEDROCK_MODEL_ID)

    body = {
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens"        : 4096,
        "temperature"       : 0.1,   # Low temperature = deterministic, factual
        "messages"          : [
            {
                "role"   : "user",
                "content": prompt,
            }
        ],
    }

    try:
        response = bedrock_client.invoke_model(
            modelId     = BEDROCK_MODEL_ID,
            body        = json.dumps(body),
            contentType = "application/json",
            accept      = "application/json",
        )
    except ClientError as exc:
        error_code = exc.response["Error"]["Code"]
        log.error("Bedrock API error [%s]: %s", error_code, exc)
        raise

    raw = json.loads(response["body"].read())
    content = raw.get("content", [])

    text_parts = [block["text"] for block in content if block.get("type") == "text"]
    result = "\n".join(text_parts).strip()

    log.info("Bedrock response received (%d chars)", len(result))
    return result


###############################################################################
# Alert formatting
###############################################################################

def format_email(anomalies: list[dict], ai_analysis: str) -> tuple[str, str]:
    """
    Build the SNS email subject and body.

    Returns (subject, body) tuple.
    """
    today = date.today().isoformat()
    count = len(anomalies)
    subject = f"[COST ALERT] {count} anomaly/anomalies detected — {today}"

    separator = "=" * 70

    # Statistical summary header
    stat_lines = [
        separator,
        f"AWS COST ANOMALY REPORT — {today}",
        f"Anomalies Detected: {count}  |  Z-Score Threshold: {ZSCORE_THRESHOLD}",
        separator,
        "",
        "STATISTICAL SUMMARY",
        "-" * 40,
    ]

    for a in anomalies:
        stat_lines.append(
            f"Service    : {a['service']}\n"
            f"Date       : {a['date']}\n"
            f"Cost today : ${a['cost_usd']:.4f}  |  "
            f"90-day mean: ${a['mean_usd']:.4f}  |  "
            f"Delta: {a['delta_pct']:+.1f}%  |  "
            f"Z-score: {a['zscore']:.2f}\n"
            f"30d trend  : {a['history_30d']}\n"
        )

    stat_lines.append("")
    stat_lines.append(separator)
    stat_lines.append("AI ANALYSIS (Claude via Amazon Bedrock)")
    stat_lines.append(separator)
    stat_lines.append("")
    stat_lines.append(ai_analysis)
    stat_lines.append("")
    stat_lines.append(separator)
    stat_lines.append("This report was generated automatically by the AWS Cost Anomaly Detector.")
    stat_lines.append(f"Z-Score Threshold: {ZSCORE_THRESHOLD} | Model: {BEDROCK_MODEL_ID}")
    stat_lines.append(separator)

    body = "\n".join(stat_lines)
    return subject, body


###############################################################################
# SNS publishing
###############################################################################

def publish_alert(subject: str, message: str) -> None:
    """Publish the cost anomaly alert to SNS."""
    log.info("Publishing alert to SNS topic: %s", SNS_TOPIC_ARN)

    try:
        response = sns_client.publish(
            TopicArn = SNS_TOPIC_ARN,
            Subject  = subject[:100],  # SNS subject max length 100 chars
            Message  = message,
        )
        log.info("SNS message published. MessageId: %s", response["MessageId"])
    except ClientError as exc:
        log.error("Failed to publish SNS alert: %s", exc)
        raise


###############################################################################
# Lambda handler
###############################################################################

def lambda_handler(event: dict, context: Any) -> dict[str, Any]:
    """
    Entry point for the Anomaly Detector Lambda.

    Flow:
    1. Load full cost history from DynamoDB.
    2. Calculate Z-scores; collect anomalies above threshold.
    3. If anomalies found: build a prompt, invoke Bedrock, publish SNS alert.
    4. Return structured result summary.
    """
    log.info("Anomaly Detector Lambda started | event=%s", json.dumps(event))

    try:
        history   = load_history()
        anomalies = detect_anomalies(history)

        if not anomalies:
            log.info("No anomalies detected. No alert will be sent.")
            return {
                "statusCode"      : 200,
                "anomalies_found" : 0,
                "alert_sent"      : False,
                "message"         : "All costs within normal Z-score range.",
            }

        log.info(
            "Processing %d anomaly/anomalies with Bedrock...", len(anomalies)
        )

        prompt      = build_prompt(anomalies)
        ai_analysis = invoke_bedrock(prompt)
        subject, body = format_email(anomalies, ai_analysis)
        publish_alert(subject, body)

        result = {
            "statusCode"      : 200,
            "anomalies_found" : len(anomalies),
            "alert_sent"      : True,
            "services"        : [a["service"] for a in anomalies],
        }
        log.info("Anomaly Detector completed: %s", json.dumps(result))
        return result

    except Exception as exc:
        log.exception("Fatal error in anomaly_detector: %s", exc)
        raise
