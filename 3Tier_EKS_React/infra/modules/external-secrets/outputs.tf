output "role_arn" {
  description = "IAM role ARN for External Secrets service account"
  value       = var.enable ? aws_iam_role.external_secrets[0].arn : ""
}
