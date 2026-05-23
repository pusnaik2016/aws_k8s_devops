# ==============================================================================
# Primary Region — Main Orchestration (us-east-1)
# ==============================================================================
# Wires together all modules for the primary region deployment.
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
# Module: KMS Keys
# =============================================================================
module "kms" {
  source = "../../modules/kms"

  project_name = var.project_name
  aws_region   = var.aws_region
  account_id   = local.account_id
  tags         = local.common_tags
}

# =============================================================================
# Module: VPC
# =============================================================================
module "vpc" {
  source = "../../modules/vpc"

  project_name          = var.project_name
  aws_region            = var.aws_region
  vpc_cidr              = var.vpc_cidr
  availability_zones    = var.availability_zones
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  database_subnet_cidrs = var.database_subnet_cidrs
  single_nat_gateway    = false  # HA: one NAT per AZ
  kms_key_arn           = module.kms.eks_key_arn
  tags                  = local.common_tags
}

# =============================================================================
# Module: Security Groups
# =============================================================================
module "security_groups" {
  source = "../../modules/security-groups"

  project_name     = var.project_name
  vpc_id           = module.vpc.vpc_id
  vpc_cidr         = var.vpc_cidr
  allowed_ssh_cidr = var.allowed_ssh_cidr
  tags             = local.common_tags
}

# =============================================================================
# Module: EKS
# =============================================================================
module "eks" {
  source = "../../modules/eks"

  project_name            = var.project_name
  eks_cluster_version     = var.eks_cluster_version
  private_subnet_ids      = module.vpc.private_subnet_ids
  eks_cluster_sg_id       = module.security_groups.eks_cluster_sg_id
  eks_kms_key_arn         = module.kms.eks_key_arn
  ebs_kms_key_arn         = module.kms.ebs_key_arn
  bootstrap_instance_type = var.bootstrap_instance_type
  bootstrap_min_size      = 2
  bootstrap_desired_size  = 2
  bootstrap_max_size      = 4
  node_disk_size          = 50
  tags                    = local.common_tags
}

# =============================================================================
# Module: CloudWatch
# =============================================================================
module "cloudwatch" {
  source = "../../modules/cloudwatch"

  project_name = var.project_name
  aws_region   = var.aws_region
  kms_key_arn  = module.kms.eks_key_arn
  tags         = local.common_tags
}

# =============================================================================
# Module: S3 — Audit Logs Bucket
# =============================================================================
module "s3_audit_logs" {
  source = "../../modules/s3"

  project_name   = var.project_name
  aws_region     = var.aws_region
  account_id     = local.account_id
  bucket_purpose = "audit-logs"
  kms_key_arn    = module.kms.s3_key_arn
  retention_days = 2555  # 7 years
  force_destroy  = false
  tags           = local.common_tags
}

# =============================================================================
# Module: S3 — Artifacts Bucket
# =============================================================================
module "s3_artifacts" {
  source = "../../modules/s3"

  project_name   = var.project_name
  aws_region     = var.aws_region
  account_id     = local.account_id
  bucket_purpose = "artifacts"
  kms_key_arn    = module.kms.s3_key_arn
  retention_days = 365
  force_destroy  = true
  tags           = local.common_tags
}

# =============================================================================
# ECR Repository
# =============================================================================
resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}/ecommerce-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = module.kms.ebs_key_arn
  }

  force_delete = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-ecr-repo"
  })
}

# ECR Lifecycle Policy
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep only last 20 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "build", "sha-"]
          countType     = "imageCountMoreThan"
          countNumber   = 20
        }
        action = { type = "expire" }
      }
    ]
  })
}

# ECR Replication — replicate to ap-south-1
resource "aws_ecr_replication_configuration" "cross_region" {
  replication_configuration {
    rule {
      destination {
        region      = "ap-south-1"
        registry_id = local.account_id
      }
    }
  }
}

# =============================================================================
# Helm: ALB Controller
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
# ArgoCD — GitOps Continuous Delivery Engine
# =============================================================================
# ArgoCD monitors this Git repository for changes to Helm values.
# When the CD workflow updates values.yaml with a new image tag, ArgoCD
# detects the change and auto-syncs the Kubernetes cluster state.
#
# Flow: CI pushes image → CD updates Git → ArgoCD syncs cluster
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

  # HA mode for production — 3 replicas of server, repo-server, controller
  set { name = "controller.replicas"; value = "2" }
  set { name = "server.replicas"; value = "2" }
  set { name = "repoServer.replicas"; value = "2" }

  # Server — run insecure behind ALB (ALB handles TLS termination)
  set { name = "server.extraArgs[0]"; value = "--insecure" }
  set { name = "server.service.type"; value = "ClusterIP" }

  # Resource limits
  set { name = "server.resources.requests.memory"; value = "256Mi" }
  set { name = "server.resources.requests.cpu"; value = "250m" }
  set { name = "controller.resources.requests.memory"; value = "512Mi" }
  set { name = "controller.resources.requests.cpu"; value = "250m" }

  # Application controller — auto-sync polling interval (3 minutes)
  set { name = "controller.args.appResyncPeriod"; value = "180" }

  depends_on = [module.eks, kubernetes_namespace.argocd]
}

# =============================================================================
# ArgoCD Application — ecommerce-app (us-east-1)
# =============================================================================
# This ArgoCD Application resource tells ArgoCD to:
#   1. Watch the Git repo (helm/ecommerce-app/) for changes
#   2. Render Helm templates with values.yaml + values-us-east-1.yaml
#   3. Auto-sync the rendered manifests to the ecommerce namespace
#   4. Self-heal if someone manually changes the cluster state
#   5. Prune resources that are removed from Git
# =============================================================================
resource "kubectl_manifest" "argocd_app_primary" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "ecommerce-app-us-east-1"
      namespace = "argocd"
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
        "region"                       = "us-east-1"
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
            "values-us-east-1.yaml"
          ]
        }
      }

      destination = {
        server    = "https://kubernetes.default.svc"  # in-cluster
        namespace = "ecommerce"
      }

      syncPolicy = {
        automated = {
          prune    = true   # Remove resources not in Git
          selfHeal = true   # Revert manual changes
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
