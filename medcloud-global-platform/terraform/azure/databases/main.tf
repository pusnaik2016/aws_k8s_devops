# ─────────────────────────────────────────────────────────────────────────────
# Azure Databases — Cosmos DB (Global Patient Profiles) + Azure Cache for Redis
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
    key                  = "azure/databases/terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

# ─── Data Sources ────────────────────────────────────────────────────────────

data "terraform_remote_state" "networking" {
  backend = "azurerm"
  config = {
    resource_group_name  = "medcloud-terraform-state-rg"
    storage_account_name = "medcloudtfstate"
    container_name       = "tfstate"
    key                  = "azure/networking/terraform.tfstate"
  }
}

data "azurerm_client_config" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  location    = var.azure_location
  pe_subnet   = data.terraform_remote_state.networking.outputs.private_endpoints_subnet_id
  vnet_id     = data.terraform_remote_state.networking.outputs.vnet_id
}

# ─── Resource Group ──────────────────────────────────────────────────────────

resource "azurerm_resource_group" "databases" {
  name     = "${local.name_prefix}-databases-rg"
  location = local.location
  tags     = merge(var.common_tags, { Component = "databases" })
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Cosmos DB — Global Patient Metadata (MongoDB API)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

resource "azurerm_cosmosdb_account" "main" {
  name                = "${local.name_prefix}-cosmosdb"
  location            = azurerm_resource_group.databases.location
  resource_group_name = azurerm_resource_group.databases.name
  offer_type          = "Standard"
  kind                = "MongoDB"
  mongo_server_version = "4.2"

  # HIPAA: Disable public access — private endpoints only
  public_network_access_enabled     = false
  is_virtual_network_filter_enabled = true
  network_acl_bypass_for_azure_services = true

  # Session consistency (best for user-facing apps)
  consistency_policy {
    consistency_level       = "Session"
    max_interval_in_seconds = 5
    max_staleness_prefix    = 100
  }

  # Multi-region writes for global availability
  geo_location {
    location          = local.location
    failover_priority = 0
    zone_redundant    = var.environment == "prod"
  }

  dynamic "geo_location" {
    for_each = var.environment == "prod" ? [1] : []
    content {
      location          = var.azure_secondary_location
      failover_priority = 1
      zone_redundant    = true
    }
  }

  # HIPAA: CMK encryption
  key_vault_key_id = var.environment == "prod" ? azurerm_key_vault_key.cosmosdb[0].id : null

  # Backup policy
  backup {
    type                = "Continuous"
    tier                = var.environment == "prod" ? "Continuous30Days" : "Continuous7Days"
  }

  # Analytics (Synapse Link)
  analytical_storage_enabled = true

  capabilities {
    name = "EnableMongo"
  }

  capabilities {
    name = "EnableAggregationPipeline"
  }

  tags = merge(var.common_tags, {
    Compliance = "HIPAA,GDPR"
    DataClass  = "PHI"
  })
}

# Cosmos DB Database
resource "azurerm_cosmosdb_mongo_database" "patient_profiles" {
  name                = "patient-profiles"
  resource_group_name = azurerm_resource_group.databases.name
  account_name        = azurerm_cosmosdb_account.main.name
}

# Cosmos DB Collections
resource "azurerm_cosmosdb_mongo_collection" "patients" {
  name                = "patients"
  resource_group_name = azurerm_resource_group.databases.name
  account_name        = azurerm_cosmosdb_account.main.name
  database_name       = azurerm_cosmosdb_mongo_database.patient_profiles.name
  shard_key           = "region"

  autoscale_settings {
    max_throughput = var.environment == "prod" ? 10000 : 4000
  }

  index {
    keys   = ["_id"]
    unique = true
  }

  index {
    keys = ["patient_id"]
    unique = true
  }

  index {
    keys = ["region", "created_at"]
  }
}

resource "azurerm_cosmosdb_mongo_collection" "medical_records" {
  name                = "medical-records"
  resource_group_name = azurerm_resource_group.databases.name
  account_name        = azurerm_cosmosdb_account.main.name
  database_name       = azurerm_cosmosdb_mongo_database.patient_profiles.name
  shard_key           = "patient_id"

  autoscale_settings {
    max_throughput = var.environment == "prod" ? 20000 : 4000
  }

  index {
    keys   = ["_id"]
    unique = true
  }

  index {
    keys = ["patient_id", "record_type"]
  }

  # TTL for GDPR right-to-erasure
  default_ttl_seconds = -1 # Disabled by default, set per-document
}

# Private endpoint for Cosmos DB
resource "azurerm_private_endpoint" "cosmosdb" {
  name                = "${local.name_prefix}-cosmosdb-pe"
  location            = azurerm_resource_group.databases.location
  resource_group_name = azurerm_resource_group.databases.name
  subnet_id           = local.pe_subnet

  private_service_connection {
    name                           = "${local.name_prefix}-cosmosdb-psc"
    private_connection_resource_id = azurerm_cosmosdb_account.main.id
    subresource_names              = ["MongoDB"]
    is_manual_connection           = false
  }

  tags = var.common_tags
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Key Vault (for CMK encryption keys)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

resource "azurerm_key_vault" "main" {
  name                       = "${local.name_prefix}-kv"
  location                   = azurerm_resource_group.databases.location
  resource_group_name        = azurerm_resource_group.databases.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "premium" # HSM-backed keys for HIPAA
  purge_protection_enabled   = true
  soft_delete_retention_days = 90

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  tags = merge(var.common_tags, { Compliance = "HIPAA" })
}

resource "azurerm_key_vault_access_policy" "current" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  key_permissions = [
    "Create", "Delete", "Get", "List", "Purge", "Recover",
    "UnwrapKey", "WrapKey", "GetRotationPolicy",
  ]
  secret_permissions = ["Get", "Set", "Delete", "List"]
}

resource "azurerm_key_vault_key" "cosmosdb" {
  count = var.environment == "prod" ? 1 : 0

  name         = "${local.name_prefix}-cosmosdb-cmk"
  key_vault_id = azurerm_key_vault.main.id
  key_type     = "RSA"
  key_size     = 3072

  key_opts = ["unwrapKey", "wrapKey"]

  rotation_policy {
    automatic {
      time_before_expiry = "P30D"
    }
    expire_after         = "P365D"
    notify_before_expiry = "P30D"
  }

  depends_on = [azurerm_key_vault_access_policy.current]
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Azure Cache for Redis
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

resource "azurerm_redis_cache" "main" {
  name                = "${local.name_prefix}-redis"
  location            = azurerm_resource_group.databases.location
  resource_group_name = azurerm_resource_group.databases.name
  capacity            = var.environment == "prod" ? 2 : 0
  family              = var.environment == "prod" ? "P" : "C"
  sku_name            = var.environment == "prod" ? "Premium" : "Standard"
  enable_non_ssl_port = false
  minimum_tls_version = "1.2"

  redis_configuration {
    maxmemory_policy = "allkeys-lru"
  }

  tags = var.common_tags
}

# ─── Outputs ─────────────────────────────────────────────────────────────────

output "cosmosdb_endpoint" {
  value = azurerm_cosmosdb_account.main.endpoint
}

output "cosmosdb_connection_strings" {
  value     = azurerm_cosmosdb_account.main.connection_strings
  sensitive = true
}

output "redis_hostname" {
  value = azurerm_redis_cache.main.hostname
}

output "key_vault_id" {
  value = azurerm_key_vault.main.id
}

output "key_vault_uri" {
  value = azurerm_key_vault.main.vault_uri
}
