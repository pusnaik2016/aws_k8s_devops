# -----------------------------------------------------------------------------
# IoT Greengrass Module — Outputs
# -----------------------------------------------------------------------------

output "role_alias_name" {
  description = "IoT Role Alias name for Greengrass TES"
  value       = aws_iot_role_alias.greengrass_tes.alias
}

output "role_alias_arn" {
  description = "IoT Role Alias ARN"
  value       = aws_iot_role_alias.greengrass_tes.arn
}

output "tes_policy_name" {
  description = "TES IoT Policy name"
  value       = aws_iot_policy.tes_policy.name
}

output "log_group_name" {
  description = "CloudWatch Log Group for Greengrass components"
  value       = aws_cloudwatch_log_group.greengrass.name
}
