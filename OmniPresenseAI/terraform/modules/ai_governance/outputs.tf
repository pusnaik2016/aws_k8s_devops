# ─────────────────────────────────────────────────────────────
# AI Governance Module — Outputs
# ─────────────────────────────────────────────────────────────

output "guardrail_id" {
  description = "Bedrock Guardrail ID"
  value       = aws_bedrock_guardrail.main.guardrail_id
}

output "guardrail_arn" {
  description = "Bedrock Guardrail ARN"
  value       = aws_bedrock_guardrail.main.guardrail_arn
}

output "guardrail_version" {
  description = "Bedrock Guardrail version number"
  value       = aws_bedrock_guardrail_version.v1.version
}

output "bedrock_logs_bucket" {
  description = "S3 bucket for Bedrock invocation logs"
  value       = aws_s3_bucket.bedrock_logs.id
}

output "bedrock_log_group" {
  description = "CloudWatch log group for Bedrock invocations"
  value       = aws_cloudwatch_log_group.bedrock.name
}
