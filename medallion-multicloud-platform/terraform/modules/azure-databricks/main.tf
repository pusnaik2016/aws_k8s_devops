# =============================================================================
# AZURE DATABRICKS MODULE — DR Workspace (Passive Pilot Light)
# =============================================================================
# Deployed into VNet injection (no public IP), CMK encryption,
# Unity Catalog with ADLS Gen2 external locations,
# Secret scope backed by Azure Key Vault.
# Cluster runs in standby/paused state — activated on DR failover.
# =============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  tags = merge(var.common_tags, {
    Module      = "azure-databricks"
    Cloud       = "azure"
    Environment = var.environment
    Compliance  = "hipaa-soc2-pci"
    DRRole      = "passive-standby"
    ManagedBy   = "terraform"
  })
}

# =============================================================================
# RESOURCE GROUP
# =============================================================================
resource "azurerm_resource_group" "databricks" {
  name     = "${local.name_prefix}-databricks-rg"
  location = var.location
  tags     = local.tags
}

# =============================================================================
# DATABRICKS WORKSPACE — VNet Injection (No Public IP)
# =============================================================================
resource "azurerm_databricks_workspace" "main" {
  name                          = "${local.name_prefix}-dbx-workspace"
  location                      = azurerm_resource_group.databricks.location
  resource_group_name           = azurerm_resource_group.databricks.name
  sku                           = "premium" # Required for Unity Catalog
  managed_resource_group_name   = "${local.name_prefix}-dbx-managed-rg"
  public_network_access_enabled = false  # COMPLIANCE: No public access

  custom_parameters {
    virtual_network_id                                   = var.vnet_id
    public_subnet_name                                   = var.databricks_host_subnet_name
    private_subnet_name                                  = var.databricks_container_subnet_name
    public_subnet_network_security_group_association_id   = var.databricks_host_nsg_association_id
    private_subnet_network_security_group_association_id  = var.databricks_container_nsg_association_id
    no_public_ip                                         = true # COMPLIANCE: Zero public IP
    storage_account_name                                 = "${replace(local.name_prefix, "-", "")}dbfs"
    storage_account_sku_name                             = "Standard_GRS"
  }

  # CMK encryption for managed services
  customer_managed_key_enabled                        = true
  infrastructure_encryption_enabled                   = true # Double encryption

  tags = local.tags
}

# =============================================================================
# PRIVATE ENDPOINT — Databricks Workspace
# =============================================================================
resource "azurerm_private_endpoint" "databricks" {
  name                = "${local.name_prefix}-dbx-pe"
  location            = azurerm_resource_group.databricks.location
  resource_group_name = azurerm_resource_group.databricks.name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${local.name_prefix}-dbx-psc"
    private_connection_resource_id = azurerm_databricks_workspace.main.id
    subresource_names              = ["databricks_ui_api"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.databricks.id]
  }

  tags = local.tags
}

