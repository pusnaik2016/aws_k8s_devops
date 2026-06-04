# =============================================================================
# AZURE Key Vault — Secrets & Key Management
# =============================================================================

resource "azurerm_key_vault" "main" {
  name                        = replace("${local.name_prefix}-kv", "-", "")
  location                    = azurerm_resource_group.main.location
  resource_group_name         = azurerm_resource_group.main.name
  tenant_id                   = local.tenant_id
  sku_name                    = "premium" # HSM-backed keys for compliance
  enabled_for_disk_encryption = true
  purge_protection_enabled    = true
  soft_delete_retention_days  = 90
  enable_rbac_authorization   = true

  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = [
      azurerm_subnet.aks_system.id,
      azurerm_subnet.aks_user.id,
      azurerm_subnet.data.id,
    ]
  }

  tags = local.tags
}

# Store SQL admin password
resource "azurerm_key_vault_secret" "sql_password" {
  name         = "sql-admin-password"
  value        = random_password.sql_admin.result
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"

  depends_on = [
    azurerm_role_assignment.admins_keyvault_admin
  ]
}

# Encryption key for SQL TDE
resource "azurerm_key_vault_key" "sql_tde" {
  name         = "${local.name_prefix}-sql-tde-key"
  key_vault_id = azurerm_key_vault.main.id
  key_type     = "RSA"
  key_size     = 2048
  key_opts     = ["decrypt", "encrypt", "sign", "unwrapKey", "verify", "wrapKey"]

  rotation_policy {
    automatic {
      time_before_expiry = "P30D"
    }
    expire_after         = "P90D"
    notify_before_expiry = "P29D"
  }

  depends_on = [
    azurerm_role_assignment.admins_keyvault_admin
  ]
}

# Diagnostic Settings
resource "azurerm_monitor_diagnostic_setting" "keyvault" {
  name                       = "${local.name_prefix}-kv-diag"
  target_resource_id         = azurerm_key_vault.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "AuditEvent"
  }

  enabled_log {
    category = "AzurePolicyEvaluationDetails"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
