output "sns_topic_arn"          { value = aws_sns_topic.alerts.arn }
output "eks_log_group_arn"      { value = aws_cloudwatch_log_group.eks.arn }
output "flow_log_group_arn"     { value = aws_cloudwatch_log_group.vpc_flow_logs.arn }
output "health_check_id"        { value = aws_route53_health_check.primary.id }
output "dashboard_name"         { value = aws_cloudwatch_dashboard.main.dashboard_name }
