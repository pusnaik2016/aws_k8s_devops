# =============================================================================
# AZURE Compliance — Log Analytics, Azure Monitor, Azure Policy, Defender
# =============================================================================

# -----------------------------------------------------------------------------
# Log Analytics Workspace (Central Logging)
# -----------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${local.name_prefix}-law"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 365 # HIPAA/SOX: 1 year online, then archive

  tags = local.tags
}

# Log Analytics Solution — Container Insights
resource "azurerm_log_analytics_solution" "containers" {
  solution_name         = "ContainerInsights"
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  workspace_resource_id = azurerm_log_analytics_workspace.main.id
  workspace_name        = azurerm_log_analytics_workspace.main.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }
}

# -----------------------------------------------------------------------------
# Activity Log Export
# -----------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "activity_log" {
  name                       = "${local.name_prefix}-activity-log"
  target_resource_id         = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "Administrative"
  }

  enabled_log {
    category = "Security"
  }

  enabled_log {
    category = "Alert"
  }

  enabled_log {
    category = "Policy"
  }
}

# -----------------------------------------------------------------------------
# Azure Policy — HIPAA HITRUST
# -----------------------------------------------------------------------------
data "azurerm_policy_set_definition" "hipaa" {
  display_name = "HITRUST/HIPAA"
}

resource "azurerm_resource_group_policy_assignment" "hipaa" {
  count                = var.enable_hipaa ? 1 : 0
  name                 = "${local.name_prefix}-hipaa"
  resource_group_id    = azurerm_resource_group.main.id
  policy_definition_id = data.azurerm_policy_set_definition.hipaa.id
  description          = "HIPAA HITRUST compliance controls"
  display_name         = "HIPAA HITRUST Compliance"

  non_compliance_message {
    content = "This resource does not comply with HIPAA HITRUST requirements."
  }
}

# -----------------------------------------------------------------------------
# Microsoft Defender for Cloud
# -----------------------------------------------------------------------------
resource "azurerm_security_center_subscription_pricing" "sql" {
  tier          = "Standard"
  resource_type = "SqlServers"
}

resource "azurerm_security_center_subscription_pricing" "kubernetes" {
  tier          = "Standard"
  resource_type = "KubernetesService"
}

resource "azurerm_security_center_subscription_pricing" "keyvault" {
  tier          = "Standard"
  resource_type = "KeyVaults"
}

resource "azurerm_security_center_subscription_pricing" "storage" {
  tier          = "Standard"
  resource_type = "StorageAccounts"
}

# Security Contact
resource "azurerm_security_center_contact" "main" {
  name                = "security-contact"
  email               = "security@example.com"
  phone               = "+1-555-0100"
  alert_notifications = true
  alerts_to_admins    = true
}
