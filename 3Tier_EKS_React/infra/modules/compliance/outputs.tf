output "cloudtrail_log_group" {
  description = "CloudTrail CloudWatch log group name"
  value       = aws_cloudwatch_log_group.cloudtrail.name
}
