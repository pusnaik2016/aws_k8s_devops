# ─────────────────────────────────────────────────────────────────────────────
# Karpenter Module — Outputs
# ─────────────────────────────────────────────────────────────────────────────

output "controller_role_arn" {
  description = "Karpenter controller IAM role ARN"
  value       = aws_iam_role.karpenter_controller.arn
}

output "node_role_arn" {
  description = "Karpenter node IAM role ARN"
  value       = aws_iam_role.karpenter_node.arn
}

output "node_instance_profile_name" {
  description = "Karpenter node instance profile name"
  value       = aws_iam_instance_profile.karpenter_node.name
}

output "interruption_queue_name" {
  description = "SQS queue name for Karpenter interruption handling"
  value       = aws_sqs_queue.karpenter_interruption.name
}

output "interruption_queue_arn" {
  description = "SQS queue ARN for Karpenter interruption handling"
  value       = aws_sqs_queue.karpenter_interruption.arn
}