resource "azurerm_private_dns_zone" "databricks" {
  name                = "privatelink.azuredatabricks.net"
  resource_group_name = azurerm_resource_group.databricks.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "databricks" {
  name                  = "${local.name_prefix}-dbx-dns-link"
  resource_group_name   = azurerm_resource_group.databricks.name
  private_dns_zone_name = azurerm_private_dns_zone.databricks.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
}

# =============================================================================
# UNITY CATALOG — Centralized Data Governance (Azure)
# =============================================================================
resource "databricks_metastore" "this" {
  provider = databricks.azure_workspace
  name     = "${local.name_prefix}-metastore"
  region   = var.location

  storage_root = "abfss://gold@${var.storage_account_name}.dfs.core.windows.net/unity-catalog"

  force_destroy = false
}

resource "databricks_metastore_assignment" "this" {
  provider     = databricks.azure_workspace
  workspace_id = azurerm_databricks_workspace.main.workspace_id
  metastore_id = databricks_metastore.this.id
}

# External locations for ADLS Gen2 medallion containers
resource "databricks_external_location" "bronze" {
  provider        = databricks.azure_workspace
  name            = "bronze-landing"
  url             = "abfss://bronze@${var.storage_account_name}.dfs.core.windows.net/"
  credential_name = databricks_storage_credential.adls.name
  comment         = "DR Bronze layer — ADLS Gen2"

  depends_on = [databricks_metastore_assignment.this]
}

resource "databricks_external_location" "silver" {
  provider        = databricks.azure_workspace
  name            = "silver-curated"
  url             = "abfss://silver@${var.storage_account_name}.dfs.core.windows.net/"
  credential_name = databricks_storage_credential.adls.name
  comment         = "DR Silver layer — ADLS Gen2"

  depends_on = [databricks_metastore_assignment.this]
}

resource "databricks_external_location" "gold" {
  provider        = databricks.azure_workspace
  name            = "gold-aggregated"
  url             = "abfss://gold@${var.storage_account_name}.dfs.core.windows.net/"
  credential_name = databricks_storage_credential.adls.name
  comment         = "DR Gold layer — ADLS Gen2"

  depends_on = [databricks_metastore_assignment.this]
}

# Storage credential for ADLS Gen2 access
resource "databricks_storage_credential" "adls" {
  provider = databricks.azure_workspace
  name     = "${local.name_prefix}-adls-credential"

  azure_managed_identity {
    access_connector_id = azurerm_databricks_access_connector.main.id
  }

  comment = "Managed identity credential for ADLS Gen2 medallion containers"

  depends_on = [databricks_metastore_assignment.this]
}

# Access connector for Unity Catalog
resource "azurerm_databricks_access_connector" "main" {
  name                = "${local.name_prefix}-access-connector"
  location            = azurerm_resource_group.databricks.location
  resource_group_name = azurerm_resource_group.databricks.name

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags
}

# Grant access connector permissions to storage
resource "azurerm_role_assignment" "access_connector_storage" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.main.identity[0].principal_id
}

# =============================================================================
# CATALOG & SCHEMA
# =============================================================================
resource "databricks_catalog" "medallion" {
  provider = databricks.azure_workspace
  name     = "medallion"
  comment  = "DR Medallion architecture data catalog"

  depends_on = [databricks_metastore_assignment.this]
}

resource "databricks_schema" "bronze" {
  provider     = databricks.azure_workspace
  catalog_name = databricks_catalog.medallion.name
  name         = "bronze"
  comment      = "DR Raw ingestion landing zone"
}

resource "databricks_schema" "silver" {
  provider     = databricks.azure_workspace
  catalog_name = databricks_catalog.medallion.name
  name         = "silver"
  comment      = "DR Cleansed and tokenized data"
}

resource "databricks_schema" "gold" {
  provider     = databricks.azure_workspace
  catalog_name = databricks_catalog.medallion.name
  name         = "gold"
  comment      = "DR Business-level aggregates"
}

# =============================================================================
# SECRET SCOPE — Backed by Azure Key Vault
# =============================================================================
resource "databricks_secret_scope" "azure_kv" {
  provider = databricks.azure_workspace
  name     = var.secret_scope_name

  keyvault_metadata {
    resource_id = var.key_vault_id
    dns_name    = var.key_vault_uri
  }
}

# =============================================================================
# DIAGNOSTIC SETTINGS
# =============================================================================
resource "azurerm_monitor_diagnostic_setting" "databricks" {
  count = var.log_analytics_workspace_id != "" ? 1 : 0

  name                       = "${local.name_prefix}-dbx-diag"
  target_resource_id         = azurerm_databricks_workspace.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log { category = "dbfs" }
  enabled_log { category = "clusters" }
  enabled_log { category = "accounts" }
  enabled_log { category = "jobs" }
  enabled_log { category = "notebook" }
  enabled_log { category = "ssh" }
  enabled_log { category = "workspace" }
  enabled_log { category = "secrets" }
  enabled_log { category = "sqlPermissions" }
  enabled_log { category = "unityCatalog" }
}
