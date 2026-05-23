# -----------------------------------------------------------------------------
# Root-Level Outputs
# -----------------------------------------------------------------------------

# IoT Core
output "iot_endpoint" {
  description = "AWS IoT Core MQTT endpoint for device connections"
  value       = module.iot_core.iot_endpoint
}

output "thing_names" {
  description = "Names of all provisioned IoT Things"
  value       = module.iot_core.thing_names
}

output "thing_group_name" {
  description = "IoT Thing Group name"
  value       = module.iot_core.thing_group_name
}

# Storage
output "telemetry_bucket_name" {
  description = "S3 bucket for raw telemetry archive"
  value       = module.storage.s3_bucket_name
}

output "timestream_database" {
  description = "Timestream database name"
  value       = module.storage.timestream_database_name
}

# Monitoring
output "alert_sns_topic_arn" {
  description = "SNS topic ARN for IoT alerts"
  value       = module.monitoring.sns_topic_arn
}

output "cloudwatch_dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = module.monitoring.dashboard_url
}

# Greengrass
output "greengrass_role_alias" {
  description = "IoT Role Alias for Greengrass Token Exchange Service"
  value       = module.iot_greengrass.role_alias_name
}
