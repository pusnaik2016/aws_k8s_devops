# ==============================================================================
# Secondary Region — Outputs
# ==============================================================================
output "vpc_id" { value = module.vpc.vpc_id }
output "eks_cluster_name" { value = module.eks.cluster_name }
output "eks_cluster_endpoint" { value = module.eks.cluster_endpoint; sensitive = true }
output "aurora_reader_endpoint" { value = aws_rds_cluster.secondary.reader_endpoint }
