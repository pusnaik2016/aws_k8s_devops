# =============================================================================
# AWS Databricks Module — Outputs
# =============================================================================

output "workspace_id" {
  description = "Databricks workspace ID"
  value       = databricks_mws_workspaces.this.workspace_id
}

output "workspace_url" {
  description = "Databricks workspace URL"
  value       = databricks_mws_workspaces.this.workspace_url
}

output "metastore_id" {
  description = "Unity Catalog metastore ID"
  value       = databricks_metastore.this.id
}

output "catalog_name" {
  description = "Medallion catalog name"
  value       = databricks_catalog.medallion.name
}

output "secret_scope_name" {
  description = "Name of the Databricks secret scope"
  value       = databricks_secret_scope.aws_sm.name
}

output "cluster_policy_id" {
  description = "ID of the compliance cluster policy"
  value       = databricks_cluster_policy.compliant.id
}

output "sql_warehouse_id" {
  description = "ID of the Gold analytics SQL warehouse"
  value       = databricks_sql_endpoint.gold_analytics.id
}
