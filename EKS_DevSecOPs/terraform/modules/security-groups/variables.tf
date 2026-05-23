# ==============================================================================
# Security Groups Module — Variables
# ==============================================================================
variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH into bastion"
  type        = string
  default     = "0.0.0.0/0"
}

variable "tags" {
  type    = map(string)
  default = {}
}
