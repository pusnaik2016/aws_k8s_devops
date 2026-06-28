# DR Standby Environment — Outputs
output "azure_vnet_id" { value = module.azure_networking.vnet_id }
output "databricks_workspace_url" { value = module.azure_databricks.workspace_url }
output "key_vault_name" { value = module.azure_security.key_vault_name }
output "storage_account_name" { value = module.azure_storage.storage_account_name }
