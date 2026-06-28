# Azure Security Module — Outputs
output "key_vault_id" { value = azurerm_key_vault.main.id }
output "key_vault_uri" { value = azurerm_key_vault.main.vault_uri }
output "key_vault_name" { value = azurerm_key_vault.main.name }
output "storage_cmk_id" { value = azurerm_key_vault_key.storage_cmk.id }
output "storage_cmk_name" { value = azurerm_key_vault_key.storage_cmk.name }
output "databricks_cmk_id" { value = azurerm_key_vault_key.databricks_cmk.id }
output "databricks_identity_id" { value = azurerm_user_assigned_identity.databricks.id }
output "databricks_identity_principal_id" { value = azurerm_user_assigned_identity.databricks.principal_id }
output "resource_group_name" { value = azurerm_resource_group.security.name }
