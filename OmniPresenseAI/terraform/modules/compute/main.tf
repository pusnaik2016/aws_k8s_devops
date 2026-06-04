# ─────────────────────────────────────────────────────────────
# Compute Module — EKS Cluster
# ─────────────────────────────────────────────────────────────

locals {
  cluster_name = "${var.project_name}-${var.environment}"
  common_tags = merge(var.tags, {
    Module      = "compute"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  role_arn = var.eks_cluster_role_arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids      = [var.eks_nodes_security_group_id]
  }

  encryption_config {
    provider {
      key_arn = var.kms_eks_key_arn
    }
    resources = ["secrets"]
  }

  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  tags = merge(local.common_tags, {
    Name = local.cluster_name
  })
}

# ─────────────────────────────────────────────────────────────
# OIDC Provider for IRSA (IAM Roles for Service Accounts)
# ─────────────────────────────────────────────────────────────

data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-oidc"
  })
}
