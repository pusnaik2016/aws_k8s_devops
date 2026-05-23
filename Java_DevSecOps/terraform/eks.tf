# ==============================================================================
# Amazon EKS — Private Kubernetes Cluster
# ==============================================================================
# Provisions a fully private EKS cluster with:
#
#   Control Plane:
#     - Private API endpoint ONLY (endpoint_public_access = false)
#     - Kubernetes API server accessible only from within the VPC
#     - Cluster secrets encrypted at rest with AWS KMS
#     - Kubernetes version 1.29 (latest stable)
#
#   Managed Node Group:
#     - t3.medium instances in private subnets across 3 AZs
#     - Auto-scaling: min 2 / desired 2 / max 4
#     - IMDSv2 enforced (blocks SSRF-based credential theft)
#     - Encrypted root volumes (gp3)
#
#   Security:
#     - kubectl access ONLY from within VPC (bastion EC2 as access point)
#     - Nodes have NO public IPs
#     - OIDC Provider enabled for IRSA (fine-grained pod permissions)
#
#   Add-ons (managed):
#     - vpc-cni: Pod networking using VPC native IPs
#     - coredns: Cluster DNS resolution
#     - kube-proxy: Network rules for service routing
# ==============================================================================

# =============================================================================
# KMS Key — Encrypts EKS cluster secrets (etcd) at rest
# =============================================================================
resource "aws_kms_key" "eks" {
  description             = "KMS key for EKS cluster secret encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = "${var.project_name}-eks-kms"
  }
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.project_name}-eks"
  target_key_id = aws_kms_key.eks.key_id
}

# =============================================================================
# EKS Cluster — Private Kubernetes control plane
# =============================================================================
resource "aws_eks_cluster" "main" {
  name     = "${var.project_name}-eks"
  version  = var.eks_cluster_version
  role_arn = aws_iam_role.eks_cluster.arn

  # ---------------------------------------------------------------------------
  # VPC Configuration — Private API endpoint, nodes in private subnets
  # ---------------------------------------------------------------------------
  vpc_config {
    # Place EKS ENIs in private subnets for control plane communication
    subnet_ids = aws_subnet.private[*].id

    # PRIVATE CLUSTER: API server endpoint is NOT accessible from the internet.
    # kubectl commands must be run from within the VPC (e.g., bastion EC2).
    endpoint_private_access = true
    endpoint_public_access  = false

    # Security groups for the EKS control plane ENIs
    security_group_ids = [aws_security_group.eks_cluster.id]
  }

  # ---------------------------------------------------------------------------
  # Encryption — Encrypt Kubernetes secrets stored in etcd with KMS
  # ---------------------------------------------------------------------------
  encryption_config {
    provider {
      key_arn = aws_kms_key.eks.arn
    }
    resources = ["secrets"]
  }

  # ---------------------------------------------------------------------------
  # Logging — Send control plane logs to CloudWatch for auditing
  # ---------------------------------------------------------------------------
  enabled_cluster_log_types = [
    "api",           # Kubernetes API server logs
    "audit",         # Kubernetes audit logs (who did what)
    "authenticator", # IAM authenticator logs
    "controllerManager",
    "scheduler"
  ]

  # Ensure IAM roles exist before creating the cluster
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller,
    aws_cloudwatch_log_group.eks,
  ]

  tags = {
    Name = "${var.project_name}-eks"
  }
}

# CloudWatch Log Group for EKS control plane logs
# PCI DSS Req 10.5: retain logs 12 months; SOC 2 CC7 continuous monitoring
resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.project_name}-eks/cluster"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.eks.arn

  tags = {
    Name = "${var.project_name}-eks-logs"
  }
}

# =============================================================================
# OIDC Provider — Enables IRSA (IAM Roles for Service Accounts)
# =============================================================================
# IRSA allows individual Kubernetes pods to assume specific IAM roles
# instead of sharing the node's IAM role. This follows the principle
# of least privilege — e.g., the ALB Controller pod gets only ALB
# permissions, not full EC2 access.
# =============================================================================

