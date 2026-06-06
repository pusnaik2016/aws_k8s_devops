# ==============================================================================
# EKS Add-ons — Helm Deployments (ALB Controller + ArgoCD)
# ==============================================================================
# Deploys cluster add-ons into EKS via the Helm and Kubernetes providers:
#
#   1. AWS Load Balancer Controller — Creates ALBs from K8s Ingress resources
#   2. ArgoCD — GitOps continuous delivery engine
#
# Provider Configuration:
#   Both Helm and Kubernetes providers authenticate to the private EKS cluster
#   using the cluster's certificate and token endpoint. Since the EKS API is
#   private-only, Terraform must run from within the VPC (e.g., on the bastion EC2).
# ==============================================================================

# =============================================================================
# Data source — Get EKS cluster auth token for Kubernetes/Helm providers
# =============================================================================
data "aws_eks_cluster_auth" "main" {
  name = aws_eks_cluster.main.name
}

# =============================================================================
# Kubernetes Provider — Points to the private EKS cluster
# =============================================================================
provider "kubernetes" {
  host                   = aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.main.token
}

# =============================================================================
# Helm Provider — Deploys Helm charts to the private EKS cluster
# =============================================================================
provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.main.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.main.token
  }
}

# =============================================================================
# 1. AWS Load Balancer Controller — Manages ALBs from Kubernetes Ingress
# =============================================================================
# The controller watches for Kubernetes Ingress resources with the 'alb'
# ingress class and automatically provisions AWS ALBs with proper target
# groups, listeners, and health checks.
#
# It uses IRSA to assume a scoped IAM role with only ALB management
# permissions (defined in eks-iam.tf).
# =============================================================================
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.1"

  # Cluster name — controller uses this to tag AWS resources
  set {
    name  = "clusterName"
    value = aws_eks_cluster.main.name
  }

  # Service account configuration — annotated with the IRSA IAM role ARN
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

  # AWS region for API calls
  set {
    name  = "region"
    value = var.aws_region
  }

  # VPC ID for ALB placement
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
# ArgoCD monitors the Git manifest repository for changes. When the GitHub
# Actions CD workflow updates deployment.yaml with a new image tag, ArgoCD
# detects the change and automatically syncs the Kubernetes cluster state.
#
# Configuration:
#   - Deployed in the 'argocd' namespace
#   - Server exposed via ALB (using K8s Ingress)
#   - Auto-sync enabled with self-heal and prune
# =============================================================================

# Create ArgoCD namespace
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [aws_eks_node_group.main]
}

# Deploy ArgoCD via Helm
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = "6.7.3"

  # Server configuration — enable insecure mode for ALB termination
  # ALB handles TLS termination, so ArgoCD server runs in HTTP mode
  set {
    name  = "server.extraArgs[0]"
    value = "--insecure"
  }

  # Service type — ClusterIP since ALB handles external access
  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }

  # Resource limits for ArgoCD server
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
