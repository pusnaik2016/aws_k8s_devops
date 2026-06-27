# ==============================================================================
# IAM Roles for EKS — Cluster, Nodes, and IRSA (Service Accounts)
# ==============================================================================
# Defines the IAM roles and policies required for the EKS ecosystem:
#
#   1. EKS Cluster Role — Allows the EKS service to manage AWS resources
#   2. EKS Node Group Role — Permissions for EC2 worker nodes
#   3. ALB Controller IRSA Role — Fine-grained permissions for the AWS LB Controller
#
# All roles follow the principle of least privilege. IRSA roles are scoped
# to specific Kubernetes service accounts, not shared across pods.
# ==============================================================================

# =============================================================================
# 1. EKS Cluster IAM Role
# =============================================================================
# This role is assumed by the EKS service itself to manage the Kubernetes
# control plane, create ENIs in your VPC, and manage security groups.
# =============================================================================
resource "aws_iam_role" "eks_cluster" {
  name = "${var.project_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.project_name}-eks-cluster-role"
  }
}

# AmazonEKSClusterPolicy — Core permissions for EKS control plane
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# AmazonEKSVPCResourceController — Allows EKS to manage ENIs for pod networking
resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster.name
}

# =============================================================================
# 2. EKS Node Group IAM Role
# =============================================================================
# Worker nodes need permissions to:
#   - Register with the EKS cluster (AmazonEKSWorkerNodePolicy)
#   - Configure VPC networking for pods (AmazonEKS_CNI_Policy)
#   - Pull container images from ECR (AmazonEC2ContainerRegistryReadOnly)
# =============================================================================
resource "aws_iam_role" "eks_node_group" {
  name = "${var.project_name}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.project_name}-eks-node-role"
  }
}

# Core node permissions — register with cluster, manage node lifecycle
resource "aws_iam_role_policy_attachment" "eks_node_worker_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group.name
}

# VPC CNI permissions — assign VPC IPs to pods, manage network interfaces
resource "aws_iam_role_policy_attachment" "eks_node_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group.name
}

# ECR read-only access — pull container images from ECR repositories
resource "aws_iam_role_policy_attachment" "eks_node_ecr_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group.name
}

# =============================================================================
# 3. AWS Load Balancer Controller — IRSA Role
# =============================================================================
# The ALB Controller runs as a pod in EKS and needs IAM permissions to
# create/manage ALBs, Target Groups, and Listeners in your AWS account.
#
# IRSA (IAM Roles for Service Accounts) scopes these permissions to ONLY
# the ALB Controller pod — other pods cannot assume this role.
# =============================================================================

# IAM policy for the ALB Controller — allows creating and managing ALBs
resource "aws_iam_policy" "alb_controller" {
  name        = "${var.project_name}-alb-controller-policy"
  description = "IAM policy for AWS Load Balancer Controller in EKS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:CreateServiceLinkedRole"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "iam:AWSServiceName" = "elasticloadbalancing.amazonaws.com"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeVpcs",
          "ec2:DescribeVpcPeeringConnections",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeTags",
          "ec2:DescribeCoipPools",
          "ec2:GetCoipPoolUsage",
          "ec2:DescribeTargetGroups",
          "ec2:DescribeTargetGroupAttributes",
          "ec2:DescribeTargetHealth",
          "ec2:DescribeListeners",
          "ec2:DescribeRules",
          "elasticloadbalancing:*",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "cognito-idp:DescribeUserPoolClient",
          "acm:ListCertificates",
          "acm:DescribeCertificate",
          "iam:ListServerCertificates",
          "iam:GetServerCertificate",
          "waf-regional:*",
          "wafv2:*",
          "shield:DescribeProtection",
          "shield:GetSubscriptionState",
          "shield:DescribeSubscription",
          "shield:CreateProtection",
          "shield:DeleteProtection"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-alb-controller-policy"
  }
}

# IRSA role for the ALB Controller — trust only the specific service account
resource "aws_iam_role" "alb_controller" {
  name = "${var.project_name}-alb-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
          "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })

  tags = {
    Name = "${var.project_name}-alb-controller-role"
  }
}

# Attach the ALB policy to the IRSA role
resource "aws_iam_role_policy_attachment" "alb_controller" {
  policy_arn = aws_iam_policy.alb_controller.arn
  role       = aws_iam_role.alb_controller.name
}
