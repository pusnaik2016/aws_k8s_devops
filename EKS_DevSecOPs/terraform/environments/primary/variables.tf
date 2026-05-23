# ==============================================================================
# Primary Region — Input Variables
# ==============================================================================

# --- General ---
variable "aws_region" {
  description = "AWS region for primary deployment"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "eks-devsecops"
}

variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string
  default     = "prod"
}

variable "owner_email" {
  description = "Owner email for tagging"
  type        = string
  default     = "devops@example.com"
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "engineering"
}

# --- Networking ---
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "AZs for multi-AZ deployment"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "database_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.201.0/24", "10.0.202.0/24", "10.0.203.0/24"]
}

# --- Access ---
variable "key_pair_name" {
  description = "EC2 key pair for bastion SSH"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH into bastion"
  type        = string
  default     = "0.0.0.0/0"
}

# --- EKS ---
variable "eks_cluster_version" {
  type    = string
  default = "1.31"
}

variable "bootstrap_instance_type" {
  type    = string
  default = "t3.medium"
}

# --- Aurora ---
variable "aurora_engine_version" {
  description = "Aurora MySQL engine version"
  type        = string
  default     = "8.0.mysql_aurora.3.07.1"
}

variable "aurora_instance_class" {
  description = "Aurora instance class"
  type        = string
  default     = "db.r6g.large"
}

variable "aurora_master_username" {
  description = "Aurora master username"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "aurora_master_password" {
  description = "Aurora master password"
  type        = string
  sensitive   = true
}

variable "aurora_global_cluster_id" {
  description = "Aurora Global Database cluster identifier"
  type        = string
  default     = "eks-devsecops-global-aurora"
}

# --- GitHub OIDC ---
variable "github_org" {
  description = "GitHub organization"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

# --- Domain ---
variable "domain_name" {
  description = "Domain for Route53"
  type        = string
  default     = "example.com"
}

# --- Monitoring ---
variable "security_alert_email" {
  description = "Email for security alerts"
  type        = string
  default     = ""
}

variable "waf_rate_limit" {
  type    = number
  default = 2000
}
