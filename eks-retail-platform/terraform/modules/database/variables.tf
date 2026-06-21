# ─────────────────────────────────────────────────────────────────────────────
# Database Module — Variables
# ─────────────────────────────────────────────────────────────────────────────

variable "name_prefix" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "db_subnet_group_name" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "db_scaling" {
  type = object({
    min_acu = number
    max_acu = number
  })
  default = {
    min_acu = 0.5
    max_acu = 16
  }
}

variable "backup_retention_days" {
  type    = number
  default = 35
}

variable "common_tags" {
  type    = map(string)
  default = {}
}
