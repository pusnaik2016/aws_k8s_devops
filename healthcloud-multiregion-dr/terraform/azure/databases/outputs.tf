output "pg_server_fqdn"    { value = azurerm_postgresql_flexible_server.dr.fqdn }
output "pg_server_id"      { value = azurerm_postgresql_flexible_server.dr.id }
output "redis_hostname"    { value = azurerm_redis_cache.dr.hostname }
output "redis_port"        { value = azurerm_redis_cache.dr.ssl_port }
output "redis_primary_key" { value = azurerm_redis_cache.dr.primary_access_key; sensitive = true }
