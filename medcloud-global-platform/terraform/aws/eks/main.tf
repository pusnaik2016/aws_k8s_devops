# ─────────────────────────────────────────────────────────────────────────────
# AWS EKS Cluster — Core E-Commerce Compute
# ─────────────────────────────────────────────────────────────────────────────
# HIPAA-compliant EKS with:
# - Private API endpoint (no public access in prod)
# - Envelope encryption for secrets (KMS)
# - IRSA (IAM Roles for Service Accounts)
# - Managed node groups with Bottlerocket AMI
# - Cluster logging to CloudWatch (audit, API, authenticator)
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }

  backend "s3" {
    bucket         = "medcloud-terraform-state"
    key            = "aws/eks/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "medcloud-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(var.common_tags, {
      Cloud     = "AWS"
      Component = "eks"
    })
  }
}

# ─── Data Sources ────────────────────────────────────────────────────────────

data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = "medcloud-terraform-state"
    key    = "aws/networking/terraform.tfstate"
    region = "us-east-1"
  }
}

data "aws_caller_identity" "current" {}

# ─── Locals ──────────────────────────────────────────────────────────────────

locals {
  name_prefix   = "${var.project_name}-${var.environment}"
  cluster_name  = "${local.name_prefix}-eks"
  vpc_id        = data.terraform_remote_state.networking.outputs.vpc_id
  private_subnets = data.terraform_remote_state.networking.outputs.private_subnet_ids
}

# ─── KMS Key for EKS Secrets Encryption ─────────────────────────────────────

resource "aws_kms_key" "eks_secrets" {
  description             = "KMS key for EKS secrets envelope encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name       = "${local.cluster_name}-secrets-kms"
    Compliance = "HIPAA"
  }
}

resource "aws_kms_alias" "eks_secrets" {
  name          = "alias/${local.cluster_name}-secrets"
  target_key_id = aws_kms_key.eks_secrets.key_id
}

# ─── EKS Cluster IAM Role ───────────────────────────────────────────────────

resource "aws_iam_role" "eks_cluster" {
  name = "${local.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster.name
}

# ─── EKS Cluster Security Group ─────────────────────────────────────────────

resource "aws_security_group" "eks_cluster" {
  name_prefix = "${local.cluster_name}-cluster-"
  description = "EKS cluster security group"
  vpc_id      = local.vpc_id

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  # Allow cross-cloud Istio mesh traffic
  ingress {
    from_port   = 15443
    to_port     = 15443
    protocol    = "tcp"
    cidr_blocks = [var.azure_vnet_cidr, var.gcp_vpc_cidr]
    description = "Istio east-west gateway (cross-cloud mesh)"
  }

  # Allow cross-cloud K8s API access
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.azure_vnet_cidr, var.gcp_vpc_cidr]
    description = "K8s API access from Azure/GCP"
  }

  tags = {
    Name = "${local.cluster_name}-cluster-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ─── EKS Cluster ────────────────────────────────────────────────────────────

resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids              = local.private_subnets
    endpoint_private_access = true
    endpoint_public_access  = var.environment == "prod" ? false : true
    public_access_cidrs     = var.environment == "prod" ? [] : ["0.0.0.0/0"]
    security_group_ids      = [aws_security_group.eks_cluster.id]
  }

  # HIPAA: Encrypt all K8s secrets with KMS
  encryption_config {
    provider {
      key_arn = aws_kms_key.eks_secrets.arn
    }
    resources = ["secrets"]
  }

  # HIPAA: Enable all control plane logging
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

  tags = {
    Name       = local.cluster_name
    Compliance = "HIPAA,PCI-DSS"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller,
  ]
}

# ─── EKS Node Group IAM Role ────────────────────────────────────────────────

resource "aws_iam_role" "eks_nodes" {
  name = "${local.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.eks_nodes.name
}

# ─── EKS Managed Node Groups ────────────────────────────────────────────────

# Application node group (storefront, orders, notifications)
resource "aws_eks_node_group" "application" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${local.cluster_name}-app-nodes"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = local.private_subnets

  instance_types = [var.node_instance_type.aws]
  capacity_type  = var.environment == "prod" ? "ON_DEMAND" : "SPOT"
  ami_type       = "BOTTLEROCKET_x86_64" # Minimal, secure container OS

  scaling_config {
    desired_size = var.node_count.min
    min_size     = var.node_count.min
    max_size     = var.node_count.max
  }

  update_config {
    max_unavailable_percentage = 25
  }

  labels = {
    role        = "application"
    cloud       = "aws"
    workload    = "e-commerce"
    compliance  = "hipaa-pci"
  }

  taint {
    key    = "workload"
    value  = "e-commerce"
    effect = "NO_SCHEDULE"
  }

  tags = {
    Name        = "${local.cluster_name}-app-nodes"
    NodeGroup   = "application"
    AutoScaling = "true"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ecr_read_only,
  ]

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

# System/Istio node group (mesh control plane, monitoring)
resource "aws_eks_node_group" "system" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${local.cluster_name}-system-nodes"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = local.private_subnets

  instance_types = ["m6i.large"]
  capacity_type  = "ON_DEMAND"
  ami_type       = "BOTTLEROCKET_x86_64"

  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 4
  }

  labels = {
    role  = "system"
    cloud = "aws"
  }

  taint {
    key    = "CriticalAddonsOnly"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  tags = {
    Name      = "${local.cluster_name}-system-nodes"
    NodeGroup = "system"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ecr_read_only,
  ]
}

# ─── EKS Addons ─────────────────────────────────────────────────────────────

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "coredns"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.system]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "kube-proxy"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "aws-ebs-csi-driver"
  resolve_conflicts_on_update = "OVERWRITE"
}

# ─── OIDC Provider for IRSA ─────────────────────────────────────────────────

data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = {
    Name = "${local.cluster_name}-oidc-provider"
  }
}

# ─── Outputs ─────────────────────────────────────────────────────────────────

output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_ca_certificate" {
  description = "EKS cluster CA certificate"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_url" {
  description = "OIDC provider URL"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "node_role_arn" {
  description = "EKS node IAM role ARN"
  value       = aws_iam_role.eks_nodes.arn
}
