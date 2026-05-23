"""
AWS IoT Alert Processor Lambda
================================
Triggered by IoT Rules Engine when sensor readings breach thresholds.
Enriches the alert payload with context and publishes to SNS for notification.

Author: Pushparaj Naik
"""

import json
import os
import logging
from datetime import datetime, timezone

import boto3

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SNS_TOPIC_ARN = os.environ.get("SNS_TOPIC_ARN", "")
PROJECT_NAME = os.environ.get("PROJECT_NAME", "iot-greengrass")
ENVIRONMENT = os.environ.get("ENVIRONMENT", "dev")

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# ---------------------------------------------------------------------------
# AWS Clients
# ---------------------------------------------------------------------------
sns_client = boto3.client("sns")


def lambda_handler(event, context):
    """
    Process IoT threshold alert from Rules Engine.

    Event payload (from IoT Rule SQL):
    {
        "temperature": 38.5,
        "humidity": 72.3,
        "pressure": 1012.5,
        "device_id": "iot-greengrass-site-mumbai",
        "site": "site-mumbai",
        "site_name": "site-mumbai",
        "alert_ts": 1716048000000
    }
    """
    logger.info(f"Alert received: {json.dumps(event)}")

    try:
        # Extract alert details
        device_id = event.get("device_id", "unknown")
        site = event.get("site_name", event.get("site", "unknown"))
        temperature = event.get("temperature")
        humidity = event.get("humidity")
        pressure = event.get("pressure")
        alert_ts = event.get("alert_ts", "")

        # Determine alert type
        alert_types = []
        if temperature and temperature > 35.0:
            alert_types.append(f"🌡️ HIGH TEMPERATURE: {temperature}°C (threshold: 35°C)")
        if humidity and humidity > 85.0:
            alert_types.append(f"💧 HIGH HUMIDITY: {humidity}% (threshold: 85%)")

        if not alert_types:
            alert_types.append("⚠️ THRESHOLD BREACH DETECTED")

        # Build notification message
        subject = f"[{ENVIRONMENT.upper()}] IoT Alert — {site}"
        message = build_alert_message(
            site=site,
            device_id=device_id,
            temperature=temperature,
            humidity=humidity,
            pressure=pressure,
            alert_types=alert_types,
        )

        # Publish to SNS
        if SNS_TOPIC_ARN:
            response = sns_client.publish(
                TopicArn=SNS_TOPIC_ARN,
                Subject=subject[:100],  # SNS subject limit
                Message=message,
                MessageAttributes={
                    "site": {"DataType": "String", "StringValue": site},
                    "severity": {"DataType": "String", "StringValue": "HIGH"},
                    "environment": {"DataType": "String", "StringValue": ENVIRONMENT},
                },
            )
            logger.info(f"SNS published: MessageId={response['MessageId']}")
        else:
            logger.warning("SNS_TOPIC_ARN not configured — alert not sent")

        return {
            "statusCode": 200,
            "body": json.dumps({
                "status": "alert_processed",
                "site": site,
                "alert_types": alert_types,
            }),
        }

    except Exception as e:
        logger.error(f"Alert processing failed: {str(e)}", exc_info=True)
        raise


def build_alert_message(site, device_id, temperature, humidity, pressure, alert_types):
    """Build a formatted alert notification message."""
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")

    msg = f"""
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  🚨 IoT SENSOR ALERT — {PROJECT_NAME.upper()}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📍 Site:        {site}
🔧 Device:      {device_id}
🕐 Time:        {timestamp}
🌍 Environment: {ENVIRONMENT.upper()}

━━━━━━━━ ALERT DETAILS ━━━━━━━━
"""
    for alert in alert_types:
        msg += f"\n  {alert}"

    msg += f"""

━━━━━━━━ SENSOR READINGS ━━━━━━━━

  🌡️ Temperature:  {temperature}°C
  💧 Humidity:      {humidity}%
  📊 Pressure:      {pressure} hPa

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Action Required: Investigate sensor readings
  Dashboard: https://console.aws.amazon.com/iot
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"""
    return msg
