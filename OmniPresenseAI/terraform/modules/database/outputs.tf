# ─────────────────────────────────────────────────────────────
# Database Module — Outputs
# ─────────────────────────────────────────────────────────────

output "aurora_cluster_endpoint" {
  description = "Aurora cluster writer endpoint"
  value       = aws_rds_cluster.main.endpoint
}

output "aurora_reader_endpoint" {
  description = "Aurora cluster reader endpoint"
  value       = aws_rds_cluster.main.reader_endpoint
}

output "aurora_port" {
  description = "Aurora port"
  value       = aws_rds_cluster.main.port
}

output "aurora_database_name" {
  description = "Aurora database name"
  value       = aws_rds_cluster.main.database_name
}

output "redis_primary_endpoint" {
  description = "Redis primary endpoint"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "redis_reader_endpoint" {
  description = "Redis reader endpoint"
  value       = aws_elasticache_replication_group.redis.reader_endpoint_address
}

output "redis_port" {
  description = "Redis port"
  value       = 6379
}
