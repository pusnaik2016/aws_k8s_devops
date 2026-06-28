# Cross-Cloud Transit Module — Outputs
output "vpn_connection_id" { value = aws_vpn_connection.azure_failover.id }
output "tunnel1_address" { value = aws_vpn_connection.azure_failover.tunnel1_address }
output "tunnel2_address" { value = aws_vpn_connection.azure_failover.tunnel2_address }
output "azure_tunnel1_connection_id" { value = azurerm_virtual_network_gateway_connection.aws_tunnel1.id }
output "azure_tunnel2_connection_id" { value = azurerm_virtual_network_gateway_connection.aws_tunnel2.id }
