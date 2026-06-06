# =============================================================================
# AZURE INFRASTRUCTURE MODULE — Hot Standby Site
# =============================================================================

data "azurerm_client_config" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  tenant_id   = data.azurerm_client_config.current.tenant_id

  tags = merge(var.common_tags, {
    Module      = "azure_infra"
    Cloud       = "azure"
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
    Compliance  = "hipaa-sox-gdpr"
  })
}

# -----------------------------------------------------------------------------
# Resource Group
# -----------------------------------------------------------------------------
resource "azurerm_resource_group" "main" {
  name     = "${local.name_prefix}-rg"
  location = var.location

  tags = local.tags
}
