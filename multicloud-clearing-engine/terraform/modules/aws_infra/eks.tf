# =============================================================================
# AWS EKS — Kubernetes Orchestration (Primary Compute)
# =============================================================================
# Production EKS cluster with:
#   - Private API endpoint
#   - Managed node group with autoscaling
#   - OIDC provider for IRSA (secure pod-level IAM)
#   - Cluster encryption at rest via KMS
#   - Full control plane logging for SOX audit trails
# =============================================================================

# -----------------------------------------------------------------------------
# EKS Cluster
# -----------------------------------------------------------------------------
resource "aws_eks_cluster" "main" {
  name     = "${local.name_prefix}-eks"
  version  = var.eks_cluster_version
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids              = aws_subnet.private_app[*].id
    endpoint_private_access = true
    endpoint_public_access  = true # Set false for full private cluster
    public_access_cidrs     = ["0.0.0.0/0"] # Restrict to CI/CD IPs in production
    security_group_ids      = [aws_security_group.eks_cluster.id]
  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.main.arn
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

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-eks"
  })

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller,
    aws_cloudwatch_log_group.eks,
  ]
}

# -----------------------------------------------------------------------------
# EKS CloudWatch Log Group
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${local.name_prefix}-eks/cluster"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.main.arn

  tags = local.tags
}

# -----------------------------------------------------------------------------
# EKS Managed Node Group
# -----------------------------------------------------------------------------
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${local.name_prefix}-main-ng"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = aws_subnet.private_app[*].id
  instance_types  = [var.eks_node_instance_type]
  capacity_type   = "ON_DEMAND"

  scaling_config {
    desired_size = var.eks_node_min
    min_size     = var.eks_node_min
    max_size     = var.eks_node_max
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role        = "general"
    environment = var.environment
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-eks-ng"
  })

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry,
  ]
}

# -----------------------------------------------------------------------------
# EKS Add-ons
# -----------------------------------------------------------------------------
resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "coredns"

  depends_on = [aws_eks_node_group.main]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "kube-proxy"
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi.arn

  depends_on = [aws_eks_node_group.main]
}

# -----------------------------------------------------------------------------
# OIDC Provider for IRSA (IAM Roles for Service Accounts)
# -----------------------------------------------------------------------------
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = local.tags
}

# -----------------------------------------------------------------------------
# EKS Security Group
# -----------------------------------------------------------------------------
resource "aws_security_group" "eks_cluster" {
  name_prefix = "${local.name_prefix}-eks-cluster-"
  vpc_id      = aws_vpc.main.id
  description = "EKS cluster control plane security group"

  ingress {
    description = "Allow HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-eks-cluster-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}
