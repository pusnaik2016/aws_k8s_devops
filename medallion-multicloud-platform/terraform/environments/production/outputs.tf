# Production Environment — Outputs
output "aws_vpc_id" { value = module.aws_networking.vpc_id }
output "databricks_workspace_url" { value = module.aws_databricks.workspace_url }
output "databricks_metastore_id" { value = module.aws_databricks.metastore_id }
output "bronze_bucket" { value = module.aws_storage.bronze_bucket_name }
output "silver_bucket" { value = module.aws_storage.silver_bucket_name }
output "gold_bucket" { value = module.aws_storage.gold_bucket_name }
output "audit_bucket" { value = module.aws_storage.audit_log_bucket_name }
output "github_deployer_role_arn" { value = module.aws_security.github_deployer_role_arn }
output "compliance_dashboard" { value = module.aws_monitoring.dashboard_name }
