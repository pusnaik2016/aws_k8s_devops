# Azure Storage Module — Outputs
output "storage_account_id" { value = azurerm_storage_account.medallion.id }
output "storage_account_name" { value = azurerm_storage_account.medallion.name }
output "primary_dfs_endpoint" { value = azurerm_storage_account.medallion.primary_dfs_endpoint }
output "primary_blob_endpoint" { value = azurerm_storage_account.medallion.primary_blob_endpoint }
output "resource_group_name" { value = azurerm_resource_group.storage.name }
