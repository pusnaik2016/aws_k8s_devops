variable "name" {
  description = "Name prefix for all Aurora resources"
  type        = string
  default     = "agentcore-memory"
}

variable "vpc_cidr" {
  description = "CIDR block for the Aurora VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "master_username" {
  description = "Master username for Aurora cluster"
  type        = string
  default     = "agentcore_admin"
}

variable "master_password" {
  description = "Master password for Aurora cluster"
  type        = string
  sensitive   = true
}

variable "min_capacity" {
  description = "Minimum ACU for Aurora Serverless v2 (0.5 = ~$43/mo always-on)"
  type        = number
  default     = 0.5
}

variable "max_capacity" {
  description = "Maximum ACU for Aurora Serverless v2"
  type        = number
  default     = 4
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on cluster deletion (true for dev)"
  type        = bool
  default     = true
}
