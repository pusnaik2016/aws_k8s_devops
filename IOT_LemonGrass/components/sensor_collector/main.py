"""
AWS IoT Greengrass v2 — Sensor Collector Component
====================================================
Simulates temperature, humidity, and pressure sensor readings from a
customer site. Publishes telemetry data to local MQTT topics via the
Greengrass IPC (Inter-Process Communication) SDK.

This component runs as a long-lived process on the Greengrass Core device,
generating sensor data at configurable intervals.

Author: Pushparaj Naik
"""

import json
import random
import time
import traceback
from datetime import datetime, timezone

try:
    import awsiot.greengrasscoreipc as ipc
    from awsiot.greengrasscoreipc.model import (
        PublishToIoTCoreRequest,
        QOS,
    )
    GREENGRASS_SDK_AVAILABLE = True
except ImportError:
    GREENGRASS_SDK_AVAILABLE = False
    print("[WARN] Greengrass IPC SDK not available — running in standalone mode")

# ---------------------------------------------------------------------------
# Configuration (overridable via Greengrass component recipe)
# ---------------------------------------------------------------------------
import os

THING_NAME = os.environ.get("AWS_IOT_THING_NAME", "iot-greengrass-site-mumbai")
SITE_NAME = os.environ.get("SITE_NAME", "site-mumbai")
TOPIC_PREFIX = os.environ.get("TOPIC_PREFIX", "dt/iot-greengrass")
PUBLISH_INTERVAL = int(os.environ.get("PUBLISH_INTERVAL_SECONDS", "10"))

# Sensor simulation parameters
TEMP_BASE = float(os.environ.get("TEMP_BASE", "28.0"))      # Base temperature (°C)
TEMP_VARIANCE = float(os.environ.get("TEMP_VARIANCE", "8.0"))
HUMIDITY_BASE = float(os.environ.get("HUMIDITY_BASE", "65.0"))
HUMIDITY_VARIANCE = float(os.environ.get("HUMIDITY_VARIANCE", "20.0"))
PRESSURE_BASE = float(os.environ.get("PRESSURE_BASE", "1013.25"))  # hPa
PRESSURE_VARIANCE = float(os.environ.get("PRESSURE_VARIANCE", "10.0"))


def generate_sensor_reading() -> dict:
    """Generate a simulated sensor reading with realistic variance."""
    return {
        "device_id": THING_NAME,
        "site": SITE_NAME,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "temperature": round(TEMP_BASE + random.uniform(-TEMP_VARIANCE, TEMP_VARIANCE), 2),
        "humidity": round(
            max(0, min(100, HUMIDITY_BASE + random.uniform(-HUMIDITY_VARIANCE, HUMIDITY_VARIANCE))),
            2,
        ),
        "pressure": round(PRESSURE_BASE + random.uniform(-PRESSURE_VARIANCE, PRESSURE_VARIANCE), 2),
        "battery_pct": round(random.uniform(70, 100), 1),
        "signal_strength_dbm": round(random.uniform(-90, -30), 1),
    }


def publish_via_greengrass(ipc_client, topic: str, payload: dict):
    """Publish telemetry via Greengrass IPC to IoT Core."""
    request = PublishToIoTCoreRequest(
        topic_name=topic,
        qos=QOS.AT_LEAST_ONCE,
        payload=json.dumps(payload).encode("utf-8"),
    )
    operation = ipc_client.new_publish_to_iot_core()
    operation.activate(request)
    operation.get_response().result(timeout=5.0)


def publish_standalone(topic: str, payload: dict):
    """Fallback: print telemetry to stdout (for local testing)."""
    print(f"[PUBLISH] Topic: {topic}")
    print(f"  Payload: {json.dumps(payload, indent=2)}")


def main():
    """Main loop — generate and publish sensor data at fixed intervals."""
    print(f"[INFO] Sensor Collector starting for {SITE_NAME} ({THING_NAME})")
    print(f"[INFO] Publishing to {TOPIC_PREFIX}/{SITE_NAME}/telemetry every {PUBLISH_INTERVAL}s")

    ipc_client = None
    if GREENGRASS_SDK_AVAILABLE:
        try:
            ipc_client = ipc.connect()
            print("[INFO] Connected to Greengrass IPC")
        except Exception as e:
            print(f"[WARN] Failed to connect to Greengrass IPC: {e}")
            print("[WARN] Falling back to standalone mode")

    telemetry_topic = f"{TOPIC_PREFIX}/{SITE_NAME}/telemetry"
    message_count = 0

    while True:
        try:
            reading = generate_sensor_reading()
            message_count += 1
            reading["message_seq"] = message_count

            if ipc_client:
                publish_via_greengrass(ipc_client, telemetry_topic, reading)
            else:
                publish_standalone(telemetry_topic, reading)

            if message_count % 10 == 0:
                print(f"[INFO] Published {message_count} messages | "
                      f"Last: temp={reading['temperature']}°C, "
                      f"humidity={reading['humidity']}%")

            time.sleep(PUBLISH_INTERVAL)

        except KeyboardInterrupt:
            print(f"\n[INFO] Sensor Collector stopped after {message_count} messages")
            break
        except Exception as e:
            print(f"[ERROR] Publish failed: {e}")
            traceback.print_exc()
            time.sleep(5)  # Back off on error


if __name__ == "__main__":
    main()
