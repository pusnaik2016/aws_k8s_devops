# ==============================================================================
# CloudWatch Module — Outputs
# ==============================================================================
output "aurora_audit_log_group_name" {
  value = aws_cloudwatch_log_group.aurora_audit.name
}

output "aurora_slowquery_log_group_name" {
  value = aws_cloudwatch_log_group.aurora_slowquery.name
}

output "application_log_group_name" {
  value = aws_cloudwatch_log_group.application.name
}

output "karpenter_log_group_name" {
  value = aws_cloudwatch_log_group.karpenter.name
}

output "dashboard_name" {
  value = aws_cloudwatch_dashboard.main.dashboard_name
}
