# ==============================================================================
# EKS Add-ons — Helm Deployments (ALB Controller + ArgoCD + Monitoring)
# ==============================================================================
# Deploys cluster add-ons into EKS via Helm:
#   1. AWS Load Balancer Controller — Creates ALBs from K8s Ingress
#   2. ArgoCD — GitOps continuous delivery engine
#   3. Prometheus — Metrics collection and alerting
#   4. Grafana — Metrics visualization and dashboards
# ==============================================================================

# =============================================================================
# Data source — Get EKS cluster auth token
# =============================================================================
data "aws_eks_cluster_auth" "main" {
  name = aws_eks_cluster.main.name
}

# =============================================================================
# Kubernetes Provider
# =============================================================================
provider "kubernetes" {
  host                   = aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.main.token
}

# =============================================================================
# Helm Provider
# =============================================================================
provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.main.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.main.token
  }
}

# =============================================================================
# 1. AWS Load Balancer Controller
# =============================================================================
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.1"

  set {
    name  = "clusterName"
    value = aws_eks_cluster.main.name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.alb_controller.arn
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = aws_vpc.devsecops_vpc.id
  }

  depends_on = [
    aws_eks_node_group.main,
    aws_iam_role_policy_attachment.alb_controller,
  ]
}

# =============================================================================
# 2. ArgoCD — GitOps Continuous Delivery Engine
# =============================================================================
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [aws_eks_node_group.main]
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = "6.7.3"

  set {
    name  = "server.extraArgs[0]"
    value = "--insecure"
  }

  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }

  set {
    name  = "server.resources.requests.memory"
    value = "256Mi"
  }

  set {
    name  = "server.resources.requests.cpu"
    value = "250m"
  }

  depends_on = [
    aws_eks_node_group.main,
    kubernetes_namespace.argocd,
  ]
}

# =============================================================================
# 3. Prometheus — Metrics Collection & Alerting
# =============================================================================
# Prometheus monitors EKS cluster health, pod metrics, and application
# performance. Deployed via the kube-prometheus-stack Helm chart which
# includes Prometheus Operator, Alertmanager, and default alert rules.
# =============================================================================
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [aws_eks_node_group.main]
}

resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "58.2.2"

  # Prometheus server configuration
  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "7d"
  }

  set {
    name  = "prometheus.prometheusSpec.resources.requests.memory"
    value = "512Mi"
  }

  set {
    name  = "prometheus.prometheusSpec.resources.requests.cpu"
    value = "250m"
  }

  set {
    name  = "prometheus.prometheusSpec.resources.limits.memory"
    value = "1Gi"
  }

  # Alertmanager configuration
  set {
    name  = "alertmanager.enabled"
    value = "true"
  }

  set {
    name  = "alertmanager.alertmanagerSpec.resources.requests.memory"
    value = "128Mi"
  }

  # Grafana is deployed separately for more control
  set {
    name  = "grafana.enabled"
    value = "false"
  }

  # Node exporter for host-level metrics
  set {
    name  = "nodeExporter.enabled"
    value = "true"
  }

  # Enable kube-state-metrics for Kubernetes object metrics
  set {
    name  = "kubeStateMetrics.enabled"
    value = "true"
  }

  # Service monitor for the Netflix Clone app
  set {
    name  = "prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues"
    value = "false"
  }

  depends_on = [
    aws_eks_node_group.main,
    kubernetes_namespace.monitoring,
  ]
}

# =============================================================================
# 4. Grafana — Metrics Visualization & Dashboards
# =============================================================================
# Grafana provides visualization dashboards for Prometheus metrics.
# Pre-configured with Prometheus as a data source.
# =============================================================================
resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "7.3.7"

  # Admin credentials (change in production!)
  set {
    name  = "adminUser"
    value = "admin"
  }

  set_sensitive {
    name  = "adminPassword"
    value = "DevSecOps2024!"
  }

  # Service type — ClusterIP (access via port-forward or ALB Ingress)
  set {
    name  = "service.type"
    value = "ClusterIP"
  }

  # Resources
  set {
    name  = "resources.requests.memory"
    value = "256Mi"
  }

  set {
    name  = "resources.requests.cpu"
    value = "100m"
  }

  # Prometheus data source — auto-configured
  set {
    name  = "datasources.datasources\\.yaml.apiVersion"
    value = "1"
  }

  set {
    name  = "datasources.datasources\\.yaml.datasources[0].name"
    value = "Prometheus"
  }

  set {
    name  = "datasources.datasources\\.yaml.datasources[0].type"
    value = "prometheus"
  }

  set {
    name  = "datasources.datasources\\.yaml.datasources[0].url"
    value = "http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090"
  }

  set {
    name  = "datasources.datasources\\.yaml.datasources[0].access"
    value = "proxy"
  }

  set {
    name  = "datasources.datasources\\.yaml.datasources[0].isDefault"
    value = "true"
  }

  # Pre-install Kubernetes dashboards
  set {
    name  = "dashboardProviders.dashboardproviders\\.yaml.apiVersion"
    value = "1"
  }

  set {
    name  = "dashboardProviders.dashboardproviders\\.yaml.providers[0].name"
    value = "default"
  }

  set {
    name  = "dashboardProviders.dashboardproviders\\.yaml.providers[0].orgId"
    value = "1"
  }

  set {
    name  = "dashboardProviders.dashboardproviders\\.yaml.providers[0].type"
    value = "file"
  }

  set {
    name  = "dashboardProviders.dashboardproviders\\.yaml.providers[0].disableDeletion"
    value = "false"
  }

  set {
    name  = "dashboardProviders.dashboardproviders\\.yaml.providers[0].options.path"
    value = "/var/lib/grafana/dashboards/default"
  }

  # Import popular Kubernetes dashboards from grafana.com
  set {
    name  = "dashboards.default.kubernetes-cluster.gnetId"
    value = "7249"
  }

  set {
    name  = "dashboards.default.kubernetes-cluster.datasource"
    value = "Prometheus"
  }

  set {
    name  = "dashboards.default.kubernetes-pods.gnetId"
    value = "6417"
  }

  set {
    name  = "dashboards.default.kubernetes-pods.datasource"
    value = "Prometheus"
  }

  depends_on = [
    helm_release.prometheus,
    kubernetes_namespace.monitoring,
  ]
}
