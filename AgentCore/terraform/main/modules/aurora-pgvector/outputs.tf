output "cluster_arn" {
  description = "ARN of the Aurora cluster"
  value       = aws_rds_cluster.this.arn
}

output "cluster_endpoint" {
  description = "Writer endpoint of the Aurora cluster"
  value       = aws_rds_cluster.this.endpoint
}

output "cluster_id" {
  description = "Identifier of the Aurora cluster"
  value       = aws_rds_cluster.this.cluster_identifier
}

output "database_name" {
  description = "Name of the database"
  value       = aws_rds_cluster.this.database_name
}

output "vpc_id" {
  description = "VPC ID where Aurora is deployed"
  value       = aws_vpc.this.id
}

output "security_group_id" {
  description = "Security group ID for Aurora"
  value       = aws_security_group.aurora.id
}

output "subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "secret_arn" {
  description = "ARN of the master user secret"
  value       = aws_rds_cluster.this.master_user_secret[0].secret_arn
}
