# =============================================================================
# EKS Module
# Project: 3-Tier EKS Application
# Author: Pushparaj Naik
# Well-Architected: Security, Reliability, Operational Excellence
# =============================================================================

module "cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.33.1"

  cluster_name    = "${var.prefix}-${var.environment}-cluster"
  cluster_version = "1.31"

  bootstrap_self_managed_addons = false
  cluster_addons = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                = {}
    aws-ebs-csi-driver     = {} # GitOps: Required for persistent storage
  }

  # Well-Architected: Security - Restrict public access in production
  cluster_endpoint_public_access  = var.environment == "prod" ? false : true
  cluster_endpoint_private_access = true

  # Well-Architected: Security - Enable envelope encryption for K8s secrets
  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.eks_secrets.arn
    resources        = ["secrets"]
  }

  # Well-Architected: Operational Excellence - Enable control plane logging
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Admin permissions for cluster creator
  enable_cluster_creator_admin_permissions = true

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    instance_types = var.node_instance_types
    # Well-Architected: Security - Encrypt EBS volumes
    block_device_mappings = {
      xvda = {
        device_name = "/dev/xvda"
        ebs = {
          volume_size           = 50
          volume_type           = "gp3"
          encrypted             = true
          kms_key_id            = aws_kms_key.eks_secrets.arn
          delete_on_termination = true
        }
      }
    }
  }

  eks_managed_node_groups = {
    primary = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_instance_types

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      labels = {
        Environment = var.environment
        ManagedBy   = "EKS"
      }
    }
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
    repo        = "3Tier_EKS_React"
    Owner       = "Pushparaj Naik"
  }
}

# KMS Key for EKS Secrets Encryption (Well-Architected: Security)
resource "aws_kms_key" "eks_secrets" {
  description             = "KMS key for EKS secrets encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true # Compliance: Auto-rotate keys

  tags = {
    Name        = "${var.prefix}-${var.environment}-eks-secrets-kms"
    Environment = var.environment
  }
}

resource "aws_kms_alias" "eks_secrets_alias" {
  name          = "alias/${var.prefix}-${var.environment}-eks-secrets"
  target_key_id = aws_kms_key.eks_secrets.id
}

# CloudWatch Log Group retention for EKS control plane logs (Compliance)
resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${var.prefix}-${var.environment}-cluster/cluster"
  retention_in_days = 90 # GDPR/SOC2: 90-day log retention

  tags = {
    Name        = "${var.prefix}-${var.environment}-eks-logs"
    Environment = var.environment
  }
}