# Fetch the OIDC issuer's TLS certificate for verification
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# Create the OIDC identity provider in IAM
resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = {
    Name = "${var.project_name}-eks-oidc"
  }
}

# =============================================================================
# EKS Managed Node Group — Worker nodes in private subnets
# =============================================================================
# Managed node groups automatically handle:
#   - Node provisioning and registration with the EKS cluster
#   - AMI updates and OS patching (when you update the launch template)
#   - Graceful node draining during scaling events
#
# Worker nodes run in private subnets with no public IPs. They reach
# AWS services via VPC Endpoints and the internet via NAT Gateways.
# =============================================================================
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-node-group"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = aws_subnet.private[*].id

  # Instance configuration
  instance_types = [var.eks_node_instance_type]
  capacity_type  = "ON_DEMAND"    # Use SPOT for cost savings in non-prod

  # Auto-scaling configuration
  scaling_config {
    min_size     = var.eks_node_min_size
    desired_size = var.eks_node_desired_size
    max_size     = var.eks_node_max_size
  }

  # Node update configuration — max 1 node unavailable during rolling updates
  update_config {
    max_unavailable = 1
  }

  # Launch template for custom node configuration
  launch_template {
    id      = aws_launch_template.eks_nodes.id
    version = aws_launch_template.eks_nodes.latest_version
  }

  # Ensure IAM roles and policies are ready before creating nodes
  depends_on = [
    aws_iam_role_policy_attachment.eks_node_worker_policy,
    aws_iam_role_policy_attachment.eks_node_cni_policy,
    aws_iam_role_policy_attachment.eks_node_ecr_policy,
  ]

  tags = {
    Name = "${var.project_name}-node-group"
  }
}

# =============================================================================
# Launch Template — Custom node configuration (IMDSv2, encryption, etc.)
# =============================================================================
resource "aws_launch_template" "eks_nodes" {
  name_prefix = "${var.project_name}-eks-node-"

  # Enforce IMDSv2 — blocks SSRF attacks from stealing node credentials
  # hop_limit = 1 prevents containers from reaching the metadata service
  # unless explicitly configured
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"    # Enforce IMDSv2
    http_put_response_hop_limit = 2             # Allow pods to use IRSA
  }

  # Encrypted root volume for all worker nodes
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  # Resource tagging for cost tracking
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-eks-node"
    }
  }

  tags = {
    Name = "${var.project_name}-eks-node-template"
  }
}

# =============================================================================
# EKS Add-ons — Managed cluster components
# =============================================================================
# EKS managed add-ons are automatically updated and patched by AWS.
# Using OVERWRITE resolve_conflicts ensures Terraform maintains control.
# =============================================================================

# VPC CNI — Assigns VPC IP addresses directly to pods for native networking
resource "aws_eks_addon" "vpc_cni" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "vpc-cni"
  addon_version = data.aws_eks_addon_version.vpc_cni.version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Name = "${var.project_name}-vpc-cni"
  }
}

data "aws_eks_addon_version" "vpc_cni" {
  addon_name         = "vpc-cni"
  kubernetes_version = aws_eks_cluster.main.version
  most_recent        = true
}

# CoreDNS — Cluster DNS for service discovery (pod-to-pod name resolution)
resource "aws_eks_addon" "coredns" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "coredns"
  addon_version = data.aws_eks_addon_version.coredns.version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.main]

  tags = {
    Name = "${var.project_name}-coredns"
  }
}

data "aws_eks_addon_version" "coredns" {
  addon_name         = "coredns"
  kubernetes_version = aws_eks_cluster.main.version
  most_recent        = true
}

# kube-proxy — Maintains network rules for Kubernetes Service routing
resource "aws_eks_addon" "kube_proxy" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "kube-proxy"
  addon_version = data.aws_eks_addon_version.kube_proxy.version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Name = "${var.project_name}-kube-proxy"
  }
}

data "aws_eks_addon_version" "kube_proxy" {
  addon_name         = "kube-proxy"
  kubernetes_version = aws_eks_cluster.main.version
  most_recent        = true
}
