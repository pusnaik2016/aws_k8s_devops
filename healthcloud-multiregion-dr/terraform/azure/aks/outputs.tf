output "cluster_name"     { value = azurerm_kubernetes_cluster.dr.name }
output "cluster_fqdn"     { value = azurerm_kubernetes_cluster.dr.fqdn }
output "kube_config_raw"  { value = azurerm_kubernetes_cluster.dr.kube_config_raw; sensitive = true }
output "cluster_identity"  { value = azurerm_kubernetes_cluster.dr.identity[0].principal_id }
output "acr_login_server"  { value = azurerm_container_registry.main.login_server }
output "acr_id"            { value = azurerm_container_registry.main.id }
output "resource_group"    { value = azurerm_resource_group.aks.name }
