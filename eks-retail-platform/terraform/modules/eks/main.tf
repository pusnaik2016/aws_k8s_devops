# ─────────────────────────────────────────────────────────────────────────────
# EKS Module — Kubernetes Cluster for Retail Platform
# ─────────────────────────────────────────────────────────────────────────────
# Compliance controls:
# - KMS envelope encryption for K8s secrets (PCI-DSS 3.4, HIPAA §164.312)
# - Private API endpoint in prod (PCI-DSS 1.3)
# - All control plane logs enabled (SOC2 CC7.2, HIPAA audit)
# - IRSA via OIDC provider (least-privilege IAM)
# - Bottlerocket AMI (minimal attack surface)
# - System node group for bootstrapping only (Karpenter handles app nodes)
# ─────────────────────────────────────────────────────────────────────────────

# ─── Data Sources ────────────────────────────────────────────────────────────

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# ─── KMS Key for EKS Secrets Encryption ─────────────────────────────────────

resource "aws_kms_key" "eks_secrets" {
  description             = "KMS key for EKS secrets envelope encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow EKS to use the key"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name       = "${var.name_prefix}-eks-secrets-kms"
    Compliance = "PCI-DSS,HIPAA"
  })
}

resource "aws_kms_alias" "eks_secrets" {
  name          = "alias/${var.name_prefix}-eks-secrets"
  target_key_id = aws_kms_key.eks_secrets.key_id
}

# ─── EKS Cluster IAM Role ───────────────────────────────────────────────────

resource "aws_iam_role" "eks_cluster" {
  name = "${var.name_prefix}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster.name
}

# ─── EKS Cluster Security Group ─────────────────────────────────────────────

resource "aws_security_group" "eks_cluster" {
  name_prefix = "${var.name_prefix}-eks-cluster-"
  description = "EKS cluster control plane security group"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  # Istio control plane communication
  ingress {
    from_port   = 15017
    to_port     = 15017
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Istio webhook (sidecar injection)"
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-eks-cluster-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ─── EKS Cluster ────────────────────────────────────────────────────────────

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = var.environment == "prod" ? false : true
    public_access_cidrs     = var.environment == "prod" ? [] : ["0.0.0.0/0"]
    security_group_ids      = [aws_security_group.eks_cluster.id]
  }

  # HIPAA/PCI-DSS: Encrypt all K8s secrets at rest with KMS
  encryption_config {
    provider {
      key_arn = aws_kms_key.eks_secrets.arn
    }
    resources = ["secrets"]
  }

  # SOC2/HIPAA: Enable ALL control plane log types for audit
  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  # Enable K8s 1.36+ feature gates when available
  # kubernetes_network_config {
  #   ip_family = "ipv4"
  # }

  tags = merge(var.common_tags, {
    Name       = var.cluster_name
    Compliance = "PCI-DSS,SOC2,HIPAA,GDPR"
  })

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller,
    aws_cloudwatch_log_group.eks_cluster,
  ]
}

# CloudWatch log group for EKS control plane logs
resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.eks_secrets.arn

  tags = merge(var.common_tags, {
    Name       = "${var.cluster_name}-eks-logs"
    Compliance = "SOC2,HIPAA"
  })
}

# ─── System Node Group IAM Role ─────────────────────────────────────────────

resource "aws_iam_role" "system_nodes" {
  name = "${var.name_prefix}-system-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "system_worker_node" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.system_nodes.name
}

resource "aws_iam_role_policy_attachment" "system_cni" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.system_nodes.name
}

resource "aws_iam_role_policy_attachment" "system_ecr" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.system_nodes.name
}

resource "aws_iam_role_policy_attachment" "system_ssm" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.system_nodes.name
}

# ─── System Managed Node Group ──────────────────────────────────────────────
# Minimal node group to bootstrap: Karpenter, CoreDNS, kube-proxy
# Application workloads are handled by Karpenter NodePools

resource "aws_eks_node_group" "system" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.name_prefix}-system-nodes"
  node_role_arn   = aws_iam_role.system_nodes.arn
  subnet_ids      = var.private_subnet_ids

  instance_types = [var.system_node_instance_type]
  capacity_type  = "ON_DEMAND" # System nodes always on-demand
  ami_type       = "BOTTLEROCKET_x86_64"

  scaling_config {
    desired_size = var.system_node_count.desired
    min_size     = var.system_node_count.min
    max_size     = var.system_node_count.max
  }

  update_config {
    max_unavailable_percentage = 25
  }

  labels = {
    role     = "system"
    nodeType = "managed"
  }

  taint {
    key    = "CriticalAddonsOnly"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  tags = merge(var.common_tags, {
    Name      = "${var.name_prefix}-system-nodes"
    NodeGroup = "system"
  })

  depends_on = [
    aws_iam_role_policy_attachment.system_worker_node,
    aws_iam_role_policy_attachment.system_cni,
    aws_iam_role_policy_attachment.system_ecr,
  ]

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

# ─── EKS Addons ─────────────────────────────────────────────────────────────

resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.common_tags
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "coredns"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.common_tags

  depends_on = [aws_eks_node_group.system]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.common_tags
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "aws-ebs-csi-driver"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.common_tags

  depends_on = [aws_eks_node_group.system]
}

resource "aws_eks_addon" "pod_identity" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "eks-pod-identity-agent"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.common_tags

  depends_on = [aws_eks_node_group.system]
}

# ─── OIDC Provider for IRSA ─────────────────────────────────────────────────

data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-oidc-provider"
  })
}
