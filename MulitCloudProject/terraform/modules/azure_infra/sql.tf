# =============================================================================
# AZURE SQL Database Hyperscale
# =============================================================================

resource "random_password" "sql_admin" {
  length           = 32
  special          = true
  override_special = "!@#$%^&*"
}

resource "azurerm_mssql_server" "main" {
  name                         = "${local.name_prefix}-sqlserver"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = random_password.sql_admin.result
  minimum_tls_version          = "1.2"
  public_network_access_enabled = false

  azuread_administrator {
    login_username = var.azure_ad_admin_group_name
    object_id      = azuread_group.admins.object_id
    tenant_id      = local.tenant_id
  }

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags
}

resource "azurerm_mssql_database" "main" {
  name      = "${local.name_prefix}-clearingdb"
  server_id = azurerm_mssql_server.main.id
  sku_name  = var.sql_sku

  # Hyperscale tier settings
  max_size_gb                  = 1024
  zone_redundant               = true
  read_replica_count           = 2
  storage_account_type         = "Geo"

  # Backup
  long_term_retention_policy {
    weekly_retention  = "P4W"
    monthly_retention = "P12M"
    yearly_retention  = "P7Y"   # SOX: 7 years
    week_of_year      = 1
  }

  # Threat Detection
  threat_detection_policy {
    state                      = "Enabled"
    email_addresses            = ["security@example.com"]
    retention_days             = 365
    disabled_alerts            = []
    email_account_admins       = "Enabled"
  }

  tags = local.tags
}

# Private Endpoint
resource "azurerm_private_endpoint" "sql" {
  name                = "${local.name_prefix}-sql-pe"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.data.id

  private_service_connection {
    name                           = "${local.name_prefix}-sql-psc"
    private_connection_resource_id = azurerm_mssql_server.main.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  tags = local.tags
}

# Auditing
resource "azurerm_mssql_server_extended_auditing_policy" "main" {
  server_id                               = azurerm_mssql_server.main.id
  storage_endpoint                        = azurerm_storage_account.flow_logs.primary_blob_endpoint
  storage_account_access_key              = azurerm_storage_account.flow_logs.primary_access_key
  storage_account_access_key_is_secondary = false
  retention_in_days                       = 365
  log_monitoring_enabled                  = true
}

# Diagnostic Settings
resource "azurerm_monitor_diagnostic_setting" "sql" {
  name                       = "${local.name_prefix}-sql-diag"
  target_resource_id         = azurerm_mssql_database.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "SQLSecurityAuditEvents"
  }

  enabled_log {
    category = "QueryStoreRuntimeStatistics"
  }

  metric {
    category = "Basic"
    enabled  = true
  }
}
