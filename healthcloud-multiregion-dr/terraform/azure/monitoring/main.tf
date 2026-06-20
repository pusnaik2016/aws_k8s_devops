# ============================================================================
# Azure Monitoring — Log Analytics, Monitor, Traffic Manager
# ============================================================================

terraform {
  required_version = ">= 1.5"
}

resource "azurerm_resource_group" "monitoring" {
  name     = "${var.project}-${var.environment}-monitoring-rg"
  location = var.azure_region
  tags     = var.common_tags
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.project}-${var.environment}-log-analytics"
  location            = azurerm_resource_group.monitoring.location
  resource_group_name = azurerm_resource_group.monitoring.name
  sku                 = "PerGB2018"
  retention_in_days   = var.environment == "prod" ? 365 : 30

  tags = merge(var.common_tags, {
    Name       = "${var.project}-${var.environment}-log-analytics"
    Compliance = "hipaa-audit"
  })
}

resource "azurerm_monitor_action_group" "critical" {
  name                = "${var.project}-${var.environment}-critical-alerts"
  resource_group_name = azurerm_resource_group.monitoring.name
  short_name          = "hc-critical"

  dynamic "email_receiver" {
    for_each = var.alert_emails
    content {
      name          = "email-${email_receiver.key}"
      email_address = email_receiver.value
    }
  }

  tags = var.common_tags
}

# ──────────────────────────────────────────────────────────────────────────────
# Traffic Manager (DR Failover Endpoint)
# ──────────────────────────────────────────────────────────────────────────────

resource "azurerm_traffic_manager_profile" "dr" {
  name                   = "${var.project}-${var.environment}-tm"
  resource_group_name    = azurerm_resource_group.monitoring.name
  traffic_routing_method = "Priority"

  dns_config {
    relative_name = "${var.project}-${var.environment}"
    ttl           = 60  # Low TTL for fast failover
  }

  monitor_config {
    protocol                     = "HTTPS"
    port                         = 443
    path                         = "/health"
    interval_in_seconds          = 10
    timeout_in_seconds           = 5
    tolerated_number_of_failures = 3
  }

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-traffic-manager"
    Role = "dr-failover"
  })
}

resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                       = "${var.project}-${var.environment}-aks-diag"
  target_resource_id         = var.aks_cluster_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "kube-apiserver"
  }

  enabled_log {
    category = "kube-audit"
  }

  enabled_log {
    category = "kube-controller-manager"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
