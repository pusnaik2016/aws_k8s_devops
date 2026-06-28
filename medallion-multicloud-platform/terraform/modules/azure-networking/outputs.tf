# =============================================================================
# Azure Networking Module — Outputs
# =============================================================================

output "resource_group_name" {
  value = azurerm_resource_group.networking.name
}

output "vnet_id" {
  value = azurerm_virtual_network.main.id
}

output "vnet_name" {
  value = azurerm_virtual_network.main.name
}

output "databricks_host_subnet_id" {
  value = azurerm_subnet.databricks_host.id
}

output "databricks_container_subnet_id" {
  value = azurerm_subnet.databricks_container.id
}

output "data_subnet_id" {
  value = azurerm_subnet.data.id
}

output "private_endpoints_subnet_id" {
  value = azurerm_subnet.private_endpoints.id
}

output "gateway_subnet_id" {
  value = azurerm_subnet.gateway.id
}

output "databricks_nsg_id" {
  value = azurerm_network_security_group.databricks.id
}

output "expressroute_circuit_id" {
  value = var.enable_cross_cloud_transit ? azurerm_express_route_circuit.cross_cloud[0].id : null
}

output "vnet_gateway_id" {
  value = var.enable_cross_cloud_transit ? azurerm_virtual_network_gateway.main[0].id : null
}
