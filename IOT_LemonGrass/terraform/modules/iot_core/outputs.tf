# -----------------------------------------------------------------------------
# IoT Core Module — Outputs
# -----------------------------------------------------------------------------

output "iot_endpoint" {
  description = "AWS IoT Core ATS endpoint for MQTT connections"
  value       = data.aws_iot_endpoint.ats.endpoint_address
}

output "thing_names" {
  description = "Map of customer site to IoT Thing name"
  value       = { for site, thing in aws_iot_thing.device : site => thing.name }
}

output "thing_arns" {
  description = "Map of customer site to IoT Thing ARN"
  value       = { for site, thing in aws_iot_thing.device : site => thing.arn }
}

output "thing_group_name" {
  description = "IoT Thing Group name for fleet management"
  value       = aws_iot_thing_group.fleet.name
}

output "thing_group_arn" {
  description = "IoT Thing Group ARN"
  value       = aws_iot_thing_group.fleet.arn
}

output "certificate_arns" {
  description = "Map of customer site to certificate ARN"
  value       = { for site, cert in aws_iot_certificate.device_cert : site => cert.arn }
}

output "policy_name" {
  description = "IoT policy name attached to all devices"
  value       = aws_iot_policy.device_policy.name
}
