# =============================================================================
# ROOT VARIABLES — Production Environment
# Global Healthcare & Financial Transaction Clearing Engine
# =============================================================================

# -----------------------------------------------------------------------------
# Global Project Settings
# -----------------------------------------------------------------------------
variable "project_name" {
  description = "Project name used for resource naming and tagging across all clouds"
  type        = string
  default     = "multicloud-clearing-engine"
}

variable "environment" {
  description = "Deployment environment (production, staging, dev)"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["production", "staging", "dev"], var.environment)
    error_message = "Environment must be one of: production, staging, dev."
  }
}

variable "domain_name" {
  description = "Primary domain for the clearing engine (used in Route53, Front Door, Cloud DNS)"
  type        = string
  default     = "clearing-engine.example.com"
}

# -----------------------------------------------------------------------------
# Compliance Flags
# -----------------------------------------------------------------------------
variable "enable_hipaa" {
  description = "Enable HIPAA compliance controls (encryption, audit logging, access controls)"
  type        = bool
  default     = true
}

variable "enable_sox" {
  description = "Enable SOX compliance controls (immutable audit trails, separation of duties)"
  type        = bool
  default     = true
}

variable "enable_gdpr" {
  description = "Enable GDPR compliance controls (data sovereignty, PII tokenization, right to erasure)"
  type        = bool
  default     = true
}

variable "enable_pci_dss" {
  description = "Enable PCI-DSS compliance controls (WAF rules, access logging, encryption, network segmentation)"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# AWS Settings
# -----------------------------------------------------------------------------
variable "aws_region" {
  description = "AWS primary region for the active site"
  type        = string
  default     = "us-east-1"
}

variable "aws_vpc_cidr" {
  description = "CIDR block for the AWS VPC (must not overlap with Azure/GCP)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "aws_eks_cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.30"
}

variable "aws_eks_node_instance_type" {
  description = "EC2 instance type for EKS managed node groups"
  type        = string
  default     = "t3.xlarge"
}

variable "aws_eks_node_min" {
  description = "Minimum number of EKS worker nodes"
  type        = number
  default     = 3
}

variable "aws_eks_node_max" {
  description = "Maximum number of EKS worker nodes"
  type        = number
  default     = 10
}

variable "aws_aurora_instance_class" {
  description = "Instance class for Aurora PostgreSQL writer"
  type        = string
  default     = "db.r6g.xlarge"
}

variable "aws_aurora_reader_instance_class" {
  description = "Instance class for Aurora PostgreSQL reader"
  type        = string
  default     = "db.r6g.large"
}

variable "aws_elasticache_node_type" {
  description = "Node type for ElastiCache Redis cluster"
  type        = string
  default     = "cache.r6g.large"
}

# -----------------------------------------------------------------------------
# Azure Settings
# -----------------------------------------------------------------------------
variable "azure_region" {
  description = "Azure region for the hot standby site"
  type        = string
  default     = "eastus"
}

variable "azure_subscription_id" {
  description = "Azure subscription ID"
  type        = string
  sensitive   = true
}

variable "azure_tenant_id" {
  description = "Azure AD tenant ID for identity management"
  type        = string
  sensitive   = true
}

variable "azure_vnet_cidr" {
  description = "Address space for the Azure VNet (must not overlap with AWS/GCP)"
  type        = string
  default     = "10.1.0.0/16"
}

variable "azure_aks_node_vm_size" {
  description = "VM size for AKS node pools"
  type        = string
  default     = "Standard_D4s_v5"
}

variable "azure_aks_system_node_min" {
  description = "Minimum nodes for AKS system pool"
  type        = number
  default     = 2
}

variable "azure_aks_system_node_max" {
  description = "Maximum nodes for AKS system pool"
  type        = number
  default     = 5
}

variable "azure_aks_user_node_min" {
  description = "Minimum nodes for AKS user pool"
  type        = number
  default     = 2
}

variable "azure_aks_user_node_max" {
  description = "Maximum nodes for AKS user pool"
  type        = number
  default     = 10
}

variable "azure_sql_sku" {
  description = "SKU for Azure SQL Database Hyperscale"
  type        = string
  default     = "HS_Gen5_4"
}

# -----------------------------------------------------------------------------
# GCP Settings
# -----------------------------------------------------------------------------
variable "gcp_project_id" {
  description = "GCP project ID for the compliance and analytics layer"
  type        = string
  default     = "enterprise-compliance-analytics"
}

variable "gcp_region" {
  description = "GCP region for the compliance layer"
  type        = string
  default     = "us-central1"
}

variable "gcp_vpc_cidr" {
  description = "Primary subnet CIDR for GCP VPC (must not overlap with AWS/Azure)"
  type        = string
  default     = "10.2.0.0/16"
}

variable "gcp_gke_node_machine_type" {
  description = "Machine type for GKE node pool"
  type        = string
  default     = "e2-standard-4"
}

variable "gcp_gke_node_min" {
  description = "Minimum nodes in GKE node pool"
  type        = number
  default     = 2
}

variable "gcp_gke_node_max" {
  description = "Maximum nodes in GKE node pool"
  type        = number
  default     = 8
}

variable "gcp_alloydb_cpu_count" {
  description = "CPU count for AlloyDB primary instance"
  type        = number
  default     = 4
}

# -----------------------------------------------------------------------------
# Cross-Cloud VPN Settings
# -----------------------------------------------------------------------------
variable "vpn_shared_secret_aws_azure" {
  description = "Pre-shared key for AWS ↔ Azure VPN tunnel"
  type        = string
  sensitive   = true
}

variable "vpn_shared_secret_aws_gcp" {
  description = "Pre-shared key for AWS ↔ GCP VPN tunnel"
  type        = string
  sensitive   = true
}

variable "vpn_shared_secret_azure_gcp" {
  description = "Pre-shared key for Azure ↔ GCP VPN tunnel"
  type        = string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Azure AD User Management
# -----------------------------------------------------------------------------
variable "azure_ad_admin_group_name" {
  description = "Azure AD group name for platform administrators"
  type        = string
  default     = "MultiCloud-Platform-Admins"
}

variable "azure_ad_dev_group_name" {
  description = "Azure AD group name for developers"
  type        = string
  default     = "MultiCloud-Developers"
}

variable "azure_ad_compliance_group_name" {
  description = "Azure AD group name for compliance auditors"
  type        = string
  default     = "MultiCloud-Compliance-Auditors"
}

variable "azure_ad_admin_users" {
  description = "List of admin user principal names to add to the admin group"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# Tags / Labels (applied uniformly across all clouds)
# -----------------------------------------------------------------------------
variable "common_tags" {
  description = "Common tags to apply to all resources across all clouds"
  type        = map(string)
  default = {
    DataClassification = "PHI-PII-Confidential"
    CostCenter         = "healthcare-finops"
    Owner              = "platform-engineering"
  }
}
