# ==============================================================================
# Secondary Region — Main Orchestration (ap-south-1)
# ==============================================================================

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Region      = var.aws_region
    ManagedBy   = "terraform"
  }
}

# =============================================================================
# Modules — Same structure as primary
# =============================================================================
module "kms" {
  source       = "../../modules/kms"
  project_name = var.project_name
  aws_region   = var.aws_region
  account_id   = local.account_id
  tags         = local.common_tags
}

module "vpc" {
  source                = "../../modules/vpc"
  project_name          = var.project_name
  aws_region            = var.aws_region
  vpc_cidr              = var.vpc_cidr
  availability_zones    = var.availability_zones
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  database_subnet_cidrs = var.database_subnet_cidrs
  single_nat_gateway    = false
  kms_key_arn           = module.kms.eks_key_arn
  tags                  = local.common_tags
}

module "security_groups" {
  source           = "../../modules/security-groups"
  project_name     = var.project_name
  vpc_id           = module.vpc.vpc_id
  vpc_cidr         = var.vpc_cidr
  allowed_ssh_cidr = var.allowed_ssh_cidr
  tags             = local.common_tags
}

module "eks" {
  source                  = "../../modules/eks"
  project_name            = var.project_name
  eks_cluster_version     = var.eks_cluster_version
  private_subnet_ids      = module.vpc.private_subnet_ids
  eks_cluster_sg_id       = module.security_groups.eks_cluster_sg_id
  eks_kms_key_arn         = module.kms.eks_key_arn
  ebs_kms_key_arn         = module.kms.ebs_key_arn
  bootstrap_instance_type = "t3.medium"
  bootstrap_min_size      = 2
  bootstrap_desired_size  = 2
  bootstrap_max_size      = 4
  node_disk_size          = 50
  tags                    = local.common_tags
}

module "cloudwatch" {
  source       = "../../modules/cloudwatch"
  project_name = var.project_name
  aws_region   = var.aws_region
  kms_key_arn  = module.kms.eks_key_arn
  tags         = local.common_tags
}

module "s3_audit_logs" {
  source         = "../../modules/s3"
  project_name   = var.project_name
  aws_region     = var.aws_region
  account_id     = local.account_id
  bucket_purpose = "audit-logs"
  kms_key_arn    = module.kms.s3_key_arn
  retention_days = 2555
  force_destroy  = false
  tags           = local.common_tags
}

# =============================================================================
# ALB Controller
# =============================================================================
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.1"

  set { name = "clusterName"; value = module.eks.cluster_name }
  set { name = "serviceAccount.create"; value = "true" }
  set { name = "serviceAccount.name"; value = "aws-load-balancer-controller" }
  set { name = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"; value = module.eks.alb_controller_role_arn }
  set { name = "region"; value = var.aws_region }
  set { name = "vpcId"; value = module.vpc.vpc_id }

  depends_on = [module.eks]
}

# =============================================================================
# GuardDuty + Security Hub
# =============================================================================
resource "aws_guardduty_detector" "main" {
  enable = true

  datasources {
    s3_logs      { enable = true }
    kubernetes   { audit_logs { enable = true } }
  }

  tags = merge(local.common_tags, { Compliance = "PCI-HIPAA-SOC2" })
}

resource "aws_securityhub_account" "main" {}

# =============================================================================
# ArgoCD — GitOps Continuous Delivery Engine (Secondary)
# =============================================================================
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [module.eks]
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = "7.3.11"

  set { name = "controller.replicas"; value = "2" }
  set { name = "server.replicas"; value = "2" }
  set { name = "repoServer.replicas"; value = "2" }
  set { name = "server.extraArgs[0]"; value = "--insecure" }
  set { name = "server.service.type"; value = "ClusterIP" }
  set { name = "server.resources.requests.memory"; value = "256Mi" }
  set { name = "server.resources.requests.cpu"; value = "250m" }
  set { name = "controller.resources.requests.memory"; value = "512Mi" }
  set { name = "controller.resources.requests.cpu"; value = "250m" }
  set { name = "controller.args.appResyncPeriod"; value = "180" }

  depends_on = [module.eks, kubernetes_namespace.argocd]
}

# ArgoCD Application — ecommerce-app (ap-south-1)
resource "kubectl_manifest" "argocd_app_secondary" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "ecommerce-app-ap-south-1"
      namespace = "argocd"
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
        "region"                       = "ap-south-1"
      }
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://github.com/${var.github_org}/${var.github_repo}.git"
        targetRevision = "main"
        path           = "helm/ecommerce-app"
        helm = {
          valueFiles = [
            "values.yaml",
            "values-ap-south-1.yaml"
          ]
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "ecommerce"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true",
          "PruneLast=true",
          "ApplyOutOfSyncOnly=true"
        ]
        retry = {
          limit = 5
          backoff = {
            duration    = "5s"
            factor      = 2
            maxDuration = "3m"
          }
        }
      }
    }
  })

  depends_on = [helm_release.argocd]
}
