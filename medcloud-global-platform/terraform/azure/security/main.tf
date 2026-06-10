# ─────────────────────────────────────────────────────────────────────────────
# Azure Security — Defender for Cloud, Sentinel SIEM, Policy Assignments
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
    key                  = "azure/security/terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_subscription" "current" {}
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
  law_id      = data.terraform_remote_state.networking.outputs.log_analytics_workspace_id
}

resource "azurerm_resource_group" "security" {
  name     = "${local.name_prefix}-security-rg"
  location = var.azure_location
  tags     = merge(var.common_tags, { Component = "security" })
}

# ─── Defender for Cloud (Security Center) ────────────────────────────────

resource "azurerm_security_center_subscription_pricing" "servers" {
  tier          = "Standard"
  resource_type = "VirtualMachines"
}

resource "azurerm_security_center_subscription_pricing" "containers" {
  tier          = "Standard"
  resource_type = "Containers"
}

resource "azurerm_security_center_subscription_pricing" "storage" {
  tier          = "Standard"
  resource_type = "StorageAccounts"
}

resource "azurerm_security_center_subscription_pricing" "keyvaults" {
  tier          = "Standard"
  resource_type = "KeyVaults"
}

resource "azurerm_security_center_subscription_pricing" "databases" {
  tier          = "Standard"
  resource_type = "CosmosDbs"
}

# ─── Azure Sentinel (SIEM) ──────────────────────────────────────────────

resource "azurerm_sentinel_log_analytics_workspace_onboarding" "main" {
  workspace_id                 = local.law_id
  customer_managed_key_enabled = false
}

# Sentinel data connector — Azure AD (Entra ID)
resource "azurerm_sentinel_data_connector_azure_active_directory" "main" {
  name                       = "${local.name_prefix}-sentinel-aad"
  log_analytics_workspace_id = local.law_id

  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.main]
}

# Sentinel analytics rule — Brute force detection
resource "azurerm_sentinel_alert_rule_scheduled" "brute_force" {
  name                       = "${local.name_prefix}-brute-force-detection"
  log_analytics_workspace_id = local.law_id
  display_name               = "Brute Force Attack Detection"
  severity                   = "High"
  query                      = <<-QUERY
    SigninLogs
    | where ResultType == "50126"
    | summarize FailedAttempts = count() by UserPrincipalName, IPAddress, bin(TimeGenerated, 1h)
    | where FailedAttempts > 10
  QUERY
  query_frequency            = "PT1H"
  query_period               = "PT1H"
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 0
  enabled                    = true

  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.main]
}

# ─── Azure Policy — HIPAA/HITRUST Compliance ────────────────────────────

resource "azurerm_subscription_policy_assignment" "hipaa" {
  name                 = "${local.name_prefix}-hipaa-hitrust"
  subscription_id      = data.azurerm_subscription.current.id
  policy_definition_id = "/providers/Microsoft.Authorization/policySetDefinitions/a169a624-5599-4385-a696-c8d643089fab"
  display_name         = "HIPAA HITRUST 9.2 Compliance"
  description          = "Audit HIPAA HITRUST 9.2 compliance for MedCloud"

  non_compliance_message {
    content = "This resource is not compliant with HIPAA HITRUST 9.2"
  }
}

# ─── Diagnostic Settings ────────────────────────────────────────────────

resource "azurerm_monitor_diagnostic_setting" "subscription" {
  name                       = "${local.name_prefix}-subscription-diagnostics"
  target_resource_id         = data.azurerm_subscription.current.id
  log_analytics_workspace_id = local.law_id

  enabled_log {
    category = "Administrative"
  }

  enabled_log {
    category = "Security"
  }

  enabled_log {
    category = "Alert"
  }
}

output "sentinel_workspace" {
  value = local.law_id
}
