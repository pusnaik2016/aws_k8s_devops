variable "vpc_cidr" { type = string }
variable "public_subnet_cidrs" { type = list(string) }
variable "private_subnet_cidrs" { type = list(string) }
variable "availability_zones" { type = list(string) }
variable "cluster_name" { type = string }
variable "environment" { type = string }
variable "prefix" { type = string }
variable "enable_flow_logs" {
  type    = bool
  default = true
}
