# -----------------------------------------------------------------------------
# IAM Module — Outputs
# -----------------------------------------------------------------------------

output "greengrass_tes_role_arn" {
  description = "ARN of the Greengrass Token Exchange Service role"
  value       = aws_iam_role.greengrass_tes.arn
}

output "greengrass_tes_role_name" {
  description = "Name of the Greengrass TES role"
  value       = aws_iam_role.greengrass_tes.name
}

output "iot_rules_role_arn" {
  description = "ARN of the IoT Rules Engine role"
  value       = aws_iam_role.iot_rules.arn
}

output "lambda_exec_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_exec.arn
}

output "kms_key_arn" {
  description = "ARN of the shared KMS encryption key"
  value       = aws_kms_key.main.arn
}

output "kms_key_id" {
  description = "ID of the shared KMS encryption key"
  value       = aws_kms_key.main.key_id
}
