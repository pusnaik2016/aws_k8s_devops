output "aurora_cluster_endpoint"        { value = aws_rds_cluster.primary.endpoint }
output "aurora_cluster_reader_endpoint" { value = aws_rds_cluster.primary.reader_endpoint }
output "aurora_cluster_id"              { value = aws_rds_cluster.primary.id }
output "global_cluster_id"             { value = aws_rds_global_cluster.main.id }
output "dynamodb_table_name"           { value = aws_dynamodb_table.sessions.name }
output "redis_endpoint"                { value = aws_elasticache_replication_group.redis.primary_endpoint_address }
output "aurora_sg_id"                  { value = aws_security_group.aurora.id }
output "redis_sg_id"                   { value = aws_security_group.redis.id }
