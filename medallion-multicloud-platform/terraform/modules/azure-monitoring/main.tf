# =============================================================================
# AZURE MONITORING MODULE — Log Analytics, Diagnostic Settings, Alerts
# =============================================================================

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  tags = merge(var.common_tags, {
    Module = "azure-monitoring"; Cloud = "azure"; Compliance = "hipaa-soc2-pci"; ManagedBy = "terraform"
  })
}

resource "azurerm_resource_group" "monitoring" {
  name     = "${local.name_prefix}-monitoring-rg"
  location = var.location
  tags     = local.tags
}

# =============================================================================
# LOG ANALYTICS WORKSPACE
# =============================================================================
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${local.name_prefix}-law"
  location            = azurerm_resource_group.monitoring.location
  resource_group_name = azurerm_resource_group.monitoring.name
  sku                 = "PerGB2018"
  retention_in_days   = 365 # HIPAA: 1-year minimum

  tags = local.tags
}

# =============================================================================
# ACTION GROUP — Compliance Alerts
# =============================================================================
resource "azurerm_monitor_action_group" "compliance" {
  name                = "${local.name_prefix}-compliance-ag"
  resource_group_name = azurerm_resource_group.monitoring.name
  short_name          = "compliance"

  dynamic "email_receiver" {
    for_each = var.alert_email_addresses
    content {
      name          = "compliance-alert-${email_receiver.key}"
      email_address = email_receiver.value
    }
  }

  tags = local.tags
}

# =============================================================================
# METRIC ALERTS — DR Activation Triggers
# =============================================================================
resource "azurerm_monitor_metric_alert" "storage_availability" {
  name                = "${local.name_prefix}-storage-availability"
  resource_group_name = azurerm_resource_group.monitoring.name
  scopes              = var.monitored_resource_ids
  description         = "Alert when storage account availability drops below threshold"
  severity            = 1
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.Storage/storageAccounts"
    metric_name      = "Availability"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 99.9
  }

  action {
    action_group_id = azurerm_monitor_action_group.compliance.id
  }

  tags = local.tags
}

# =============================================================================
# LOG QUERY ALERTS — Security Monitoring
# =============================================================================
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "keyvault_access" {
  name                = "${local.name_prefix}-kv-unauthorized-access"
  resource_group_name = azurerm_resource_group.monitoring.name
  location            = azurerm_resource_group.monitoring.location
  description         = "Alert on unauthorized Key Vault access attempts"
  severity            = 1
  enabled             = true

  evaluation_frequency = "PT5M"
  window_duration      = "PT5M"
  scopes               = [azurerm_log_analytics_workspace.main.id]

  criteria {
    query = <<-QUERY
      AzureDiagnostics
      | where ResourceProvider == "MICROSOFT.KEYVAULT"
      | where ResultSignature == "Unauthorized" or ResultSignature == "Forbidden"
      | summarize count() by CallerIPAddress, OperationName, bin(TimeGenerated, 5m)
    QUERY

    time_aggregation_method = "Count"
    operator                = "GreaterThan"
    threshold               = 0

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.compliance.id]
  }

  tags = local.tags
}
