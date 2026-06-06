# -----------------------------------------------------------------------------
# IoT Rules Module — Outputs
# -----------------------------------------------------------------------------

output "telemetry_s3_rule_arn" {
  description = "ARN of the telemetry-to-S3 rule"
  value       = aws_iot_topic_rule.telemetry_to_s3.arn
}

output "telemetry_timestream_rule_arn" {
  description = "ARN of the telemetry-to-Timestream rule"
  value       = aws_iot_topic_rule.telemetry_to_timestream.arn
}

output "temperature_alert_rule_arn" {
  description = "ARN of the temperature alert rule"
  value       = aws_iot_topic_rule.temperature_alert.arn
}

output "humidity_alert_rule_arn" {
  description = "ARN of the humidity alert rule"
  value       = aws_iot_topic_rule.humidity_alert.arn
}
