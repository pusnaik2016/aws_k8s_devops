output "resource_group_name"  { value = azurerm_resource_group.networking.name }
output "vnet_id"              { value = azurerm_virtual_network.main.id }
output "vnet_name"            { value = azurerm_virtual_network.main.name }
output "aks_subnet_id"        { value = azurerm_subnet.aks.id }
output "database_subnet_id"   { value = azurerm_subnet.database.id }
output "pe_subnet_id"         { value = azurerm_subnet.private_endpoints.id }
output "vpn_gateway_ip"       { value = azurerm_public_ip.vpn.ip_address }
output "private_dns_zone_name" { value = azurerm_private_dns_zone.internal.name }
