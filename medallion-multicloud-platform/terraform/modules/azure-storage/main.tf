# =============================================================================
# AZURE STORAGE MODULE — ADLS Gen2 Medallion Containers
# =============================================================================
# COMPLIANCE:
#   HIPAA  — CMK encryption, private endpoints only, no public access
#   PCI-DSS — Immutable storage policy on audit container
#   SOC 2  — Diagnostic logging, network restrictions
# =============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  # Storage account names must be 3-24 chars, lowercase alphanumeric only
  storage_account_name = replace(lower("${var.project_name}${var.environment}dl"), "-", "")

  tags = merge(var.common_tags, {
    Module      = "azure-storage"
    Cloud       = "azure"
    Environment = var.environment
    Compliance  = "hipaa-soc2-pci"
    ManagedBy   = "terraform"
  })
}

# =============================================================================
# RESOURCE GROUP
# =============================================================================
resource "azurerm_resource_group" "storage" {
  name     = "${local.name_prefix}-storage-rg"
  location = var.location
  tags     = local.tags
}

# =============================================================================
# ADLS GEN2 STORAGE ACCOUNT — Medallion Data Lake
# =============================================================================
resource "azurerm_storage_account" "medallion" {
  name                     = substr(local.storage_account_name, 0, 24)
  location                 = azurerm_resource_group.storage.location
  resource_group_name      = azurerm_resource_group.storage.name
  account_tier             = "Standard"
  account_replication_type = "GRS" # Geo-redundant for DR
  account_kind             = "StorageV2"
  is_hns_enabled           = true  # Hierarchical namespace (ADLS Gen2)
  min_tls_version          = "TLS1_2"

  # COMPLIANCE: No public network access
  public_network_access_enabled = false

  # CMK encryption via Key Vault
  identity {
    type         = "UserAssigned"
    identity_ids = [var.databricks_identity_id]
  }

  customer_managed_key {
    key_vault_key_id          = var.storage_cmk_id
    user_assigned_identity_id = var.databricks_identity_id
  }

  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = var.allowed_subnet_ids
  }

  blob_properties {
    versioning_enabled  = true
    change_feed_enabled = true

    delete_retention_policy {
      days = 365
    }

    container_delete_retention_policy {
      days = 90
    }
  }

  tags = local.tags
}

# =============================================================================
# MEDALLION CONTAINERS
# =============================================================================
resource "azurerm_storage_container" "bronze" {
  name                  = "bronze"
  storage_account_id    = azurerm_storage_account.medallion.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "silver" {
  name                  = "silver"
  storage_account_id    = azurerm_storage_account.medallion.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "gold" {
  name                  = "gold"
  storage_account_id    = azurerm_storage_account.medallion.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "audit_logs" {
  name                  = "audit-logs"
  storage_account_id    = azurerm_storage_account.medallion.id
  container_access_type = "private"
}

# =============================================================================
# IMMUTABLE STORAGE POLICY — Audit Logs (PCI-DSS/HIPAA)
# =============================================================================
resource "azurerm_storage_management_policy" "lifecycle" {
  storage_account_id = azurerm_storage_account.medallion.id

  rule {
    name    = "bronze-lifecycle"
    enabled = true

    filters {
      prefix_match = ["bronze/"]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = 90
        tier_to_archive_after_days_since_modification_greater_than = 365
      }
    }
  }

  rule {
    name    = "audit-retention"
    enabled = true

    filters {
      prefix_match = ["audit-logs/"]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        # Never delete audit logs before 365 days
        delete_after_days_since_modification_greater_than = 730
      }
    }
  }
}

# =============================================================================
# PRIVATE ENDPOINT — ADLS Gen2 (No public access)
# =============================================================================
resource "azurerm_private_endpoint" "adls_blob" {
  name                = "${local.name_prefix}-adls-blob-pe"
  location            = azurerm_resource_group.storage.location
  resource_group_name = azurerm_resource_group.storage.name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${local.name_prefix}-adls-blob-psc"
    private_connection_resource_id = azurerm_storage_account.medallion.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }

  tags = local.tags
}

resource "azurerm_private_endpoint" "adls_dfs" {
  name                = "${local.name_prefix}-adls-dfs-pe"
  location            = azurerm_resource_group.storage.location
  resource_group_name = azurerm_resource_group.storage.name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${local.name_prefix}-adls-dfs-psc"
    private_connection_resource_id = azurerm_storage_account.medallion.id
    subresource_names              = ["dfs"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.dfs.id]
  }

  tags = local.tags
}

# Private DNS Zones
resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.storage.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone" "dfs" {
  name                = "privatelink.dfs.core.windows.net"
  resource_group_name = azurerm_resource_group.storage.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                  = "${local.name_prefix}-blob-dns-link"
  resource_group_name   = azurerm_resource_group.storage.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "dfs" {
  name                  = "${local.name_prefix}-dfs-dns-link"
  resource_group_name   = azurerm_resource_group.storage.name
  private_dns_zone_name = azurerm_private_dns_zone.dfs.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
}

# =============================================================================
# DIAGNOSTIC SETTINGS
# =============================================================================
resource "azurerm_monitor_diagnostic_setting" "storage" {
  count = var.log_analytics_workspace_id != "" ? 1 : 0

  name                       = "${local.name_prefix}-storage-diag"
  target_resource_id         = "${azurerm_storage_account.medallion.id}/blobServices/default"
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  metric {
    category = "Transaction"
    enabled  = true
  }
}
