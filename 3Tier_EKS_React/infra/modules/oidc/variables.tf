variable "prefix" { type = string }
variable "environment" { type = string }
variable "github_repositories" { type = list(object({ org = string, repo = string, branch = string })) }
variable "eks_cluster_name" { type = string }
variable "account_id" { type = string }
