# ─────────────────────────────────────────────────────────────────────────────
# Azure Storage — DICOM Archive, Backup, Audit Logs
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
  }

  backend "azurerm" {
    resource_group_name  = "medcloud-terraform-state-rg"
    storage_account_name = "medcloudtfstate"
    container_name       = "tfstate"
    key                  = "azure/storage/terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

data "terraform_remote_state" "networking" {
  backend = "azurerm"
  config = {
    resource_group_name  = "medcloud-terraform-state-rg"
    storage_account_name = "medcloudtfstate"
    container_name       = "tfstate"
    key                  = "azure/networking/terraform.tfstate"
  }
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  pe_subnet   = data.terraform_remote_state.networking.outputs.private_endpoints_subnet_id
}

resource "azurerm_resource_group" "storage" {
  name     = "${local.name_prefix}-storage-rg"
  location = var.azure_location
  tags     = merge(var.common_tags, { Component = "storage" })
}

# ─── Azure Container Registry (ACR) ─────────────────────────────────────

resource "azurerm_container_registry" "main" {
  name                          = replace("${local.name_prefix}acr", "-", "")
  resource_group_name           = azurerm_resource_group.storage.name
  location                      = azurerm_resource_group.storage.location
  sku                           = var.environment == "prod" ? "Premium" : "Standard"
  admin_enabled                 = false
  public_network_access_enabled = var.environment != "prod"

  dynamic "georeplications" {
    for_each = var.environment == "prod" ? [var.azure_secondary_location] : []
    content {
      location                = georeplications.value
      zone_redundancy_enabled = true
    }
  }

  identity {
    type = "SystemAssigned"
  }

  tags = merge(var.common_tags, { Service = "container-registry" })
}

# ─── Backup Vault ────────────────────────────────────────────────────────

resource "azurerm_data_protection_backup_vault" "main" {
  name                = "${local.name_prefix}-backup-vault"
  resource_group_name = azurerm_resource_group.storage.name
  location            = azurerm_resource_group.storage.location
  datastore_type      = "VaultStore"
  redundancy          = var.environment == "prod" ? "GeoRedundant" : "LocallyRedundant"

  identity {
    type = "SystemAssigned"
  }

  tags = merge(var.common_tags, { Service = "backup" })
}

# ─── Audit Log Storage (immutable for compliance) ────────────────────────

resource "azurerm_storage_account" "audit_logs" {
  name                            = replace("${local.name_prefix}auditlogs", "-", "")
  resource_group_name             = azurerm_resource_group.storage.name
  location                        = azurerm_resource_group.storage.location
  account_tier                    = "Standard"
  account_replication_type        = "GRS"
  min_tls_version                 = "TLS1_2"
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false

  immutability_policy {
    allow_protected_append_writes = true
    state                         = "Unlocked"
    period_since_creation_in_days = var.environment == "prod" ? 2190 : 365 # 6 years for HIPAA
  }

  blob_properties {
    versioning_enabled  = true
    change_feed_enabled = true
    delete_retention_policy {
      days = var.environment == "prod" ? 365 : 30
    }
  }

  identity {
    type = "SystemAssigned"
  }

  tags = merge(var.common_tags, {
    Compliance = "HIPAA"
    DataClass  = "audit-logs"
  })
}

resource "azurerm_storage_container" "audit_logs" {
  name                  = "audit-logs"
  storage_account_name  = azurerm_storage_account.audit_logs.name
  container_access_type = "private"
}

# ─── Outputs ─────────────────────────────────────────────────────────────

output "acr_login_server" {
  value = azurerm_container_registry.main.login_server
}

output "backup_vault_id" {
  value = azurerm_data_protection_backup_vault.main.id
}

output "audit_logs_storage_id" {
  value = azurerm_storage_account.audit_logs.id
}
