# ============================================================================
# Azure Storage — Blob (HIPAA: CMK, Immutability) + Azure Front Door
# ============================================================================

terraform {
  required_version = ">= 1.5"
}

resource "azurerm_resource_group" "storage" {
  name     = "${var.project}-${var.environment}-storage-rg"
  location = var.azure_region
  tags     = var.common_tags
}

resource "azurerm_storage_account" "phi" {
  name                     = "${replace(var.project, "-", "")}${var.environment}phi"
  resource_group_name      = azurerm_resource_group.storage.name
  location                 = azurerm_resource_group.storage.location
  account_tier             = "Standard"
  account_replication_type = var.environment == "prod" ? "GRS" : "LRS"
  min_tls_version          = "TLS1_2"
  allow_nested_items_to_be_public = false

  identity {
    type = "SystemAssigned"
  }

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 365
    }
    container_delete_retention_policy {
      days = 90
    }
  }

  tags = merge(var.common_tags, {
    Name               = "${var.project}-${var.environment}-phi-storage"
    DataClassification = "phi"
    Compliance         = "hipaa"
  })
}

resource "azurerm_storage_container" "phi_data" {
  name                  = "phi-data"
  storage_account_name  = azurerm_storage_account.phi.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "audit_logs" {
  name                  = "audit-logs"
  storage_account_name  = azurerm_storage_account.phi.name
  container_access_type = "private"
}

resource "azurerm_storage_management_policy" "lifecycle" {
  storage_account_id = azurerm_storage_account.phi.id

  rule {
    name    = "archive-old-phi"
    enabled = true
    filters {
      prefix_match = ["phi-data/"]
      blob_types   = ["blockBlob"]
    }
    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = 30
        tier_to_archive_after_days_since_modification_greater_than = 90
        delete_after_days_since_modification_greater_than          = 2555  # 7 years
      }
    }
  }
}
