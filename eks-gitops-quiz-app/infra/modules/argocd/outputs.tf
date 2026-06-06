output "server_url_command" {
  description = "Command to port-forward ArgoCD server"
  value       = var.enable ? "kubectl port-forward svc/argocd-server -n ${var.namespace} 8080:443" : "ArgoCD not enabled"
}

output "admin_password_command" {
  description = "Command to retrieve initial admin password"
  value       = var.enable ? "kubectl -n ${var.namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d" : "ArgoCD not enabled"
}
