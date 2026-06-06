# ─────────────────────────────────────────────────────────────
# Security Module — IAM Roles
# ─────────────────────────────────────────────────────────────

locals {
  common_tags = merge(var.tags, {
    Module      = "security"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

# ─────────────────────────────────────────────────────────────
# EKS Cluster IAM Role
# ─────────────────────────────────────────────────────────────

resource "aws_iam_role" "eks_cluster" {
  name = "${var.project_name}-${var.environment}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster.name
}

# ─────────────────────────────────────────────────────────────
# EKS Node Group IAM Role
# ─────────────────────────────────────────────────────────────

resource "aws_iam_role" "eks_node_group" {
  name = "${var.project_name}-${var.environment}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "eks_worker_node" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.eks_node_group.name
}

# ─────────────────────────────────────────────────────────────
# SSM Parameters for Secrets
# ─────────────────────────────────────────────────────────────

resource "aws_ssm_parameter" "aurora_password" {
  name        = "/${var.project_name}/${var.environment}/aurora/master-password"
  description = "Aurora PostgreSQL master password"
  type        = "SecureString"
  value       = "CHANGE_ME_BEFORE_DEPLOY"

  tags = local.common_tags

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "redis_auth_token" {
  name        = "/${var.project_name}/${var.environment}/redis/auth-token"
  description = "ElastiCache Redis auth token"
  type        = "SecureString"
  value       = "CHANGE_ME_BEFORE_DEPLOY"

  tags = local.common_tags

  lifecycle {
    ignore_changes = [value]
  }
}
