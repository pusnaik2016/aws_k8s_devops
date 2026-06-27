# ==============================================================================
# Input Variables — Netflix Clone DevSecOps (GitHub Actions + EKS)
# ==============================================================================

# --- General Configuration ---
variable "aws_region" {
  description = "AWS region where all infrastructure resources will be provisioned"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used as prefix for all resource names and tags"
  type        = string
  default     = "netflix-devsecops"
}

variable "key_pair_name" {
  description = "Name of an existing AWS EC2 key pair for SSH access to bastion"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into the bastion host (restrict to your IP!)"
  type        = string
  default     = "0.0.0.0/0"
}

# --- Networking ---
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of AWS Availability Zones for multi-AZ deployment"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway (cost saving) vs one per AZ (HA)"
  type        = bool
  default     = true
}

# --- EKS Configuration ---
variable "eks_cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.29"
}

variable "eks_node_instance_type" {
  description = "EC2 instance type for EKS managed node group workers"
  type        = string
  default     = "t3.medium"
}

variable "eks_node_min_size" {
  description = "Minimum number of nodes in the EKS node group"
  type        = number
  default     = 2
}

variable "eks_node_desired_size" {
  description = "Desired number of nodes in the EKS node group"
  type        = number
  default     = 2
}

variable "eks_node_max_size" {
  description = "Maximum number of nodes in the EKS node group (auto-scaling ceiling)"
  type        = number
  default     = 4
}

# --- Bastion Host ---
variable "bastion_instance_type" {
  description = "EC2 instance type for the bastion host"
  type        = string
  default     = "t3.micro"
}

# --- GitHub OIDC ---
variable "github_org" {
  description = "GitHub organization or username owning the repository"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

# --- Domain & DNS ---
variable "domain_name" {
  description = "Domain name for Route53 hosted zone (e.g., example.com)"
  type        = string
  default     = "example.com"
}

variable "create_route53_zone" {
  description = "Create a new Route53 hosted zone (false = use existing zone)"
  type        = bool
  default     = true
}

# --- WAF Configuration ---
variable "waf_rate_limit" {
  description = "Maximum requests per 5-minute window per IP before WAF blocks"
  type        = number
  default     = 2000
}

# --- Application Configuration ---
variable "app_name" {
  description = "Name of the application"
  type        = string
  default     = "netflix-clone"
}

# --- Compliance & Security Monitoring ---
variable "security_alert_email" {
  description = "Email address to receive security alarm notifications. Leave empty to skip."
  type        = string
  default     = ""
}

variable "waf_block_alarm_threshold" {
  description = "Number of WAF blocked requests in a 5-minute window before alerting"
  type        = number
  default     = 100
}
