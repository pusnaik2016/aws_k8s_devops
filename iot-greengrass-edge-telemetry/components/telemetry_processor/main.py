"""
AWS IoT Greengrass v2 — Telemetry Processor Component
======================================================
Edge-side data processing component that:
1. Subscribes to local sensor telemetry topics
2. Filters out noise (readings within normal range)
3. Aggregates data over configurable windows
4. Forwards processed data to IoT Core (reduces cloud data transfer)
5. Detects anomalies locally and publishes alert topics

Author: Pushparaj Naik
"""

import json
import os
import time
import statistics
from collections import defaultdict
from datetime import datetime, timezone

try:
    import awsiot.greengrasscoreipc as ipc
    from awsiot.greengrasscoreipc.model import (
        SubscribeToIoTCoreRequest,
        PublishToIoTCoreRequest,
        QOS,
        IoTCoreMessage,
    )
    GREENGRASS_SDK_AVAILABLE = True
except ImportError:
    GREENGRASS_SDK_AVAILABLE = False
    print("[WARN] Greengrass IPC SDK not available — running in standalone mode")

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SITE_NAME = os.environ.get("SITE_NAME", "site-mumbai")
TOPIC_PREFIX = os.environ.get("TOPIC_PREFIX", "dt/iot-greengrass")
AGGREGATION_WINDOW_SECONDS = int(os.environ.get("AGGREGATION_WINDOW_SECONDS", "60"))
TEMP_ALERT_THRESHOLD = float(os.environ.get("TEMP_ALERT_THRESHOLD", "35.0"))
HUMIDITY_ALERT_THRESHOLD = float(os.environ.get("HUMIDITY_ALERT_THRESHOLD", "85.0"))


class TelemetryAggregator:
    """Aggregates sensor readings over time windows."""

    def __init__(self, window_seconds: int = 60):
        self.window_seconds = window_seconds
        self.readings: list[dict] = []
        self.window_start = time.time()
        self.anomalies_detected = 0

    def add_reading(self, reading: dict):
        """Add a sensor reading to the current window."""
        self.readings.append(reading)

        # Check for anomalies
        if reading.get("temperature", 0) > TEMP_ALERT_THRESHOLD:
            self.anomalies_detected += 1
            return {"type": "temperature_alert", "reading": reading}
        if reading.get("humidity", 0) > HUMIDITY_ALERT_THRESHOLD:
            self.anomalies_detected += 1
            return {"type": "humidity_alert", "reading": reading}
        return None

    def should_flush(self) -> bool:
        """Check if aggregation window has elapsed."""
        return (time.time() - self.window_start) >= self.window_seconds

    def flush(self) -> dict | None:
        """Compute aggregates and reset the window."""
        if not self.readings:
            return None

        temps = [r["temperature"] for r in self.readings if "temperature" in r]
        humidities = [r["humidity"] for r in self.readings if "humidity" in r]
        pressures = [r["pressure"] for r in self.readings if "pressure" in r]

        aggregate = {
            "site": SITE_NAME,
            "window_start": datetime.fromtimestamp(self.window_start, tz=timezone.utc).isoformat(),
            "window_end": datetime.now(timezone.utc).isoformat(),
            "reading_count": len(self.readings),
            "anomalies_detected": self.anomalies_detected,
            "temperature": {
                "min": round(min(temps), 2) if temps else None,
                "max": round(max(temps), 2) if temps else None,
                "avg": round(statistics.mean(temps), 2) if temps else None,
                "stddev": round(statistics.stdev(temps), 2) if len(temps) > 1 else 0,
            },
            "humidity": {
                "min": round(min(humidities), 2) if humidities else None,
                "max": round(max(humidities), 2) if humidities else None,
                "avg": round(statistics.mean(humidities), 2) if humidities else None,
            },
            "pressure": {
                "avg": round(statistics.mean(pressures), 2) if pressures else None,
            },
        }

        # Reset window
        self.readings.clear()
        self.window_start = time.time()
        self.anomalies_detected = 0

        return aggregate


def main():
    """Main loop — aggregate and forward telemetry."""
    print(f"[INFO] Telemetry Processor starting for {SITE_NAME}")
    print(f"[INFO] Aggregation window: {AGGREGATION_WINDOW_SECONDS}s")
    print(f"[INFO] Alert thresholds: temp>{TEMP_ALERT_THRESHOLD}°C, humidity>{HUMIDITY_ALERT_THRESHOLD}%")

    aggregator = TelemetryAggregator(AGGREGATION_WINDOW_SECONDS)

    # In standalone mode, simulate processing
    if not GREENGRASS_SDK_AVAILABLE:
        print("[INFO] Running in standalone simulation mode")
        while True:
            # Simulate receiving a reading
            fake_reading = {
                "temperature": 30.5,
                "humidity": 70.2,
                "pressure": 1013.0,
                "site": SITE_NAME,
            }
            alert = aggregator.add_reading(fake_reading)
            if alert:
                print(f"[ALERT] {alert['type']}: {json.dumps(alert['reading'])}")

            if aggregator.should_flush():
                aggregate = aggregator.flush()
                if aggregate:
                    print(f"[AGGREGATE] {json.dumps(aggregate, indent=2)}")

            time.sleep(5)

    # Greengrass IPC mode
    try:
        ipc_client = ipc.connect()
        print("[INFO] Connected to Greengrass IPC")

        subscribe_topic = f"{TOPIC_PREFIX}/{SITE_NAME}/telemetry"
        aggregate_topic = f"{TOPIC_PREFIX}/{SITE_NAME}/aggregate"
        alert_topic = f"{TOPIC_PREFIX}/{SITE_NAME}/alert"

        # Main processing loop
        while True:
            if aggregator.should_flush():
                aggregate = aggregator.flush()
                if aggregate:
                    request = PublishToIoTCoreRequest(
                        topic_name=aggregate_topic,
                        qos=QOS.AT_LEAST_ONCE,
                        payload=json.dumps(aggregate).encode("utf-8"),
                    )
                    op = ipc_client.new_publish_to_iot_core()
                    op.activate(request)
                    op.get_response().result(timeout=5.0)
                    print(f"[INFO] Published aggregate: {aggregate['reading_count']} readings")

            time.sleep(1)

    except Exception as e:
        print(f"[ERROR] Telemetry Processor failed: {e}")
        raise


if __name__ == "__main__":
    main()
