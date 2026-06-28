# =============================================================================
# DR STANDBY ENVIRONMENT — Azure Passive Pilot Light
# =============================================================================

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm    = { source = "hashicorp/azurerm"; version = "~> 3.80" }
    databricks = { source = "databricks/databricks"; version = "~> 1.30" }
  }

  backend "azurerm" {
    resource_group_name  = "medallion-tfstate-rg"
    storage_account_name = "medallionplatformtfstate"
    container_name       = "tfstate"
    key                  = "dr-standby/terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}

provider "databricks" {
  alias = "azure_workspace"
  host  = module.azure_databricks.workspace_url
}

# =============================================================================
# MODULE COMPOSITION — Azure DR Site
# =============================================================================

module "azure_monitoring" {
  source       = "../../modules/azure-monitoring"
  project_name = var.project_name
  environment  = var.environment
  location     = var.azure_location
  common_tags  = var.common_tags
}

module "azure_networking" {
  source       = "../../modules/azure-networking"
  project_name = var.project_name
  environment  = var.environment
  location     = var.azure_location
  common_tags  = var.common_tags
  vnet_cidr    = var.azure_vnet_cidr

  log_analytics_workspace_id          = module.azure_monitoring.log_analytics_workspace_id
  log_analytics_workspace_resource_id = module.azure_monitoring.log_analytics_workspace_resource_id
}

module "azure_security" {
  source       = "../../modules/azure-security"
  project_name = var.project_name
  environment  = var.environment
  location     = var.azure_location
  common_tags  = var.common_tags

  allowed_subnet_ids         = [module.azure_networking.databricks_host_subnet_id, module.azure_networking.data_subnet_id]
  log_analytics_workspace_id = module.azure_monitoring.log_analytics_workspace_resource_id
}

module "azure_storage" {
  source       = "../../modules/azure-storage"
  project_name = var.project_name
  environment  = var.environment
  location     = var.azure_location
  common_tags  = var.common_tags

  storage_cmk_id             = module.azure_security.storage_cmk_id
  databricks_identity_id     = module.azure_security.databricks_identity_id
  vnet_id                    = module.azure_networking.vnet_id
  private_endpoint_subnet_id = module.azure_networking.private_endpoints_subnet_id
  allowed_subnet_ids         = [module.azure_networking.databricks_host_subnet_id, module.azure_networking.databricks_container_subnet_id]
  log_analytics_workspace_id = module.azure_monitoring.log_analytics_workspace_resource_id
}

module "azure_databricks" {
  source = "../../modules/azure-databricks"

  providers = {
    databricks.azure_workspace = databricks.azure_workspace
  }

  project_name                            = var.project_name
  environment                             = var.environment
  location                                = var.azure_location
  common_tags                             = var.common_tags
  vnet_id                                 = module.azure_networking.vnet_id
  databricks_host_subnet_name             = "${var.project_name}-${var.environment}-dbx-host"
  databricks_container_subnet_name        = "${var.project_name}-${var.environment}-dbx-container"
  databricks_host_nsg_association_id       = module.azure_networking.databricks_nsg_id
  databricks_container_nsg_association_id  = module.azure_networking.databricks_nsg_id
  private_endpoint_subnet_id              = module.azure_networking.private_endpoints_subnet_id
  storage_account_id                      = module.azure_storage.storage_account_id
  storage_account_name                    = module.azure_storage.storage_account_name
  key_vault_id                            = module.azure_security.key_vault_id
  key_vault_uri                           = module.azure_security.key_vault_uri
  log_analytics_workspace_id              = module.azure_monitoring.log_analytics_workspace_resource_id
}
