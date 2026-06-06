# =============================================================================
# AZURE AD — Centralized User Management
# =============================================================================
# Azure AD is the identity backbone across all three clouds:
#   - Admin Group  → Full platform access (AKS admin, SQL admin, Key Vault)
#   - Dev Group    → Limited K8s access, read-only DB
#   - Compliance   → Audit read-only access across all resources
# =============================================================================

# -----------------------------------------------------------------------------
# Azure AD Groups
# -----------------------------------------------------------------------------
resource "azuread_group" "admins" {
  display_name     = var.azure_ad_admin_group_name
  mail_enabled     = false
  security_enabled = true
  description      = "Platform administrators — full access to AKS, SQL, Key Vault across all clouds"

  owners = [data.azurerm_client_config.current.object_id]
}

resource "azuread_group" "developers" {
  display_name     = var.azure_ad_dev_group_name
  mail_enabled     = false
  security_enabled = true
  description      = "Developers — limited K8s namespace access, read-only database access"

  owners = [data.azurerm_client_config.current.object_id]
}

resource "azuread_group" "compliance" {
  display_name     = var.azure_ad_compliance_group_name
  mail_enabled     = false
  security_enabled = true
  description      = "Compliance auditors — read-only access to audit logs, Config, CloudTrail, BigQuery"

  owners = [data.azurerm_client_config.current.object_id]
}

# -----------------------------------------------------------------------------
# Azure AD Application — Multicloud Service Principal
# -----------------------------------------------------------------------------
resource "azuread_application" "multicloud" {
  display_name = "${local.name_prefix}-service-app"

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph

    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d" # User.Read
      type = "Scope"
    }

    resource_access {
      id   = "df021288-bdef-4463-88db-98f22de89214" # User.Read.All
      type = "Role"
    }

    resource_access {
      id   = "62a82d76-70ea-41e2-9197-370581804d09" # Group.ReadWrite.All
      type = "Role"
    }
  }

  web {
    redirect_uris = ["https://${var.domain_name}/auth/callback"]
  }

  tags = ["multicloud", "clearing-engine", var.environment]
}

resource "azuread_service_principal" "multicloud" {
  client_id                    = azuread_application.multicloud.client_id
  app_role_assignment_required = true

  tags = ["multicloud", "clearing-engine", var.environment]
}

# -----------------------------------------------------------------------------
# Azure AD Application — GitHub Actions OIDC Federation
# -----------------------------------------------------------------------------
resource "azuread_application" "github_actions" {
  display_name = "${local.name_prefix}-github-actions"

  tags = ["github-actions", "cicd", var.environment]
}

resource "azuread_service_principal" "github_actions" {
  client_id = azuread_application.github_actions.client_id
  tags      = ["github-actions", "cicd"]
}

resource "azuread_application_federated_identity_credential" "github_main" {
  application_id = azuread_application.github_actions.id
  display_name   = "github-main-branch"
  description    = "GitHub Actions OIDC for main branch deployments"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:*:ref:refs/heads/main"
}

# -----------------------------------------------------------------------------
# Role Assignments — Admin Group
# -----------------------------------------------------------------------------
resource "azurerm_role_assignment" "admins_contributor" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Contributor"
  principal_id         = azuread_group.admins.object_id
}

resource "azurerm_role_assignment" "admins_keyvault_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = azuread_group.admins.object_id
}

# -----------------------------------------------------------------------------
# Role Assignments — Developer Group
# -----------------------------------------------------------------------------
resource "azurerm_role_assignment" "devs_aks_user" {
  scope                = azurerm_kubernetes_cluster.main.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = azuread_group.developers.object_id
}

resource "azurerm_role_assignment" "devs_keyvault_reader" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azuread_group.developers.object_id
}

# -----------------------------------------------------------------------------
# Role Assignments — Compliance Group
# -----------------------------------------------------------------------------
resource "azurerm_role_assignment" "compliance_reader" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Reader"
  principal_id         = azuread_group.compliance.object_id
}

resource "azurerm_role_assignment" "compliance_log_reader" {
  scope                = azurerm_log_analytics_workspace.main.id
  role_definition_name = "Log Analytics Reader"
  principal_id         = azuread_group.compliance.object_id
}

# -----------------------------------------------------------------------------
# Role Assignments — GitHub Actions Service Principal
# -----------------------------------------------------------------------------
resource "azurerm_role_assignment" "github_contributor" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.github_actions.object_id
}

# -----------------------------------------------------------------------------
# Add Admin Users to Group (if provided)
# -----------------------------------------------------------------------------
data "azuread_user" "admins" {
  count               = length(var.azure_ad_admin_users)
  user_principal_name = var.azure_ad_admin_users[count.index]
}

resource "azuread_group_member" "admins" {
  count            = length(var.azure_ad_admin_users)
  group_object_id  = azuread_group.admins.object_id
  member_object_id = data.azuread_user.admins[count.index].object_id
}
