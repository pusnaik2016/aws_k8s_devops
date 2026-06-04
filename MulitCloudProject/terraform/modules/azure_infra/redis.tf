# =============================================================================
# AZURE Cache for Redis Enterprise
# =============================================================================

resource "azurerm_redis_cache" "main" {
  name                = "${local.name_prefix}-redis"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  capacity            = 1
  family              = "P"
  sku_name            = "Premium"
  shard_count         = 3
  replicas_per_master = 1

  enable_non_ssl_port = false
  minimum_tls_version = "1.2"

  redis_configuration {
    maxmemory_reserved = 256
    maxmemory_delta    = 256
    maxmemory_policy   = "volatile-lru"

    # AOF persistence for durability
    aof_backup_enabled = false
  }

  # Scheduled patching
  patch_schedule {
    day_of_week    = "Sunday"
    start_hour_utc = 3
  }

  zones = ["1", "2"]

  tags = local.tags
}

# Private Endpoint
resource "azurerm_private_endpoint" "redis" {
  name                = "${local.name_prefix}-redis-pe"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.data.id

  private_service_connection {
    name                           = "${local.name_prefix}-redis-psc"
    private_connection_resource_id = azurerm_redis_cache.main.id
    subresource_names              = ["redisCache"]
    is_manual_connection           = false
  }

  tags = local.tags
}

# Diagnostic Settings
resource "azurerm_monitor_diagnostic_setting" "redis" {
  name                       = "${local.name_prefix}-redis-diag"
  target_resource_id         = azurerm_redis_cache.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
