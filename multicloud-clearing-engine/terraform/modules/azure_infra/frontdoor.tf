# =============================================================================
# AZURE Front Door Premium + WAF
# =============================================================================

resource "azurerm_cdn_frontdoor_profile" "main" {
  name                = "${local.name_prefix}-frontdoor"
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "Premium_AzureFrontDoor"

  tags = local.tags
}

resource "azurerm_cdn_frontdoor_endpoint" "main" {
  name                     = "${local.name_prefix}-endpoint"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id

  tags = local.tags
}

# WAF Policy
resource "azurerm_cdn_frontdoor_firewall_policy" "main" {
  name                = replace("${local.name_prefix}-waf", "-", "")
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "Premium_AzureFrontDoor"
  enabled             = true
  mode                = "Prevention"

  managed_rule {
    type    = "Microsoft_DefaultRuleSet"
    version = "2.1"
    action  = "Block"
  }

  managed_rule {
    type    = "Microsoft_BotManagerRuleSet"
    version = "1.0"
    action  = "Block"
  }

  custom_rule {
    name                           = "RateLimitRule"
    enabled                        = true
    priority                       = 100
    rate_limit_duration_in_minutes = 1
    rate_limit_threshold           = 1000
    type                           = "RateLimitRule"
    action                         = "Block"

    match_condition {
      match_variable     = "RemoteAddr"
      operator           = "IPMatch"
      negation_condition = true
      match_values       = ["0.0.0.0/0"] # Match all; rate limiting applies globally
    }
  }

  tags = local.tags
}

# Security Policy — Link WAF to Endpoint
resource "azurerm_cdn_frontdoor_security_policy" "main" {
  name                     = "${local.name_prefix}-sec-policy"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.main.id

      association {
        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_endpoint.main.id
        }
        patterns_to_match = ["/*"]
      }
    }
  }
}

# Origin Group
resource "azurerm_cdn_frontdoor_origin_group" "main" {
  name                     = "${local.name_prefix}-origin-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id
  session_affinity_enabled = false

  health_probe {
    path                = "/health"
    protocol            = "Https"
    interval_in_seconds = 30
    request_type        = "GET"
  }

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 2
    additional_latency_in_milliseconds = 50
  }
}

# Origin — AKS Ingress
resource "azurerm_cdn_frontdoor_origin" "aks" {
  name                          = "${local.name_prefix}-aks-origin"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.main.id
  enabled                       = true

  host_name          = "aks-ingress.${var.domain_name}"
  http_port          = 80
  https_port         = 443
  origin_host_header = "aks-ingress.${var.domain_name}"
  priority           = 1
  weight             = 1000

  certificate_name_check_enabled = true
}

# Route
resource "azurerm_cdn_frontdoor_route" "main" {
  name                          = "${local.name_prefix}-default-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.main.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.main.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.aks.id]

  supported_protocols    = ["Http", "Https"]
  patterns_to_match      = ["/*"]
  forwarding_protocol    = "HttpsOnly"
  https_redirect_enabled = true
  link_to_default_domain = true
}

# Diagnostic Settings
resource "azurerm_monitor_diagnostic_setting" "frontdoor" {
  name                       = "${local.name_prefix}-frontdoor-diag"
  target_resource_id         = azurerm_cdn_frontdoor_profile.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "FrontDoorAccessLog"
  }

  enabled_log {
    category = "FrontDoorWebApplicationFirewallLog"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
