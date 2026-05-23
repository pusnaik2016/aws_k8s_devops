# ==============================================================================
# Primary Region — Outputs
# ==============================================================================

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value     = module.eks.cluster_endpoint
  sensitive = true
}

output "aurora_cluster_endpoint" {
  value = aws_rds_cluster.primary.endpoint
}

output "aurora_reader_endpoint" {
  value = aws_rds_cluster.primary.reader_endpoint
}

output "aurora_global_cluster_id" {
  value = aws_rds_global_cluster.main.id
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}

output "kms_eks_key_arn" {
  value = module.kms.eks_key_arn
}

output "kms_rds_key_arn" {
  value = module.kms.rds_key_arn
}

output "s3_audit_logs_bucket" {
  value = module.s3_audit_logs.bucket_id
}
