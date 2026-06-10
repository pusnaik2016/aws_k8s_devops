# ─────────────────────────────────────────────────────────────────────────────
# Reusable Module: Database
# ─────────────────────────────────────────────────────────────────────────────
# Shared variable interface for consistent database provisioning across
# Aurora (AWS), Cosmos DB (Azure), Cloud SQL (GCP).
# ─────────────────────────────────────────────────────────────────────────────

variable "cloud_provider" {
  description = "Target cloud"
  type        = string
}

variable "name_prefix" {
  description = "Resource naming prefix"
  type        = string
}

variable "environment" {
  description = "Environment"
  type        = string
}

variable "engine" {
  description = "Database engine: postgresql, mongodb, bigtable"
  type        = string
}

variable "instance_class" {
  description = "Instance size"
  type        = string
}

variable "storage_encrypted" {
  description = "Enable CMK encryption (required for HIPAA)"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Backup retention in days"
  type        = number
  default     = 35
}

variable "multi_az" {
  description = "Enable multi-AZ / multi-region (HA)"
  type        = bool
  default     = true
}

variable "private_network_only" {
  description = "Disable public access (HIPAA requirement)"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

# ─── Compliance Defaults ────────────────────────────────────────────────

locals {
  compliance_defaults = {
    encryption_at_rest       = var.storage_encrypted
    encryption_in_transit    = true  # Always TLS
    public_access            = !var.private_network_only
    backup_enabled           = true
    backup_retention         = var.backup_retention_days
    pitr_enabled             = var.environment == "prod"
    audit_logging            = true
    deletion_protection      = var.environment == "prod"
    auto_minor_version_upgrade = var.environment != "prod"
  }
}

output "compliance_defaults" {
  value = local.compliance_defaults
}

output "database_config_summary" {
  value = {
    cloud          = var.cloud_provider
    engine         = var.engine
    size           = var.instance_class
    multi_az       = var.multi_az
    encrypted      = var.storage_encrypted
    private_only   = var.private_network_only
    backup_days    = var.backup_retention_days
  }
}
