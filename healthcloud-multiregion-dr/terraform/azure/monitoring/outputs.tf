output "log_analytics_workspace_id" { value = azurerm_log_analytics_workspace.main.id }
output "log_analytics_workspace_key" { value = azurerm_log_analytics_workspace.main.primary_shared_key; sensitive = true }
output "action_group_id"             { value = azurerm_monitor_action_group.critical.id }
output "traffic_manager_fqdn"       { value = azurerm_traffic_manager_profile.dr.fqdn }
output "traffic_manager_id"         { value = azurerm_traffic_manager_profile.dr.id }
