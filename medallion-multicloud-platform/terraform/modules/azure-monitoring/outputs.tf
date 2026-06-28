# Azure Monitoring Module — Outputs
output "log_analytics_workspace_id" { value = azurerm_log_analytics_workspace.main.workspace_id }
output "log_analytics_workspace_resource_id" { value = azurerm_log_analytics_workspace.main.id }
output "action_group_id" { value = azurerm_monitor_action_group.compliance.id }
output "resource_group_name" { value = azurerm_resource_group.monitoring.name }
