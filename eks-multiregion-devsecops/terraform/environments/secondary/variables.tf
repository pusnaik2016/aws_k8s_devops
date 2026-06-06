# ==============================================================================
# Secondary Region — Variables (ap-south-1)
# ==============================================================================

variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "project_name" {
  type    = string
  default = "eks-devsecops"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "owner_email" {
  type    = string
  default = "devops@example.com"
}

variable "cost_center" {
  type    = string
  default = "engineering"
}

variable "vpc_cidr" {
  type    = string
  default = "10.1.0.0/16"  # Different CIDR from primary
}

variable "availability_zones" {
  type    = list(string)
  default = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.1.101.0/24", "10.1.102.0/24", "10.1.103.0/24"]
}

variable "database_subnet_cidrs" {
  type    = list(string)
  default = ["10.1.201.0/24", "10.1.202.0/24", "10.1.203.0/24"]
}

variable "key_pair_name" {
  type = string
}

variable "allowed_ssh_cidr" {
  type    = string
  default = "0.0.0.0/0"
}

variable "eks_cluster_version" {
  type    = string
  default = "1.31"
}

variable "aurora_global_cluster_id" {
  description = "Aurora Global Cluster ID from primary region"
  type        = string
  default     = "eks-devsecops-global-aurora"
}

variable "aurora_engine_version" {
  type    = string
  default = "8.0.mysql_aurora.3.07.1"
}

variable "aurora_instance_class" {
  type    = string
  default = "db.r6g.large"
}

variable "security_alert_email" {
  type    = string
  default = ""
}

variable "github_org" {
  description = "GitHub organization for ArgoCD repo source"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name for ArgoCD repo source"
  type        = string
}
