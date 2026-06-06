# =============================================================================
# AZURE MODULE OUTPUTS
# =============================================================================

output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "vnet_id" {
  value = azurerm_virtual_network.main.id
}

output "aks_cluster_endpoint" {
  value     = azurerm_kubernetes_cluster.main.fqdn
  sensitive = true
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.main.name
}

output "sql_server_fqdn" {
  value     = azurerm_mssql_server.main.fully_qualified_domain_name
  sensitive = true
}

output "frontdoor_endpoint" {
  value = azurerm_cdn_frontdoor_endpoint.main.host_name
}

output "vpn_gateway_ip" {
  value = azurerm_public_ip.vpn_gw.ip_address
}

output "key_vault_uri" {
  value = azurerm_key_vault.main.vault_uri
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.main.id
}

output "azure_ad_admin_group_id" {
  value = azuread_group.admins.object_id
}

# --- Container Registry ---
output "acr_login_server" {
  description = "Azure Container Registry login server"
  value       = azurerm_container_registry.main.login_server
}

output "acr_id" {
  description = "Azure Container Registry resource ID"
  value       = azurerm_container_registry.main.id
}

output "acr_private_endpoint_ip" {
  description = "ACR Private Endpoint IP address"
  value       = azurerm_private_endpoint.acr.private_service_connection[0].private_ip_address
}
