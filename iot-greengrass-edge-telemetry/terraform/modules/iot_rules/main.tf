# -----------------------------------------------------------------------------
# IoT Rules Engine Module — Telemetry Routing & Alert Processing
# -----------------------------------------------------------------------------
# This module creates IoT Topic Rules that:
# 1. Archive ALL telemetry → S3 (raw data lake)
# 2. Stream ALL telemetry → Timestream (time-series analytics)
# 3. Alert on threshold breach → Lambda → SNS
# 4. Error action → S3 (dead letter for failed actions)
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Rule 1: Archive All Telemetry to S3
# Captures every MQTT message for compliance and long-term analysis
# Topic pattern: dt/iot-greengrass/+/telemetry (+ = site wildcard)
# -----------------------------------------------------------------------------
resource "aws_iot_topic_rule" "telemetry_to_s3" {
  name        = "${replace(var.project_name, "-", "_")}_telemetry_to_s3"
  description = "Archive all IoT telemetry data to S3"
  enabled     = true
  sql         = "SELECT *, topic() as mqtt_topic, timestamp() as ingestion_ts FROM '${var.telemetry_topic_prefix}/+/telemetry'"
  sql_version = "2016-03-23"

  s3 {
    bucket_name = var.s3_bucket_name
    key         = "telemetry/$${topic(2)}/$${parse_time(\"yyyy/MM/dd/HH\", timestamp())}/$${newuuid()}.json"
    role_arn    = var.iot_rules_role_arn
  }

  # Error action — save failed messages for debugging
  error_action {
    s3 {
      bucket_name = var.s3_bucket_name
      key         = "errors/s3-rule/$${timestamp()}-$${newuuid()}.json"
      role_arn    = var.iot_rules_role_arn
    }
  }

  tags = {
    Name = "${var.project_name}-telemetry-to-s3"
  }
}

# -----------------------------------------------------------------------------
# Rule 2: Stream All Telemetry to Timestream
# Enables real-time time-series analytics and dashboard queries
# -----------------------------------------------------------------------------
resource "aws_iot_topic_rule" "telemetry_to_timestream" {
  name        = "${replace(var.project_name, "-", "_")}_telemetry_to_timestream"
  description = "Stream IoT telemetry to Timestream for real-time analytics"
  enabled     = true
  sql         = "SELECT temperature, humidity, pressure, device_id, site FROM '${var.telemetry_topic_prefix}/+/telemetry'"
  sql_version = "2016-03-23"

  timestream {
    database_name = var.timestream_database_name
    table_name    = var.timestream_table_name
    role_arn      = var.iot_rules_role_arn

    dimension {
      name  = "device_id"
      value = "$${device_id}"
    }

    dimension {
      name  = "site"
      value = "$${site}"
    }

    timestamp {
      value = "$${timestamp()}"
      unit  = "MILLISECONDS"
    }
  }

  # Error action
  error_action {
    s3 {
      bucket_name = var.s3_bucket_name
      key         = "errors/timestream-rule/$${timestamp()}-$${newuuid()}.json"
      role_arn    = var.iot_rules_role_arn
    }
  }

  tags = {
    Name = "${var.project_name}-telemetry-to-timestream"
  }
}

# -----------------------------------------------------------------------------
# Rule 3: Temperature Alert — Threshold Breach Detection
# Fires when temperature exceeds the configured threshold
# Action: Invoke Lambda → Lambda publishes to SNS
# -----------------------------------------------------------------------------
resource "aws_iot_topic_rule" "temperature_alert" {
  name        = "${replace(var.project_name, "-", "_")}_temperature_alert"
  description = "Trigger alert when temperature exceeds ${var.alert_temperature_threshold}°C"
  enabled     = true
  sql         = "SELECT *, topic(2) as site_name, timestamp() as alert_ts FROM '${var.telemetry_topic_prefix}/+/telemetry' WHERE temperature > ${var.alert_temperature_threshold}"
  sql_version = "2016-03-23"

  lambda {
    function_arn = var.alert_lambda_arn
  }

  # Error action
  error_action {
    s3 {
      bucket_name = var.s3_bucket_name
      key         = "errors/alert-rule/$${timestamp()}-$${newuuid()}.json"
      role_arn    = var.iot_rules_role_arn
    }
  }

  tags = {
    Name = "${var.project_name}-temperature-alert"
  }
}

# -----------------------------------------------------------------------------
# Rule 4: Humidity Alert — Threshold Breach Detection
# -----------------------------------------------------------------------------
resource "aws_iot_topic_rule" "humidity_alert" {
  name        = "${replace(var.project_name, "-", "_")}_humidity_alert"
  description = "Trigger alert when humidity exceeds ${var.alert_humidity_threshold}%"
  enabled     = true
  sql         = "SELECT *, topic(2) as site_name, timestamp() as alert_ts FROM '${var.telemetry_topic_prefix}/+/telemetry' WHERE humidity > ${var.alert_humidity_threshold}"
  sql_version = "2016-03-23"

  lambda {
    function_arn = var.alert_lambda_arn
  }

  error_action {
    s3 {
      bucket_name = var.s3_bucket_name
      key         = "errors/humidity-alert/$${timestamp()}-$${newuuid()}.json"
      role_arn    = var.iot_rules_role_arn
    }
  }

  tags = {
    Name = "${var.project_name}-humidity-alert"
  }
}
