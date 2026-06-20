# ============================================================================
# Azure Databases — PostgreSQL Flex (DR replica), Redis Cache
# ============================================================================

terraform {
  required_version = ">= 1.5"
}

resource "azurerm_resource_group" "databases" {
  name     = "${var.project}-${var.environment}-databases-rg"
  location = var.azure_region
  tags     = var.common_tags
}

# ──────────────────────────────────────────────────────────────────────────────
# Azure Database for PostgreSQL — Flexible Server (DR Replica)
# ──────────────────────────────────────────────────────────────────────────────

resource "azurerm_postgresql_flexible_server" "dr" {
  name                          = "${var.project}-${var.environment}-pg-dr"
  resource_group_name           = azurerm_resource_group.databases.name
  location                      = azurerm_resource_group.databases.location
  version                       = "16"
  delegated_subnet_id           = var.database_subnet_id
  private_dns_zone_id           = var.private_dns_zone_id
  administrator_login           = var.db_admin_username
  administrator_password        = var.db_admin_password
  sku_name                      = var.environment == "prod" ? "GP_Standard_D4s_v3" : "GP_Standard_D2s_v3"
  storage_mb                    = var.environment == "prod" ? 131072 : 32768
  backup_retention_days         = var.environment == "prod" ? 35 : 7
  geo_redundant_backup_enabled  = var.environment == "prod" ? true : false
  zone                          = "1"

  high_availability {
    mode                      = var.environment == "prod" ? "ZoneRedundant" : "Disabled"
    standby_availability_zone = "2"
  }

  authentication {
    active_directory_auth_enabled = true
    password_auth_enabled         = true
  }

  tags = merge(var.common_tags, {
    Name               = "${var.project}-${var.environment}-pg-dr"
    Role               = "dr-replica"
    DataClassification = "phi"
    Compliance         = "hipaa"
  })
}

resource "azurerm_postgresql_flexible_server_database" "healthcloud" {
  name      = "healthcloud"
  server_id = azurerm_postgresql_flexible_server.dr.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_postgresql_flexible_server_configuration" "ssl" {
  name      = "require_secure_transport"
  server_id = azurerm_postgresql_flexible_server.dr.id
  value     = "ON"
}

resource "azurerm_postgresql_flexible_server_configuration" "log_connections" {
  name      = "log_connections"
  server_id = azurerm_postgresql_flexible_server.dr.id
  value     = "ON"
}

# ──────────────────────────────────────────────────────────────────────────────
# Azure Cache for Redis
# ──────────────────────────────────────────────────────────────────────────────

resource "azurerm_redis_cache" "dr" {
  name                = "${var.project}-${var.environment}-redis-dr"
  location            = azurerm_resource_group.databases.location
  resource_group_name = azurerm_resource_group.databases.name
  capacity            = var.environment == "prod" ? 2 : 1
  family              = "C"
  sku_name            = var.environment == "prod" ? "Premium" : "Standard"
  enable_non_ssl_port = false
  minimum_tls_version = "1.2"

  redis_configuration {
    maxmemory_policy = "allkeys-lru"
  }

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-redis-dr"
    Role = "dr"
  })
}
