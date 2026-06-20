output "phi_storage_account_name" { value = azurerm_storage_account.phi.name }
output "phi_storage_account_id"   { value = azurerm_storage_account.phi.id }
output "phi_container_name"       { value = azurerm_storage_container.phi_data.name }
output "audit_container_name"     { value = azurerm_storage_container.audit_logs.name }
