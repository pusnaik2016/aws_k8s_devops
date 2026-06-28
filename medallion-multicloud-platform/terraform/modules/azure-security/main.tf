# =============================================================================
# AZURE SECURITY MODULE — Key Vault, CMKs, Managed Identity
# =============================================================================
# COMPLIANCE:
#   HIPAA  — HSM-backed keys, purge protection, RBAC authorization
#   SOC 2  — Diagnostic audit logging, soft delete retention
#   PCI-DSS — Key rotation policy, network ACL restriction
# =============================================================================

data "azurerm_client_config" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  tenant_id   = data.azurerm_client_config.current.tenant_id

  tags = merge(var.common_tags, {
    Module      = "azure-security"
    Cloud       = "azure"
    Environment = var.environment
    Compliance  = "hipaa-soc2-pci"
    ManagedBy   = "terraform"
  })
}

# =============================================================================
# RESOURCE GROUP
# =============================================================================
resource "azurerm_resource_group" "security" {
  name     = "${local.name_prefix}-security-rg"
  location = var.location

  tags = local.tags
}

# =============================================================================
# KEY VAULT — Premium SKU (HSM-backed) for Compliance
# =============================================================================
resource "azurerm_key_vault" "main" {
  name                        = replace("${local.name_prefix}-kv", "-", "")
  location                    = azurerm_resource_group.security.location
  resource_group_name         = azurerm_resource_group.security.name
  tenant_id                   = local.tenant_id
  sku_name                    = "premium" # HSM-backed for HIPAA/PCI compliance
  enabled_for_disk_encryption = true
  purge_protection_enabled    = true       # COMPLIANCE: Prevent accidental key deletion
  soft_delete_retention_days  = 90
  enable_rbac_authorization   = true       # Use Azure RBAC instead of access policies

  network_acls {
    default_action             = "Deny"     # COMPLIANCE: Deny all by default
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = var.allowed_subnet_ids
  }

  tags = local.tags
}

# =============================================================================
# CMK — ADLS Gen2 Storage Encryption Key
# =============================================================================
resource "azurerm_key_vault_key" "storage_cmk" {
  name         = "${local.name_prefix}-storage-cmk"
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

  depends_on = [azurerm_role_assignment.terraform_keyvault_admin]
}

# =============================================================================
# CMK — Databricks Workspace Encryption Key
# =============================================================================
resource "azurerm_key_vault_key" "databricks_cmk" {
  name         = "${local.name_prefix}-databricks-cmk"
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

  depends_on = [azurerm_role_assignment.terraform_keyvault_admin]
}

# =============================================================================
# SECRETS — DR Connection Strings
# =============================================================================
resource "azurerm_key_vault_secret" "databricks_token" {
  name            = "databricks-access-token"
  value           = "PLACEHOLDER_ROTATED_BY_AZURE_FUNCTION"
  key_vault_id    = azurerm_key_vault.main.id
  content_type    = "text/plain"
  expiration_date = timeadd(timestamp(), "2160h") # 90 days

  depends_on = [azurerm_role_assignment.terraform_keyvault_admin]

  lifecycle {
    ignore_changes = [value, expiration_date]
  }
}

resource "azurerm_key_vault_secret" "tokenization_key" {
  name            = "tokenization-encryption-key"
  value           = "PLACEHOLDER_ROTATED_BY_AZURE_FUNCTION"
  key_vault_id    = azurerm_key_vault.main.id
  content_type    = "text/plain"
  expiration_date = timeadd(timestamp(), "2160h")

  depends_on = [azurerm_role_assignment.terraform_keyvault_admin]

  lifecycle {
    ignore_changes = [value, expiration_date]
  }
}

# =============================================================================
# MANAGED IDENTITY — Databricks Workspace
# =============================================================================
resource "azurerm_user_assigned_identity" "databricks" {
  name                = "${local.name_prefix}-dbx-identity"
  location            = azurerm_resource_group.security.location
  resource_group_name = azurerm_resource_group.security.name

  tags = local.tags
}

# =============================================================================
# RBAC ROLE ASSIGNMENTS
# =============================================================================

# Terraform service principal → Key Vault Admin
resource "azurerm_role_assignment" "terraform_keyvault_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Databricks managed identity → Key Vault Crypto User (for CMK)
resource "azurerm_role_assignment" "databricks_keyvault_crypto" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Crypto User"
  principal_id         = azurerm_user_assigned_identity.databricks.principal_id
}

# Databricks managed identity → Key Vault Secrets User
resource "azurerm_role_assignment" "databricks_keyvault_secrets" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.databricks.principal_id
}

# =============================================================================
# DIAGNOSTIC SETTINGS — Audit Logging
# =============================================================================
resource "azurerm_monitor_diagnostic_setting" "keyvault" {
  count = var.log_analytics_workspace_id != "" ? 1 : 0

  name                       = "${local.name_prefix}-kv-diag"
  target_resource_id         = azurerm_key_vault.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

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

# =============================================================================
# AZURE POLICY — Encryption Enforcement
# =============================================================================
resource "azurerm_resource_group_policy_assignment" "require_encryption" {
  name                 = "${local.name_prefix}-require-encryption"
  resource_group_id    = azurerm_resource_group.security.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/0961003e-5a0a-4549-abde-af6a37f2724d" # Storage accounts should use CMK
  display_name         = "Require CMK encryption on storage accounts"

  non_compliance_message {
    content = "COMPLIANCE VIOLATION: Storage accounts must use customer-managed keys for encryption (HIPAA/PCI-DSS)"
  }
}
