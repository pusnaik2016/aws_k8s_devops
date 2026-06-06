# ─────────────────────────────────────────────────────────────
# ElastiCache Redis — Session State + LLM Response Cache
# ─────────────────────────────────────────────────────────────
# Dual purpose:
# 1. WebSocket session state (user_id → conversation history)
# 2. LLM cache (SHA256(prompt) → cached AI response, TTL 1h)
# ─────────────────────────────────────────────────────────────

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.project_name}-${var.environment}-redis-subnet"
  subnet_ids = var.private_subnet_ids

  tags = local.common_tags
}

resource "aws_elasticache_parameter_group" "redis" {
  family = "redis7"
  name   = "${var.project_name}-${var.environment}-redis-params"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"  # Evict least recently used keys when memory full
  }

  parameter {
    name  = "notify-keyspace-events"
    value = "Ex"  # Enable expired key notifications (for KEDA scaling)
  }

  tags = local.common_tags
}

data "aws_ssm_parameter" "redis_auth" {
  name = "/${var.project_name}/${var.environment}/redis/auth-token"
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${var.project_name}-${var.environment}-redis"
  description          = "Redis cluster for ${var.project_name} ${var.environment}"

  node_type            = var.redis_node_type
  num_cache_clusters   = 2  # Primary + Replica for HA
  engine_version       = var.redis_engine_version
  port                 = 6379
  parameter_group_name = aws_elasticache_parameter_group.redis.name
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [var.redis_security_group_id]

  auth_token                 = data.aws_ssm_parameter.redis_auth.value
  transit_encryption_enabled = true
  at_rest_encryption_enabled = true

  automatic_failover_enabled = true
  multi_az_enabled           = true

  snapshot_retention_limit = 3
  snapshot_window          = "05:00-06:00"
  maintenance_window       = "sun:06:00-sun:07:00"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-redis"
  })
}
