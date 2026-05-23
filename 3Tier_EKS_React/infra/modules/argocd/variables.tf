variable "enable" {
  description = "Enable ArgoCD deployment"
  type        = bool
  default     = true
}

variable "chart_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "7.7.5"
}

variable "namespace" {
  description = "Kubernetes namespace for ArgoCD"
  type        = string
  default     = "argocd"
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "gitops_repo_url" {
  description = "Git repository URL for ArgoCD to monitor"
  type        = string
}

variable "gitops_target_revision" {
  description = "Git branch/tag to track"
  type        = string
  default     = "main"
}
