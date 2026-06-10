# ─────────────────────────────────────────────────────────────────────────────
# Reusable Module: Kubernetes Cluster
# ─────────────────────────────────────────────────────────────────────────────
# Shared variable interface for provisioning EKS / AKS / GKE clusters
# with consistent security baselines across clouds.
# ─────────────────────────────────────────────────────────────────────────────

variable "cloud_provider" {
  description = "Target cloud: aws, azure, or gcp"
  type        = string
}

variable "name_prefix" {
  description = "Resource naming prefix"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version (e.g., 1.29)"
  type        = string
  default     = "1.29"
}

variable "environment" {
  description = "Environment: dev, staging, prod"
  type        = string
}

variable "node_instance_type" {
  description = "Instance type for worker nodes"
  type        = string
}

variable "node_count" {
  description = "Node count range"
  type = object({
    min = number
    max = number
  })
  default = { min = 2, max = 10 }
}

variable "enable_private_cluster" {
  description = "Disable public API endpoint (HIPAA requirement for prod)"
  type        = bool
  default     = true
}

variable "enable_pod_security" {
  description = "Enable Pod Security Standards (restricted)"
  type        = bool
  default     = true
}

variable "encryption_key_arn" {
  description = "KMS/Key Vault/Cloud KMS key for etcd encryption"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

# ─── Security Baseline ──────────────────────────────────────────────────

locals {
  security_baseline = {
    # Consistent across all 3 clouds
    private_cluster      = var.enable_private_cluster
    encrypt_etcd         = var.encryption_key_arn != ""
    pod_security         = var.enable_pod_security ? "restricted" : "baseline"
    network_policy       = true
    audit_logging        = true
    image_scanning       = true
    workload_identity    = true
    auto_upgrade         = var.environment != "prod" # Auto-upgrade non-prod only
    node_auto_repair     = true
  }
}

output "security_baseline" {
  description = "Computed security baseline for the cluster"
  value       = local.security_baseline
}

output "cluster_config_summary" {
  value = {
    cloud      = var.cloud_provider
    version    = var.kubernetes_version
    node_type  = var.node_instance_type
    node_range = "${var.node_count.min}-${var.node_count.max}"
    private    = var.enable_private_cluster
  }
}
