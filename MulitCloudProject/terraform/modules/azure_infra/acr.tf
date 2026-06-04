# =============================================================================
# AZURE ACR — Container Registry (Private Access)
# =============================================================================
# Creates Azure Container Registry with Private Endpoint for AKS.
# Since AKS is a private cluster with no public internet egress, image pulls
# flow through the Private Endpoint in the AKS subnet.
# =============================================================================

# -----------------------------------------------------------------------------
# Azure Container Registry — Premium SKU (required for Private Link)
# -----------------------------------------------------------------------------
resource "azurerm_container_registry" "main" {
  name                = replace("${var.project_name}${var.environment}acr", "-", "")
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Premium" # Required for Private Link, geo-replication, content trust
  admin_enabled       = false     # Use managed identity for auth, not admin credentials

  # Trust policy — enforce signed images (SOX compliance)
  trust_policy {
    enabled = true
  }

  # Quarantine policy — new images quarantined until scanned
  quarantine_policy_enabled = true

  # Retention policy — untagged manifests
  retention_policy {
    days    = 30
    enabled = true
  }

  # Encryption with Customer-Managed Key
  # Note: Requires User-Assigned Managed Identity with Key Vault access
  # encryption {
  #   enabled            = true
  #   key_vault_key_id   = azurerm_key_vault_key.acr.id
  #   identity_client_id = azurerm_user_assigned_identity.acr.client_id
  # }

  # Disable public network access — all access via Private Endpoint
  public_network_access_enabled = false

  # Network rule set — deny by default
  network_rule_set {
    default_action = "Deny"
  }

  tags = merge(var.common_tags, {
    Name      = "${local.name_prefix}-acr"
    Component = "container-registry"
  })
}

# -----------------------------------------------------------------------------
# Private DNS Zone for ACR
# -----------------------------------------------------------------------------
resource "azurerm_private_dns_zone" "acr" {
  name                = "privatelink.azurecr.io"
  resource_group_name = azurerm_resource_group.main.name

  tags = var.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr" {
  name                  = "${local.name_prefix}-acr-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.acr.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false

  tags = var.common_tags
}

# -----------------------------------------------------------------------------
# Private Endpoint for ACR — AKS pulls images via this endpoint
# -----------------------------------------------------------------------------
resource "azurerm_private_endpoint" "acr" {
  name                = "${local.name_prefix}-acr-pe"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.data.id

  private_service_connection {
    name                           = "${local.name_prefix}-acr-psc"
    private_connection_resource_id = azurerm_container_registry.main.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "acr-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.acr.id]
  }

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-acr-private-endpoint"
  })
}

# -----------------------------------------------------------------------------
# AKS ↔ ACR Integration — Allow AKS to pull images
# -----------------------------------------------------------------------------
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                            = azurerm_container_registry.main.id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}

# -----------------------------------------------------------------------------
# Diagnostic Settings — Audit logging for compliance
# -----------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "acr" {
  name                       = "${local.name_prefix}-acr-diag"
  target_resource_id         = azurerm_container_registry.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "ContainerRegistryRepositoryEvents"
  }

  enabled_log {
    category = "ContainerRegistryLoginEvents"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
