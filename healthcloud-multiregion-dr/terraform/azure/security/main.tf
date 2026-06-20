# ============================================================================
# Azure Security — Key Vault, Defender, Sentinel, Azure Policy
# ============================================================================

terraform {
  required_version = ">= 1.5"
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "security" {
  name     = "${var.project}-${var.environment}-security-rg"
  location = var.azure_region
  tags     = var.common_tags
}

resource "azurerm_key_vault" "main" {
  name                        = "${var.project}-${var.environment}-kv"
  location                    = azurerm_resource_group.security.location
  resource_group_name         = azurerm_resource_group.security.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "premium"
  purge_protection_enabled    = true
  soft_delete_retention_days  = 90
  enable_rbac_authorization   = true

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  tags = merge(var.common_tags, {
    Name       = "${var.project}-${var.environment}-kv"
    Compliance = "hipaa"
  })
}

resource "azurerm_security_center_subscription_pricing" "vms" {
  tier          = "Standard"
  resource_type = "VirtualMachines"
}

resource "azurerm_security_center_subscription_pricing" "containers" {
  tier          = "Standard"
  resource_type = "Containers"
}

resource "azurerm_security_center_subscription_pricing" "keyvaults" {
  tier          = "Standard"
  resource_type = "KeyVaults"
}

resource "azurerm_security_center_subscription_pricing" "storage" {
  tier          = "Standard"
  resource_type = "StorageAccounts"
}
