"""
AWS IoT Telemetry Simulator
============================
Standalone MQTT client that simulates IoT devices publishing telemetry
to AWS IoT Core. Use this for local testing without Greengrass.

Prerequisites:
  pip install awsiotsdk
  Certificates from terraform apply (saved in terraform/modules/iot_core/certs/)

Usage:
  python scripts/simulate_telemetry.py \
    --endpoint <iot-endpoint>.iot.us-east-1.amazonaws.com \
    --cert certs/site-mumbai-certificate.pem \
    --key certs/site-mumbai-private.key \
    --site site-mumbai \
    --count 100

Author: Pushparaj Naik
"""

import argparse
import json
import random
import ssl
import time
from datetime import datetime, timezone

try:
    from awscrt import mqtt
    from awsiot import mqtt_connection_builder
    AWS_IOT_SDK = True
except ImportError:
    AWS_IOT_SDK = False
    print("[WARN] awsiotsdk not installed. Install: pip install awsiotsdk")
    print("[INFO] Running in dry-run mode (no actual MQTT publishing)")


def generate_reading(site: str, device_id: str, seq: int) -> dict:
    """Generate a simulated sensor reading."""
    return {
        "device_id": device_id,
        "site": site,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "message_seq": seq,
        "temperature": round(28.0 + random.uniform(-8, 12), 2),  # Occasionally exceeds 35
        "humidity": round(65.0 + random.uniform(-20, 25), 2),     # Occasionally exceeds 85
        "pressure": round(1013.25 + random.uniform(-10, 10), 2),
        "battery_pct": round(random.uniform(70, 100), 1),
        "signal_strength_dbm": round(random.uniform(-90, -30), 1),
    }


def main():
    parser = argparse.ArgumentParser(description="IoT Telemetry Simulator")
    parser.add_argument("--endpoint", required=True, help="AWS IoT endpoint")
    parser.add_argument("--cert", required=True, help="Path to device certificate PEM")
    parser.add_argument("--key", required=True, help="Path to device private key")
    parser.add_argument("--root-ca", default="AmazonRootCA1.pem", help="Path to root CA")
    parser.add_argument("--site", default="site-mumbai", help="Customer site name")
    parser.add_argument("--topic-prefix", default="dt/iot-greengrass", help="MQTT topic prefix")
    parser.add_argument("--count", type=int, default=50, help="Number of messages to send")
    parser.add_argument("--interval", type=float, default=5.0, help="Seconds between messages")
    parser.add_argument("--dry-run", action="store_true", help="Print messages without publishing")
    args = parser.parse_args()

    device_id = f"iot-greengrass-{args.site}"
    topic = f"{args.topic_prefix}/{args.site}/telemetry"

    print(f"{'=' * 60}")
    print(f"  IoT Telemetry Simulator")
    print(f"  Site:     {args.site}")
    print(f"  Device:   {device_id}")
    print(f"  Topic:    {topic}")
    print(f"  Messages: {args.count}")
    print(f"  Interval: {args.interval}s")
    print(f"{'=' * 60}")

    mqtt_connection = None
    if AWS_IOT_SDK and not args.dry_run:
        mqtt_connection = mqtt_connection_builder.mtls_from_path(
            endpoint=args.endpoint,
            cert_filepath=args.cert,
            pri_key_filepath=args.key,
            ca_filepath=args.root_ca,
            client_id=device_id,
            clean_session=False,
            keep_alive_secs=30,
        )
        connect_future = mqtt_connection.connect()
        connect_future.result(timeout=10)
        print(f"[CONNECTED] {device_id} → {args.endpoint}")

    alerts = 0
    for i in range(1, args.count + 1):
        reading = generate_reading(args.site, device_id, i)
        payload = json.dumps(reading)

        is_alert = reading["temperature"] > 35 or reading["humidity"] > 85
        if is_alert:
            alerts += 1

        if mqtt_connection:
            mqtt_connection.publish(
                topic=topic,
                payload=payload,
                qos=mqtt.QoS.AT_LEAST_ONCE,
            )
            status = "🔴 ALERT" if is_alert else "✅ OK"
            print(f"[{i}/{args.count}] {status} | temp={reading['temperature']}°C "
                  f"humidity={reading['humidity']}%")
        else:
            status = "🔴 ALERT" if is_alert else "✅ OK"
            print(f"[DRY-RUN {i}/{args.count}] {status} | {payload[:80]}...")

        time.sleep(args.interval)

    print(f"\n{'=' * 60}")
    print(f"  Simulation Complete")
    print(f"  Total Messages: {args.count}")
    print(f"  Alerts Triggered: {alerts}")
    print(f"{'=' * 60}")

    if mqtt_connection:
        disconnect_future = mqtt_connection.disconnect()
        disconnect_future.result(timeout=10)
        print("[DISCONNECTED]")


if __name__ == "__main__":
    main()
