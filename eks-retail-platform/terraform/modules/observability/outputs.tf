output "app_log_group_name" { value = aws_cloudwatch_log_group.application.name }
output "payment_log_group_name" { value = aws_cloudwatch_log_group.payment.name }
output "istio_log_group_name" { value = aws_cloudwatch_log_group.istio.name }
output "fluentbit_role_arn" { value = aws_iam_role.fluentbit.arn }
output "dashboard_name" { value = aws_cloudwatch_dashboard.retail_platform.dashboard_name }
