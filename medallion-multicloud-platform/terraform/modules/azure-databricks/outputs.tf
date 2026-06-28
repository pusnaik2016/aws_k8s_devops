# Azure Databricks Module — Outputs
output "workspace_id" { value = azurerm_databricks_workspace.main.workspace_id }
output "workspace_url" { value = "https://${azurerm_databricks_workspace.main.workspace_url}" }
output "metastore_id" { value = databricks_metastore.this.id }
output "catalog_name" { value = databricks_catalog.medallion.name }
output "secret_scope_name" { value = databricks_secret_scope.azure_kv.name }
output "managed_resource_group_name" { value = azurerm_databricks_workspace.main.managed_resource_group_name }
