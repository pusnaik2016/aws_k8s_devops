###############################################################################
# Bedrock Config Module — Outputs
###############################################################################

output "model_id" {
  description = "The Bedrock model ID to be used across the stack."
  value       = var.model_id
}

output "invoke_arn_prefix" {
  description = "Base ARN prefix for Bedrock model invocation IAM policies."
  value       = "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.model_id}"
}
